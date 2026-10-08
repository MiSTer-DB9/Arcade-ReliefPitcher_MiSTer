// SPDX-License-Identifier: GPL-3.0-or-later
// Four-bit frame counter; accesses reload the upper half of its range.
module relief_watchdog (
    input wire clk_sys, reset, vblank, select_n,
    output wire reset_n,
    output reg [3:0] count
);
    reg old_vblank;
    always @(posedge clk_sys) begin
        old_vblank <= vblank;
        if (reset) begin count<=0;old_vblank<=vblank;end
        else if (!select_n) count <= 4'd8;
        else if (vblank && !old_vblank) count <= count+4'd1;
    end
    assign reset_n = count[3] && !reset;
endmodule
