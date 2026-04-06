`timescale 1ns / 1ps
// ====================================================================
// Testbench: mina_top — Full Integration Test
// Instantiates the complete MINA top module, loads ECG data,
// asserts start, waits for done, then prints results from PE[0].
// ====================================================================

module tb_mina_top();

    localparam M    = 40;
    localparam PIXW = 16;

    reg  clk, rst, start;
    wire done;
    wire [PIXW-1:0] result_out;

    // Instantiate MINA top
    mina_top #(
        .M          (M),
        .PIXW       (PIXW),
        .NUM_LAYERS (8),
        .ADDRW      (8),
        .WADDRW     (11),
        .BADDRW     (6),
        .WDEPTH     (2048),
        .BDEPTH     (64),
        .CTX_MEMFILE("./context.mem"),
        .W_MEMFILE  ("./weights.mem"),
        .B_MEMFILE  ("./bias.mem")
    ) DUT (
        .clk       (clk),
        .rst       (rst),
        .start     (start),
        .done      (done),
        .result_out(result_out)
    );

    always #5 clk = ~clk;

    integer i;

    initial begin
        $display("\n=== MINA TOP INTEGRATION TEST START ===\n");
        clk   = 0;
        rst   = 1;
        start = 0;

        #30 rst = 0;
        #10;

        $display("Asserting start...");
        start = 1;
        #10 start = 0;

        // Wait for done (up to 10000 cycles)
        begin : wait_done
            integer timeout_cnt;
            for (timeout_cnt = 0; timeout_cnt < 10000; timeout_cnt = timeout_cnt + 1) begin
                @(posedge clk);
                if (done) disable wait_done;
            end
        end

        if (done)
            $display("Computation DONE!");
        else
            $display("TIMEOUT — done not asserted within 10000 cycles");

        // Print PE[0] result (representative output)
        $display("result_out (PE[0]) = 0x%04h (%0d)", result_out, result_out);

        // Print outputs from all 40 PEs via hierarchical reference
        $display("\nAll PE outputs:");
        for (i = 0; i < M; i = i + 1) begin
            $display("  PE[%0d] = 0x%04h (%0d)", i, DUT.U_PEA.bus_out[i], DUT.U_PEA.bus_out[i]);
        end

        $display("\n=== MINA TOP INTEGRATION TEST COMPLETE ===\n");
        $finish;
    end

endmodule
