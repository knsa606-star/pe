`timescale 1ns/1ps

module tb_pea_40();

    localparam M = 40;
    localparam PIXW = 16;
    localparam ADDRW = 8;

    reg clk;
    reg rst;

    reg [2:0] j_sel;
    reg [PIXW-1:0] weight_in;
    reg [PIXW-1:0] bias_in;
    reg [2:0] cfg_alu;

    reg [8:0]       pixel_base_addr;
    reg             mac_clear;
    reg             bias_en;
    reg             ld_en;
    reg             st_en;
    reg [1:0]       ldm_sel;
    reg [ADDRW-1:0] ldm_addr;
    reg [PIXW-1:0]  bus_in;

    wire [PIXW-1:0] bus_out [0:M-1];

    // Instantiate PEA
    pea_40 DUT (
        .clk(clk),
        .rst(rst),
        .j_sel(j_sel),
        .weight_in(weight_in),
        .bias_in(bias_in),
        .cfg_alu(cfg_alu),
        .pixel_base_addr(pixel_base_addr),
        .mac_clear(mac_clear),
        .bias_en(bias_en),
        .ld_en(ld_en),
        .st_en(st_en),
        .ldm_sel(ldm_sel),
        .ldm_addr(ldm_addr),
        .bus_in(bus_in),
        .bus_out(bus_out)
    );

    // Clock 100 MHz
    always #5 clk = ~clk;

    integer i;

    initial begin
        $display("\n=========== PEA + SBA TEST START ===========\n");

        clk = 0;
        rst = 1;

        weight_in        = 2;
        bias_in          = 1;
        cfg_alu          = 3'b000;
        pixel_base_addr  = 9'd0;
        mac_clear        = 0;
        bias_en          = 0;
        ld_en            = 0;
        st_en            = 0;
        ldm_sel          = 2'd0;
        ldm_addr         = 0;
        bus_in           = 16'd0;

        #20 rst = 0;

        // Sweep j_sel = 0,1,2,3
        for (j_sel = 0; j_sel <= 3; j_sel = j_sel + 1) begin
            #20;
            $display("\n----- j_sel = %0d -----", j_sel);
            $display("PE OUT VALUES:");

            for (i = 0; i < M; i = i + 1) begin
                $display("PE[%0d] bus_out = %0d", i, bus_out[i]);
            end
        end

        $display("\n=========== TEST COMPLETE ===========\n");
        $finish;
    end

endmodule
