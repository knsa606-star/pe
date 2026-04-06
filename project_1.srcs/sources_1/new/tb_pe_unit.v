`timescale 1ns/1ps

module tb_pe_unit();

    // Parameters
    localparam PIXW  = 16;
    localparam ADDRW = 8; // enough for LDM testing

    // DUT signals
    reg clk;
    reg rst;

    // Pixel inputs
    reg  [PIXW-1:0] px0, px1, px2;

    // Weight/Bias
    reg  [PIXW-1:0] weight_in;
    reg  [PIXW-1:0] bias_in;

    // Controls
    reg  [2:0] cfg_alu;
    reg        ld_en;
    reg        st_en;
    reg  [1:0] ldm_sel;
    reg  [ADDRW-1:0] ldm_addr;

    // Internal bus
    reg  [PIXW-1:0] bus_in;
    wire [PIXW-1:0] bus_out;

    // Instantiate PE
    pe_unit #(
        .PIXW(PIXW),
        .ADDRW(ADDRW)
    ) DUT (
        .clk(clk),
        .rst(rst),
        .px0(px0),
        .px1(px1),
        .px2(px2),
        .weight_in(weight_in),
        .bias_in(bias_in),
        .cfg_alu(cfg_alu),
        .ld_en(ld_en),
        .st_en(st_en),
        .ldm_sel(ldm_sel),
        .ldm_addr(ldm_addr),
        .bus_in(bus_in),
        .bus_out(bus_out)
    );

    // Clock generator
    always #5 clk = ~clk; // 100 MHz

    // Test procedure
    initial begin
        $display("\n=== PE UNIT TEST START ===\n");

        clk = 0;
        rst = 1;
        px0 = 0; px1 = 0; px2 = 0;
        weight_in = 0;
        bias_in = 0;
        cfg_alu = 3'b000;
        ld_en = 0; st_en = 0;
        ldm_sel = 0;
        ldm_addr = 0;
        bus_in = 0;

        // Release reset
        #20 rst = 0;

        // --------------------------------------------------------
        // TEST 1: STORE values in LDM0
        // --------------------------------------------------------
        $display("Writing values 10, 20, 30 into LDM0...");
        st_en = 1;

        ldm_sel  = 2'd0;
        
        ldm_addr = 0; bus_in = 10; #10;
        ldm_addr = 1; bus_in = 20; #10;
        ldm_addr = 2; bus_in = 30; #10;

        st_en = 0;

        // --------------------------------------------------------
        // TEST 2: LOAD from LDM0
        // --------------------------------------------------------
        $display("Reading from LDM0...");
        ld_en = 1;

        ldm_addr = 0; #10;
        $display("LDM0[0] = %d", bus_out);

        ldm_addr = 1; #10;
        $display("LDM0[1] = %d", bus_out);

        ldm_addr = 2; #10;
        $display("LDM0[2] = %d", bus_out);

        ld_en = 0;

        // --------------------------------------------------------
        // TEST 3: MAC operation
        // --------------------------------------------------------
        $display("\nTesting MAC: (px0 * weight) + bias");
        cfg_alu = 3'b000;   // MAC
        px0 = 5;
        weight_in = 3;
        bias_in = 7;

        #20;
        $display("MAC result = %d", bus_out);

        // --------------------------------------------------------
        // TEST 4: ADD
        // --------------------------------------------------------
        $display("\nTesting ADD");
        cfg_alu = 3'b001;
        px0 = 8;
        px1 = 4;

        #20;
        $display("ADD result = %d", bus_out);

        // --------------------------------------------------------
        // TEST 5: MAXPOOL
        // --------------------------------------------------------
        $display("\nTesting MAXPOOL");
        cfg_alu = 3'b010;
        px0 = 15;
        px1 = 9;

        #20;
        $display("MAXPOOL result = %d", bus_out);

        // --------------------------------------------------------
        // TEST 6: RELU
        // --------------------------------------------------------
        $display("\nTesting RELU");
        cfg_alu = 3'b011;
        px0 = -5; // negative test

        #20;
        $display("RELU result = %d", bus_out);

        $display("\n=== PE UNIT TEST COMPLETE ===\n");
        $finish;
    end

endmodule
