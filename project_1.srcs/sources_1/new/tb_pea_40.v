`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 22.03.2026 13:36:56
// Design Name: 
// Module Name: tb_pea_40
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

module tb_pea_40();

    localparam M = 40;
    localparam PIXW = 16;

    reg clk;
    reg rst;

    reg [2:0] j_sel;
    reg [PIXW-1:0] weight_in;
    reg [PIXW-1:0] bias_in;
    reg [2:0] cfg_alu;

    wire [PIXW-1:0] bus_out [0:M-1];

    // Instantiate PEA
    pea_40 DUT (
        .clk(clk),
        .rst(rst),
        .j_sel(j_sel),
        .weight_in(weight_in),
        .bias_in(bias_in),
        .cfg_alu(cfg_alu),
        .bus_out(bus_out)
    );

    // Clock 100 MHz
    always #5 clk = ~clk;

    integer i;

    initial begin
        $display("\n=========== PEA + SBA TEST START ===========\n");

        clk = 0;
        rst = 1;

        weight_in = 2;      // MAC = (pixel × 2) + bias
        bias_in   = 1;

        cfg_alu = 3'b000;   // MAC operation

        #20 rst = 0;

        // Sweep j_sel = 0,1,2,3
        foreach (j_sel) begin
            for (j_sel = 0; j_sel <= 3; j_sel = j_sel + 1) begin
                #20;
                $display("\n----- j_sel = %0d -----", j_sel);
                $display("PE OUT VALUES:");

                for (i = 0; i < M; i = i + 1) begin
                    $display("PE[%0d] bus_out = %0d", i, bus_out[i]);
                end
            end
        end

        $display("\n=========== TEST COMPLETE ===========\n");
        $finish;
    end

endmodule


