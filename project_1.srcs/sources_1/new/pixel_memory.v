`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06.04.2026 01:29:17
// Design Name: 
// Module Name: pixel_memory
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


`timescale 1ns/1ps

module pixel_memory #(
    parameter DATA_WIDTH = 16,
    parameter DEPTH = 320,
    parameter MEMFILE = "./ecg.mem"
)(
    input wire clk,
    input wire [$clog2(DEPTH)-1:0] addr,
    output reg [DATA_WIDTH-1:0] data_out
);

    reg [DATA_WIDTH-1:0] ram [0:DEPTH-1];

    initial begin
        $display("Loading ECG file...");
        $readmemh(MEMFILE, ram);
        $display("First ECG sample = %h", ram[0]);
    end

    always @(posedge clk) begin
        data_out <= ram[addr];
    end

endmodule
