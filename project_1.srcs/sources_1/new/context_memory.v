`timescale 1ns / 1ps
// ====================================================================
// Context Memory for MINA Accelerator
// Stores per-layer parameters for the PEA Controller.
// Paper Reference: Fig. 5, Section III-E
//
// Each 64-bit entry layout:
//   [63]    = unused (0)
//   [62:60] = op_type   (0=CONV, 1=MAXPOOL, 2=ADD, 3=RELU, 4=GAP)
//   [59:56] = kernel_size_J [3:0]
//   [55:48] = in_channels_K [7:0]
//   [47:40] = out_channels_N [7:0]
//   [39:30] = out_length_Y   [9:0]
//   [29:28] = stride          [1:0]
//   [27:12] = weight_base_addr[15:0]
//   [11:4]  = bias_base_addr  [7:0]
//   [3:0]   = residual_source [3:0]  (0 = none)
// ====================================================================

module context_memory #(
    parameter NUM_LAYERS = 16,
    parameter MEMFILE    = "./context.mem"
)(
    input  wire                            clk,
    input  wire [$clog2(NUM_LAYERS)-1:0]   layer_index,

    // Decoded outputs (registered, 1-cycle read latency)
    output reg  [2:0]  op_type,
    output reg  [3:0]  kernel_size_J,
    output reg  [7:0]  in_channels_K,
    output reg  [7:0]  out_channels_N,
    output reg  [9:0]  out_length_Y,
    output reg  [1:0]  stride,
    output reg  [15:0] weight_base_addr,
    output reg  [7:0]  bias_base_addr,
    output reg  [3:0]  residual_source
);

    // op_type constants
    localparam OP_CONV    = 3'd0;
    localparam OP_MAXPOOL = 3'd1;
    localparam OP_ADD     = 3'd2;
    localparam OP_RELU    = 3'd3;
    localparam OP_GAP     = 3'd4;

    reg [63:0] rom [0:NUM_LAYERS-1];

    initial begin
        $readmemh(MEMFILE, rom);
    end

    // Synchronous read: decode all fields from packed ROM word
    always @(posedge clk) begin
        op_type          <= rom[layer_index][62:60];
        kernel_size_J    <= rom[layer_index][59:56];
        in_channels_K    <= rom[layer_index][55:48];
        out_channels_N   <= rom[layer_index][47:40];
        out_length_Y     <= rom[layer_index][39:30];
        stride           <= rom[layer_index][29:28];
        weight_base_addr <= rom[layer_index][27:12];
        bias_base_addr   <= rom[layer_index][11:4];
        residual_source  <= rom[layer_index][3:0];
    end

endmodule
