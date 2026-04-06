`timescale 1ns/1ps

module tb_sba_unit();

    localparam M = 40;
    localparam PIXW = 16;

    reg [2:0] j_sel;

    // Pixel input array
    reg  [PIXW-1:0] pixel_in  [0:M-1];
    wire [PIXW-1:0] pixel_out [0:M-1];

    // Instantiate SBA
    sba_unit #(.M(M), .PIXW(PIXW)) DUT (
        .j_sel(j_sel),
        .pixel_in(pixel_in),
        .pixel_out(pixel_out)
    );

    integer i;

    initial begin
        $display("\n========= SBA TEST START =========\n");

        // Load pixel_in with values 0..39
        for (i = 0; i < M; i = i + 1) begin
            pixel_in[i] = i;
        end

        // Test for j = 0,1,2,3
        for (j_sel = 0; j_sel < 4; j_sel = j_sel + 1) begin
            #5;
            $display("\n--- j_sel = %0d ---", j_sel);

            for (i = 0; i < M; i = i + 1) begin
                $display("pixel_out[%0d] = %0d", i, pixel_out[i]);
            end
        end

        $display("\n========= SBA TEST COMPLETE =========\n");
        $finish;
    end

endmodule
