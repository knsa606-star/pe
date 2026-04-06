`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 21.03.2026 13:58:58
// Design Name: 
// Module Name: pe_unit
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


// ===================================================================
//  PE Unit for MINA
//  4 Local Data Memories (LDM0..LDM3)
//  ALU supporting MAC, ADD, MAXPOOL, RELU
//  LSU for load/store from/to internal bus
// ===================================================================

module pe_unit #(
    parameter PIXW  = 16,
    parameter ADDRW = 10      // depth ? 1280/40 = 32 entries (paper)
)(
    input  wire                   clk,
    input  wire                   rst,

    // Incoming pixel values (SBA routed)
    input  wire [PIXW-1:0] px0,
    input  wire [PIXW-1:0] px1,
    input  wire [PIXW-1:0] px2,

    // Weight & bias
    input  wire [PIXW-1:0] weight_in,
    input  wire [PIXW-1:0] bias_in,

    // ALU control (from PEA controller)
    input  wire [2:0] cfg_alu,
    // 000 = MAC
    // 001 = ADD
    // 010 = MAXPOOL
    // 011 = RELU
    // 100 = PASS THROUGH

    // LSU control
    input  wire        ld_en,
    input  wire        st_en,
    input  wire [1:0]  ldm_sel,   // choose LDM0..LDM3
    input  wire [ADDRW-1:0] ldm_addr,

    // Internal bus connection
    input  wire [PIXW-1:0] bus_in,
    output reg  [PIXW-1:0] bus_out
);

    // -------------------------------------------------------------------
    // 4 Local Data Memories
    // -------------------------------------------------------------------
    reg [PIXW-1:0] LDM0 [(1<<ADDRW)-1:0];
    reg [PIXW-1:0] LDM1 [(1<<ADDRW)-1:0];
    reg [PIXW-1:0] LDM2 [(1<<ADDRW)-1:0];
    reg [PIXW-1:0] LDM3 [(1<<ADDRW)-1:0];

    reg [PIXW-1:0] ldm_read;

    // Select LDM
    always @(*) begin
        case(ldm_sel)
            2'd0: ldm_read = LDM0[ldm_addr];
            2'd1: ldm_read = LDM1[ldm_addr];
            2'd2: ldm_read = LDM2[ldm_addr];
            2'd3: ldm_read = LDM3[ldm_addr];
        endcase
    end

    // Writes
    always @(posedge clk) begin
        if (st_en) begin
            case(ldm_sel)
                2'd0: LDM0[ldm_addr] <= bus_in;
                2'd1: LDM1[ldm_addr] <= bus_in;
                2'd2: LDM2[ldm_addr] <= bus_in;
                2'd3: LDM3[ldm_addr] <= bus_in;
            endcase
        end
    end

    // -------------------------------------------------------------------
    // ALU
    // -------------------------------------------------------------------
    reg [PIXW-1:0] alu_out;
    reg [31:0] mac_accum;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mac_accum <= 0;
        end else begin
            case (cfg_alu)

                // -------------------------
                // MAC: (weight * px0) + acc
                // -------------------------
                // MAC operation
                3'b000: begin
                    mac_accum <= mac_accum + (weight_in * px0);
                    alu_out   <= mac_accum + (weight_in * px0) + bias_in;
                end




                // -------------------------
                // ADD
                // -------------------------
                3'b001: alu_out <= px0 + px1;

                // -------------------------
                // MaxPool
                // -------------------------
                3'b010: alu_out <= (px0 > px1) ? px0 : px1;

                // -------------------------
                // ReLU
                // -------------------------
                3'b011: alu_out <= (px0[PIXW-1] == 1'b1) ? 0 : px0;

                // -------------------------
                // passthrough
                // -------------------------
                default: alu_out <= px0;
            endcase
        end
    end

    // -------------------------------------------------------------------
    // LSU output to internal bus
    // -------------------------------------------------------------------
    always @(posedge clk) begin
        if (ld_en)
            bus_out <= ldm_read;
        else
            bus_out <= alu_out;
    end

endmodule
