// SPDX-License-Identifier: GPL-3.0-or-later
// Adapted from the Batman video DAC.
// Copyright (C) 2026 the Batman MiSTer core authors.
module relief_dac #(
    parameter bit BLACK_CLAMP=1'b1
)(
    input wire [15:0] colour,
    output wire [7:0] red,green,blue
);
    wire [4:0] r5=colour[14:10],g5=colour[9:5],b5=colour[4:0];
    wire [5:0] r6={r5,colour[15]},g6={g5,colour[15]},b6={b5,colour[15]};
    assign red=BLACK_CLAMP && r5 == 0 ? 8'd0 : {r6,r6[5:4]};
    assign green=BLACK_CLAMP && g5 == 0 ? 8'd0 : {g6,g6[5:4]};
    assign blue=BLACK_CLAMP && b5 == 0 ? 8'd0 : {b6,b6[5:4]};
endmodule
