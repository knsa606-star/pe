`timescale 1ns / 1ps
// ====================================================================
// MINA Top-Level Integration
// Paper Reference: Fig. 5 — overall MINA architecture
//
// Connects:
//   context_memory  -> pea_controller (layer parameters)
//   pea_controller  -> weight_memory  (addr)
//   pea_controller  -> bias_memory    (addr)
//   pea_controller  -> pea_40         (all control signals)
//   weight_memory   -> pea_40.weight_in
//   bias_memory     -> pea_40.bias_in
//   pea_40.bus_out  -> result_out (PE[0] output)
// ====================================================================

module mina_top #(
    parameter M          = 40,
    parameter PIXW       = 16,
    parameter NUM_LAYERS = 16,
    parameter ADDRW      = 8,     // LDM address width
    parameter WADDRW     = 13,    // weight memory: 8192 entries
    parameter BADDRW     = 7,     // bias   memory: 128 entries
    parameter WDEPTH     = 8192,
    parameter BDEPTH     = 128,
    parameter CTX_MEMFILE = "./context.mem",
    parameter W_MEMFILE   = "./weights.mem",
    parameter B_MEMFILE   = "./bias.mem"
)(
    input  wire              clk,
    input  wire              rst,
    input  wire              start,

    output wire              done,
    output wire [PIXW-1:0]   result_out  // bus_out from PE[0] after processing
);

    // ---------------------------------------------------------------
    // Internal wires: controller -> memories and PEA
    // ---------------------------------------------------------------
    wire [$clog2(NUM_LAYERS)-1:0] layer_index;

    wire [2:0]  ctx_op_type;
    wire [3:0]  ctx_kernel_J;
    wire [7:0]  ctx_in_ch_K;
    wire [7:0]  ctx_out_ch_N;
    wire [9:0]  ctx_out_len_Y;
    wire [1:0]  ctx_stride;
    wire [15:0] ctx_w_base;
    wire [7:0]  ctx_b_base;
    wire [3:0]  ctx_residual;

    wire [WADDRW-1:0]  weight_addr;
    wire [BADDRW-1:0]  bias_addr;
    wire [8:0]         pixel_base_addr;

    wire [2:0]         j_sel;
    wire [2:0]         cfg_alu;
    wire               mac_clear;
    wire               bias_en;
    wire               ld_en;
    wire               st_en;
    wire [1:0]         ldm_sel;
    wire [ADDRW-1:0]   ldm_addr;

    wire [PIXW-1:0]    weight_data;
    wire [PIXW-1:0]    bias_data;
    wire [PIXW-1:0]    bus_out [0:M-1];

    // ---------------------------------------------------------------
    // Context Memory
    // ---------------------------------------------------------------
    context_memory #(
        .NUM_LAYERS(NUM_LAYERS),
        .MEMFILE(CTX_MEMFILE)
    ) U_CTX (
        .clk            (clk),
        .layer_index    (layer_index),
        .op_type        (ctx_op_type),
        .kernel_size_J  (ctx_kernel_J),
        .in_channels_K  (ctx_in_ch_K),
        .out_channels_N (ctx_out_ch_N),
        .out_length_Y   (ctx_out_len_Y),
        .stride         (ctx_stride),
        .weight_base_addr(ctx_w_base),
        .bias_base_addr (ctx_b_base),
        .residual_source(ctx_residual)
    );

    // ---------------------------------------------------------------
    // PEA Controller (FSM)
    // ---------------------------------------------------------------
    pea_controller #(
        .NUM_LAYERS(NUM_LAYERS),
        .M         (M),
        .PIXW      (PIXW),
        .ADDRW     (ADDRW),
        .WADDRW    (WADDRW),
        .BADDRW    (BADDRW)
    ) U_CTRL (
        .clk            (clk),
        .rst            (rst),
        .start          (start),

        .layer_index    (layer_index),
        .ctx_op_type    (ctx_op_type),
        .ctx_kernel_J   (ctx_kernel_J),
        .ctx_in_ch_K    (ctx_in_ch_K),
        .ctx_out_ch_N   (ctx_out_ch_N),
        .ctx_out_len_Y  (ctx_out_len_Y),
        .ctx_stride     (ctx_stride),
        .ctx_w_base     (ctx_w_base),
        .ctx_b_base     (ctx_b_base),
        .ctx_residual   (ctx_residual),

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

    // ---------------------------------------------------------------
    // Weight Memory
    // ---------------------------------------------------------------
    weight_memory #(
        .DATA_WIDTH(PIXW),
        .DEPTH     (WDEPTH),
        .MEMFILE   (W_MEMFILE)
    ) U_WMEM (
        .clk     (clk),
        .addr    (weight_addr),
        .data_out(weight_data)
    );

    // ---------------------------------------------------------------
    // Bias Memory
    // ---------------------------------------------------------------
    bias_memory #(
        .DATA_WIDTH(PIXW),
        .DEPTH     (BDEPTH),
        .MEMFILE   (B_MEMFILE)
    ) U_BMEM (
        .clk     (clk),
        .addr    (bias_addr),
        .data_out(bias_data)
    );

    // ---------------------------------------------------------------
    // 40-PE Processing Array (with SBA + Pixel Memory)
    // ---------------------------------------------------------------
    pea_40 #(
        .M    (M),
        .PIXW (PIXW),
        .ADDRW(ADDRW)
    ) U_PEA (
        .clk            (clk),
        .rst            (rst),
        .j_sel          (j_sel),
        .weight_in      (weight_data),
        .bias_in        (bias_data),
        .cfg_alu        (cfg_alu),
        .pixel_base_addr(pixel_base_addr),
        .mac_clear      (mac_clear),
        .bias_en        (bias_en),
        .ld_en          (ld_en),
        .st_en          (st_en),
        .ldm_sel        (ldm_sel),
        .ldm_addr       (ldm_addr),
        .bus_in         (16'd0),   // bus_in not used in this config
        .bus_out        (bus_out)
    );

    // Expose PE[0] output as primary result
    assign result_out = bus_out[0];

endmodule
