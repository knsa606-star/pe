`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 24.03.2026 07:33:55
// Design Name: 
// Module Name: weight_memory
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


// ====================================================================
// Weight Memory for MINA Accelerator
// Stores all convolution weights in BRAM
// Preloaded from an external .mem file
// ====================================================================
`timescale 1ns / 1ps
module weight_memory #(
    parameter DATA_WIDTH = 16,
    parameter DEPTH      = 256,
    parameter MEMFILE = "./weights.mem"
)(
    input  wire clk,
    input  wire [$clog2(DEPTH)-1:0] addr,
    output reg [DATA_WIDTH-1:0] data_out
);

    // BRAM storage
    reg [DATA_WIDTH-1:0] ram [0:DEPTH-1];

    // Load memory
    initial begin
        $display("Loading WEIGHT memory file: %s", MEMFILE);
        $readmemh(MEMFILE, ram);

        // Debug
        $display("First WEIGHT value = %h", ram[0]);
        $display("Second WEIGHT value = %h", ram[1]);
        $display("Third WEIGHT value = %h", ram[2]);
    end

    // Synchronous read
    always @(posedge clk) begin
        data_out <= ram[addr];
    end

endmodule


