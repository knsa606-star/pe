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
        .WADDRW     (13),
        .BADDRW     (7),
        .WDEPTH     (8192),
        .BDEPTH     (128),
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

        // Wait for done (up to 100000 cycles)
        begin : wait_done
            integer timeout_cnt;
            for (timeout_cnt = 0; timeout_cnt < 100000; timeout_cnt = timeout_cnt + 1) begin
                @(posedge clk);
                if (done) disable wait_done;
            end
        end

        if (done) begin
            $display("Computation DONE!");
            $display("result_out (PE[0]) = 0x%04h (%0d)", result_out, result_out);

            // Show PE[0] internal state
            $display("\nPE[0] mac_accum = %0d", DUT.U_PEA.PE_ARRAY[0].U_PE.mac_accum);
            $display("PE[0] alu_out   = 0x%04h", DUT.U_PEA.PE_ARRAY[0].U_PE.alu_out);
            $display("PE[0] LDM0[0]   = 0x%04h", DUT.U_PEA.PE_ARRAY[0].U_PE.LDM0[0]);
            $display("PE[0] LDM0[1]   = 0x%04h", DUT.U_PEA.PE_ARRAY[0].U_PE.LDM0[1]);
            $display("PE[0] LDM0[2]   = 0x%04h", DUT.U_PEA.PE_ARRAY[0].U_PE.LDM0[2]);
            $display("PE[0] LDM0[3]   = 0x%04h", DUT.U_PEA.PE_ARRAY[0].U_PE.LDM0[3]);
            $display("PE[0] LDM0[4]   = 0x%04h", DUT.U_PEA.PE_ARRAY[0].U_PE.LDM0[4]);
            $display("PE[0] LDM0[5]   = 0x%04h", DUT.U_PEA.PE_ARRAY[0].U_PE.LDM0[5]);
            $display("PE[0] LDM0[6]   = 0x%04h", DUT.U_PEA.PE_ARRAY[0].U_PE.LDM0[6]);
            $display("PE[0] LDM0[7]   = 0x%04h", DUT.U_PEA.PE_ARRAY[0].U_PE.LDM0[7]);
        end else
            $display("TIMEOUT — done not asserted within 100000 cycles");

        // Print outputs from all 40 PEs via hierarchical reference
        $display("\nAll PE outputs:");
        for (i = 0; i < M; i = i + 1) begin
            $display("  PE[%0d] = 0x%04h (%0d)", i, DUT.U_PEA.bus_out[i], DUT.U_PEA.bus_out[i]);
        end

        $display("\n=== MINA TOP INTEGRATION TEST COMPLETE ===\n");
        $finish;
    end

endmodule
