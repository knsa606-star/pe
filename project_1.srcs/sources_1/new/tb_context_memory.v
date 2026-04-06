`timescale 1ns / 1ps
// ====================================================================
// Testbench: context_memory
// Reads all 8 layer entries and prints decoded parameters
// ====================================================================

module tb_context_memory();

    localparam NUM_LAYERS = 8;

    reg clk;
    reg [$clog2(NUM_LAYERS)-1:0] layer_index;

    wire [2:0]  op_type;
    wire [3:0]  kernel_J;
    wire [7:0]  in_ch_K;
    wire [7:0]  out_ch_N;
    wire [9:0]  out_len_Y;
    wire [1:0]  stride;
    wire [15:0] w_base;
    wire [7:0]  b_base;
    wire [3:0]  residual;

    // DUT
    context_memory #(
        .NUM_LAYERS(NUM_LAYERS),
        .MEMFILE("./context.mem")
    ) DUT (
        .clk            (clk),
        .layer_index    (layer_index),
        .op_type        (op_type),
        .kernel_size_J  (kernel_J),
        .in_channels_K  (in_ch_K),
        .out_channels_N (out_ch_N),
        .out_length_Y   (out_len_Y),
        .stride         (stride),
        .weight_base_addr(w_base),
        .bias_base_addr (b_base),
        .residual_source(residual)
    );

    always #5 clk = ~clk;

    integer i;

    initial begin
        $display("\n=== CONTEXT MEMORY TEST START ===\n");
        clk = 0;
        layer_index = 0;

        // Read each layer entry (1 cycle per read due to sync memory)
        for (i = 0; i < NUM_LAYERS; i = i + 1) begin
            layer_index = i;
            @(posedge clk); // present address
            @(posedge clk); // wait for registered output
            #1;
            $display("Layer %0d: op=%0d J=%0d K=%0d N=%0d Y=%0d stride=%0d w_base=%0d b_base=%0d res=%0d",
                i, op_type, kernel_J, in_ch_K, out_ch_N, out_len_Y,
                stride, w_base, b_base, residual);
        end

        $display("\n=== CONTEXT MEMORY TEST COMPLETE ===\n");
        $finish;
    end

endmodule
