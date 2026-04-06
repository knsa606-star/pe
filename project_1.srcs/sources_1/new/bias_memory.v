// ====================================================================
// Bias Memory for MINA Accelerator
// Stores biases b[n] for each output channel
// ====================================================================
`timescale 1ns / 1ps
module bias_memory #(
    parameter DATA_WIDTH = 16,
    parameter DEPTH      = 64,
    parameter MEMFILE    = "./bias.mem"
)(
    input  wire clk,
    input  wire [$clog2(DEPTH)-1:0] addr,
    output reg [DATA_WIDTH-1:0] data_out
);

    reg [DATA_WIDTH-1:0] ram [0:DEPTH-1];

    initial begin
        $display("Loading BIAS memory file: %s", MEMFILE);
        $readmemh(MEMFILE, ram);

        // Debug
        $display("First BIAS value = %h", ram[0]);
        $display("Second BIAS value = %h", ram[1]);
        $display("Third BIAS value = %h", ram[2]);
    end

    always @(posedge clk) begin
        data_out <= ram[addr];
    end

endmodule

