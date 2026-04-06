`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 24.03.2026 07:36:43
// Design Name: 
// Module Name: tb_weight_bias
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

module tb_weight_bias();

    localparam DATAW = 16;
    localparam DEPTH = 16;

    reg clk;
    reg [3:0] addr_w;
    reg [3:0] addr_b;

    wire [DATAW-1:0] weight_out;
    wire [DATAW-1:0] bias_out;

    // Instantiate weight memory
    weight_memory #(
        .DATA_WIDTH(DATAW),
        .DEPTH(DEPTH),
        .MEMFILE("weights.mem")
    ) U_WMEM (
        .clk(clk),
        .addr(addr_w),
        .data_out(weight_out)
    );

    // Instantiate bias memory
    bias_memory #(
        .DATA_WIDTH(DATAW),
        .DEPTH(DEPTH),
        .MEMFILE("bias.mem")
    ) U_BMEM (
        .clk(clk),
        .addr(addr_b),
        .data_out(bias_out)
    );
    

    // Clock
    always #5 clk = ~clk;

    initial begin
    
        $display("\n=== WEIGHT & BIAS MEMORY TEST START ===\n");

        clk = 0;
        addr_w = 0;
        addr_b = 0;

        #20;

        // Read first 8 weights
        repeat (8) begin
            #10;
            $display("Weight[%0d] = %h", addr_w, weight_out);
            addr_w = addr_w + 1;
        end

        // Read first 4 biases
        repeat (4) begin
            #10;
            $display("Bias[%0d] = %h", addr_b, bias_out);
            addr_b = addr_b + 1;
        end

        $display("\n=== TEST COMPLETE ===");
        $finish;
    end

endmodule
