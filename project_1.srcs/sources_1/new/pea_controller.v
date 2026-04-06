`timescale 1ns / 1ps
// ====================================================================
// PEA Controller for MINA Accelerator
// Paper Reference: Section III-E, Fig. 9 (pipeline timing), Algorithm 2
//
// This FSM controls the entire computation:
//   IDLE -> LOAD_CONTEXT -> LATCH_CTX -> COMPUTE ->
//   BIAS_APPLY -> RELU_APPLY -> ADVANCE_N ->
//   NEXT_LAYER -> DONE
//
// For CONV layers the controller runs:
//   for n = 0..N-1:           (output channel)
//     mac_clear pulse
//     for k = 0..K-1:         (input channel)
//       for j = 0..J-1:       (kernel position)
//         cfg_alu = MAC, weight_addr = w_base + n*K*J + k*J + j
//     cfg_alu = ADD_BIAS, bias_addr = b_base + n
//     cfg_alu = RELU
//     st_en=1 to store result into LDM (addr = n_cnt)
//
// For RELU / MAXPOOL / ADD layers the controller issues a single-cycle
// ALU command to all PEs simultaneously.
// ====================================================================

module pea_controller #(
    parameter NUM_LAYERS = 16,
    parameter M          = 40,    // number of PEs
    parameter PIXW       = 16,
    parameter ADDRW      = 8,     // LDM address width inside PE
    parameter WADDRW     = 13,    // weight memory address width (8192 entries)
    parameter BADDRW     = 7      // bias   memory address width (128 entries)
)(
    input  wire                  clk,
    input  wire                  rst,
    input  wire                  start,

    // Context memory read interface (1-cycle latency)
    output reg  [$clog2(NUM_LAYERS)-1:0] layer_index,
    input  wire [2:0]            ctx_op_type,
    input  wire [3:0]            ctx_kernel_J,
    input  wire [7:0]            ctx_in_ch_K,
    input  wire [7:0]            ctx_out_ch_N,
    input  wire [9:0]            ctx_out_len_Y,
    input  wire [1:0]            ctx_stride,
    input  wire [15:0]           ctx_w_base,
    input  wire [7:0]            ctx_b_base,
    input  wire [3:0]            ctx_residual,

    // Memory address outputs
    output reg  [WADDRW-1:0]     weight_addr,
    output reg  [BADDRW-1:0]     bias_addr,
    output reg  [8:0]            pixel_base_addr,

    // PE control outputs (broadcast to all 40 PEs)
    output reg  [2:0]            j_sel,
    output reg  [2:0]            cfg_alu,
    output reg                   mac_clear,
    output reg                   bias_en,

    // LSU control (broadcast to all PEs)
    output reg                   ld_en,
    output reg                   st_en,
    output reg  [1:0]            ldm_sel,
    output reg  [ADDRW-1:0]      ldm_addr,

    // Status
    output reg                   done
);

    // ---------------------------------------------------------------
    // op_type encoding (must match context_memory.v)
    // ---------------------------------------------------------------
    localparam OP_CONV    = 3'd0;
    localparam OP_MAXPOOL = 3'd1;
    localparam OP_ADD     = 3'd2;
    localparam OP_RELU    = 3'd3;
    localparam OP_GAP     = 3'd4;

    // ---------------------------------------------------------------
    // cfg_alu encoding (must match pe_unit.v)
    // ---------------------------------------------------------------
    localparam ALU_MAC      = 3'b000;
    localparam ALU_ADD      = 3'b001;
    localparam ALU_MAXPOOL  = 3'b010;
    localparam ALU_RELU     = 3'b011;
    localparam ALU_PASS     = 3'b100;
    localparam ALU_ADDBIAS  = 3'b101;

    // ---------------------------------------------------------------
    // FSM states
    // ---------------------------------------------------------------
    localparam ST_IDLE         = 4'd0;
    localparam ST_LOAD_CTX     = 4'd1;  // present layer_index, wait 1 cycle
    localparam ST_LATCH_CTX    = 4'd2;  // latch context outputs
    localparam ST_MAC_CLEAR    = 4'd3;  // issue mac_clear for new n
    localparam ST_COMPUTE      = 4'd4;  // inner MAC loops (k, j)
    localparam ST_BIAS_APPLY   = 4'd5;  // add bias (ADD_BIAS opcode)
    localparam ST_RELU_APPLY   = 4'd6;  // apply RELU
    localparam ST_STORE_RESULT = 4'd7;  // st_en=1, save to LDM
    localparam ST_ADVANCE_N    = 4'd8;  // increment n, loop or go next layer
    localparam ST_SIMPLE_OP    = 4'd9;  // 1-cycle RELU/MAXPOOL/ADD layer
    localparam ST_NEXT_LAYER   = 4'd10; // increment layer_index
    localparam ST_DONE         = 4'd11;

    reg [3:0] state;

    // Latched layer parameters
    reg [2:0]  op_type_r;
    reg [3:0]  kernel_J_r;   // up to 7
    reg [7:0]  in_ch_K_r;
    reg [7:0]  out_ch_N_r;
    reg [9:0]  out_len_Y_r;
    reg [1:0]  stride_r;
    reg [15:0] w_base_r;
    reg [7:0]  b_base_r;
    reg [3:0]  residual_r;

    // Loop counters
    reg [7:0]  n_cnt;   // output channel index
    reg [7:0]  k_cnt;   // input channel index
    reg [3:0]  j_cnt;   // kernel position index

    // ---------------------------------------------------------------
    // Weight address computation:  w_base + n*K*J + k*J + j
    // Use 20-bit intermediates to avoid overflow
    // ---------------------------------------------------------------
    wire [19:0] weight_addr_w;
    assign weight_addr_w = w_base_r
                         + n_cnt * in_ch_K_r * kernel_J_r
                         + k_cnt * kernel_J_r
                         + j_cnt;

    // ---------------------------------------------------------------
    // FSM
    // ---------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state            <= ST_IDLE;
            done             <= 1'b0;
            layer_index      <= 0;
            cfg_alu          <= ALU_PASS;
            mac_clear        <= 1'b0;
            bias_en          <= 1'b0;
            ld_en            <= 1'b0;
            st_en            <= 1'b0;
            ldm_sel          <= 2'd0;
            ldm_addr         <= 0;
            weight_addr      <= 0;
            bias_addr        <= 0;
            pixel_base_addr  <= 9'd0;
            j_sel            <= 3'd0;
            n_cnt            <= 0;
            k_cnt            <= 0;
            j_cnt            <= 0;
        end else begin
            // Default: de-assert one-cycle pulses
            mac_clear <= 1'b0;
            st_en     <= 1'b0;
            bias_en   <= 1'b0;

            case (state)
                // -------------------------------------------------
                // IDLE: wait for start
                // -------------------------------------------------
                ST_IDLE: begin
                    layer_index <= 0;
                    cfg_alu     <= ALU_PASS;
                    if (start) begin
                        done  <= 1'b0;  // clear done when new computation starts
                        state <= ST_LOAD_CTX;
                    end
                end

                // -------------------------------------------------
                // LOAD_CONTEXT: present layer_index, wait 1 cycle
                // for context_memory synchronous read
                // -------------------------------------------------
                ST_LOAD_CTX: begin
                    state <= ST_LATCH_CTX;
                end

                // -------------------------------------------------
                // LATCH_CONTEXT: latch decoded context fields,
                // reset per-layer counters
                // -------------------------------------------------
                ST_LATCH_CTX: begin
                    op_type_r   <= ctx_op_type;
                    kernel_J_r  <= ctx_kernel_J;
                    in_ch_K_r   <= ctx_in_ch_K;
                    out_ch_N_r  <= ctx_out_ch_N;
                    out_len_Y_r <= ctx_out_len_Y;
                    stride_r    <= ctx_stride;
                    w_base_r    <= ctx_w_base;
                    b_base_r    <= ctx_b_base;
                    residual_r  <= ctx_residual;

                    n_cnt <= 0;
                    k_cnt <= 0;
                    j_cnt <= 0;

                    // Route to appropriate sub-FSM
                    case (ctx_op_type)
                        OP_CONV:    state <= ST_MAC_CLEAR;
                        OP_RELU,
                        OP_MAXPOOL,
                        OP_ADD,
                        OP_GAP:     state <= ST_SIMPLE_OP;
                        default:    state <= ST_NEXT_LAYER;
                    endcase
                end

                // -------------------------------------------------
                // MAC_CLEAR: pulse mac_clear at start of each new n
                // -------------------------------------------------
                ST_MAC_CLEAR: begin
                    mac_clear       <= 1'b1;
                    cfg_alu         <= ALU_PASS;  // no computation this cycle
                    j_cnt           <= 0;
                    k_cnt           <= 0;
                    j_sel           <= 3'd0;
                    weight_addr     <= weight_addr_w[WADDRW-1:0];
                    state           <= ST_COMPUTE;
                end

                // -------------------------------------------------
                // COMPUTE: inner MAC loops — one MAC per cycle
                // Loop order (innermost first): j -> k -> n
                // -------------------------------------------------
                ST_COMPUTE: begin
                    // Issue MAC
                    cfg_alu     <= ALU_MAC;
                    j_sel       <= j_cnt[2:0];
                    weight_addr <= weight_addr_w[WADDRW-1:0];

                    // Advance innermost counter j
                    if (j_cnt < kernel_J_r - 1) begin
                        j_cnt <= j_cnt + 1;
                    end else begin
                        j_cnt <= 0;
                        // Advance k
                        if (k_cnt < in_ch_K_r - 1) begin
                            k_cnt <= k_cnt + 1;
                        end else begin
                            k_cnt <= 0;
                            // All j,k done for this n -> add bias
                            state <= ST_BIAS_APPLY;
                        end
                    end
                end

                // -------------------------------------------------
                // BIAS_APPLY: issue ADD_BIAS for current n
                // -------------------------------------------------
                ST_BIAS_APPLY: begin
                    cfg_alu   <= ALU_ADDBIAS;
                    bias_en   <= 1'b1;
                    bias_addr <= b_base_r[BADDRW-1:0] + n_cnt[BADDRW-1:0];
                    state     <= ST_RELU_APPLY;
                end

                // -------------------------------------------------
                // RELU_APPLY: apply ReLU to alu_out
                // (bus_out holds alu_out when ld_en=0)
                // -------------------------------------------------
                ST_RELU_APPLY: begin
                    cfg_alu <= ALU_RELU;
                    state   <= ST_STORE_RESULT;
                end

                // -------------------------------------------------
                // STORE_RESULT: write result into LDM bank 0
                // at address n_cnt (one word per output channel)
                // -------------------------------------------------
                ST_STORE_RESULT: begin
                    cfg_alu  <= ALU_PASS;
                    st_en    <= 1'b1;
                    ldm_sel  <= 2'd0;
                    ldm_addr <= n_cnt[ADDRW-1:0];
                    state    <= ST_ADVANCE_N;
                end

                // -------------------------------------------------
                // ADVANCE_N: move to next output channel or finish
                // -------------------------------------------------
                ST_ADVANCE_N: begin
                    st_en <= 1'b0;
                    if (n_cnt < out_ch_N_r - 1) begin
                        n_cnt <= n_cnt + 1;
                        state <= ST_MAC_CLEAR;
                    end else begin
                        state <= ST_NEXT_LAYER;
                    end
                end

                // -------------------------------------------------
                // SIMPLE_OP: single-cycle RELU/MAXPOOL/ADD/GAP
                // -------------------------------------------------
                ST_SIMPLE_OP: begin
                    case (op_type_r)
                        OP_RELU:    cfg_alu <= ALU_RELU;
                        OP_MAXPOOL: cfg_alu <= ALU_MAXPOOL;
                        OP_ADD:     cfg_alu <= ALU_ADD;
                        default:    cfg_alu <= ALU_PASS;
                    endcase
                    state <= ST_NEXT_LAYER;
                end

                // -------------------------------------------------
                // NEXT_LAYER: advance layer_index
                // -------------------------------------------------
                ST_NEXT_LAYER: begin
                    cfg_alu <= ALU_PASS;
                    if (layer_index < NUM_LAYERS - 1) begin
                        layer_index <= layer_index + 1;
                        state       <= ST_LOAD_CTX;
                    end else begin
                        state <= ST_DONE;
                    end
                end

                // -------------------------------------------------
                // DONE: assert done and hold until next start
                // -------------------------------------------------
                ST_DONE: begin
                    done    <= 1'b1;
                    cfg_alu <= ALU_PASS;
                    // Stay in DONE until a new start pulse arrives
                    if (start) begin
                        done  <= 1'b0;
                        layer_index <= 0;
                        state <= ST_LOAD_CTX;
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
