`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 21.03.2026 14:17:25
// Design Name: 
// Module Name: sba_unit
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


// ========================================================================
// SBA UNIT (Sharing Buffer Allocator)
// This routes pixel data to PEs using (m + j) % M
// ========================================================================

module sba_unit #(
    parameter M = 40,        // Number of PEs
    parameter PIXW = 16      // Bit width of each pixel
)(
    input  wire [2:0] j_sel,                  // kernel index j (0..6)
    input  wire [PIXW-1:0] pixel_in [0:M-1],  // input pixels from PEs
    output wire [PIXW-1:0] pixel_out[0:M-1]   // routed pixels
);

genvar m;
generate
    for (m = 0; m < M; m = m + 1) begin : SBA_ROUTE

        // (m + j) % M
        wire [$clog2(M):0] tmp = m + j_sel;
        wire [$clog2(M)-1:0] sel = (tmp >= M) ? tmp - M : tmp;

        assign pixel_out[m] = pixel_in[sel];

    end
endgenerate

endmodule
