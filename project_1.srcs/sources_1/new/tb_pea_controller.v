`timescale 1ns / 1ps
// ====================================================================
// Testbench: pea_controller
// Instantiates context_memory + pea_controller.
// Asserts start, then observes:
//   - FSM state transitions (via weight_addr/cfg_alu changes)
//   - j_sel sweeping 0..J-1
//   - mac_clear pulses at start of each n
//   - bias/relu ops after each n's MAC loops
//   - done assertion after all layers
// ====================================================================

module tb_pea_controller();

    localparam NUM_LAYERS = 8;
    localparam ADDRW      = 8;
    localparam WADDRW     = 11;
    localparam BADDRW     = 6;

    reg clk, rst, start;

    // Context memory <-> controller
    wire [$clog2(NUM_LAYERS)-1:0] layer_index;
    wire [2:0]  ctx_op;
    wire [3:0]  ctx_J;
    wire [7:0]  ctx_K;
    wire [7:0]  ctx_N;
    wire [9:0]  ctx_Y;
    wire [1:0]  ctx_stride;
    wire [15:0] ctx_wbase;
    wire [7:0]  ctx_bbase;
    wire [3:0]  ctx_res;

    // Controller outputs
    wire [WADDRW-1:0] weight_addr;
    wire [BADDRW-1:0] bias_addr;
    wire [8:0]        pixel_base_addr;
    wire [2:0]        j_sel;
    wire [2:0]        cfg_alu;
    wire              mac_clear;
    wire              bias_en;
    wire              ld_en, st_en;
    wire [1:0]        ldm_sel;
    wire [ADDRW-1:0]  ldm_addr;
    wire              done;

    localparam CTX_MEMFILE = "./context.mem";

    // Context Memory
    context_memory #(.NUM_LAYERS(NUM_LAYERS), .MEMFILE(CTX_MEMFILE)) U_CTX (
        .clk            (clk),
        .layer_index    (layer_index),
        .op_type        (ctx_op),
        .kernel_size_J  (ctx_J),
        .in_channels_K  (ctx_K),
        .out_channels_N (ctx_N),
        .out_length_Y   (ctx_Y),
        .stride         (ctx_stride),
        .weight_base_addr(ctx_wbase),
        .bias_base_addr (ctx_bbase),
        .residual_source(ctx_res)
    );

    // PEA Controller
    pea_controller #(
        .NUM_LAYERS(NUM_LAYERS),
        .ADDRW(ADDRW),
        .WADDRW(WADDRW),
        .BADDRW(BADDRW)
    ) U_CTRL (
        .clk            (clk),
        .rst            (rst),
        .start          (start),
        .layer_index    (layer_index),
        .ctx_op_type    (ctx_op),
        .ctx_kernel_J   (ctx_J),
        .ctx_in_ch_K    (ctx_K),
        .ctx_out_ch_N   (ctx_N),
        .ctx_out_len_Y  (ctx_Y),
        .ctx_stride     (ctx_stride),
        .ctx_w_base     (ctx_wbase),
        .ctx_b_base     (ctx_bbase),
        .ctx_residual   (ctx_res),
        .weight_addr    (weight_addr),
        .bias_addr      (bias_addr),
        .pixel_base_addr(pixel_base_addr),
        .j_sel          (j_sel),
        .cfg_alu        (cfg_alu),
        .mac_clear      (mac_clear),
        .bias_en        (bias_en),
        .ld_en          (ld_en),
        .st_en          (st_en),
        .ldm_sel        (ldm_sel),
        .ldm_addr       (ldm_addr),
        .done           (done)
    );

    always #5 clk = ~clk;

    // Monitor key signals on every rising edge
    always @(posedge clk) begin
        if (!rst) begin
            if (mac_clear)
                $display("t=%0t  mac_clear pulse (n=%0d)", $time, U_CTRL.n_cnt);
            if (cfg_alu == 3'b000)
                $display("t=%0t  MAC  j_sel=%0d  weight_addr=%0d", $time, j_sel, weight_addr);
            if (cfg_alu == 3'b101)
                $display("t=%0t  ADD_BIAS  bias_addr=%0d", $time, bias_addr);
            if (cfg_alu == 3'b011)
                $display("t=%0t  RELU", $time);
            if (st_en)
                $display("t=%0t  STORE  ldm_addr=%0d", $time, ldm_addr);
            if (done)
                $display("t=%0t  === DONE ===", $time);
        end
    end

    initial begin
        $display("\n=== PEA CONTROLLER TEST START ===\n");
        clk   = 0;
        rst   = 1;
        start = 0;
        #30 rst = 0;
        #10 start = 1;
        #10 start = 0;

        // Wait up to 5000 cycles for done
        repeat(5000) @(posedge clk);

        if (!done)
            $display("TIMEOUT — done not asserted");

        $display("\n=== PEA CONTROLLER TEST COMPLETE ===\n");
        $finish;
    end

endmodule
