`timescale 1ns / 1ps

// ======================================================================
// 40-PE Processing Element Array with SBA + REAL ECG INPUT
// ======================================================================

module pea_40 #(
    parameter M = 40,
    parameter PIXW = 16,
    parameter ADDRW = 8
)(
    input  wire                    clk,
    input  wire                    rst,

    input  wire [2:0]              j_sel,

    input  wire [PIXW-1:0]         weight_in,
    input  wire [PIXW-1:0]         bias_in,

    input  wire [2:0]              cfg_alu,

    output wire [PIXW-1:0]         bus_out [0:M-1]
);

    // ----------------------------------------------------
    // REAL ECG DATA INPUT (from ecg.mem)
    // ----------------------------------------------------
    wire [PIXW-1:0] pixel_in [0:M-1];
    wire [PIXW-1:0] pixel_routed [0:M-1];

    // ----------------------------------------------------
    // Create 40 pixel memories (each PE gets one sample)
    // ----------------------------------------------------
    genvar i;
    generate
        for (i = 0; i < M; i = i + 1) begin : PIX_MEM_BLOCK

            pixel_memory #(
                .DATA_WIDTH(16),
                .DEPTH(320),
                .MEMFILE("./ecg.mem")
            ) U_PIX (
                .clk(clk),
                .addr(i),                 // each PE reads different sample
                .data_out(pixel_in[i])
            );

        end
    endgenerate

    // ----------------------------------------------------
    // SBA (Sharing Buffer Allocator)
    // ----------------------------------------------------
    sba_unit #(.M(M), .PIXW(PIXW)) U_SBA (
        .j_sel(j_sel),
        .pixel_in(pixel_in),
        .pixel_out(pixel_routed)
    );

    // ----------------------------------------------------
    // 40 Processing Elements
    // ----------------------------------------------------
    generate
        for (i = 0; i < M; i = i + 1) begin : PE_ARRAY

            pe_unit #(.PIXW(PIXW), .ADDRW(ADDRW)) U_PE (
                .clk(clk),
                .rst(rst),

                .px0(pixel_routed[i]),
                .px1(16'd0),
                .px2(16'd0),

                .weight_in(weight_in),
                .bias_in(bias_in),
                .cfg_alu(cfg_alu),

                .ld_en(1'b0),
                .st_en(1'b0),
                .ldm_sel(2'd0),
                .ldm_addr(0),

                .bus_in(16'd0),
                .bus_out(bus_out[i])
            );

        end
    endgenerate

endmodule
