// SPDX-License-Identifier: GPL-3.0-or-later
// Raw inverted-ROM plane bytes, plane zero in the low byte.
module relief_gfx_pixel (
    input wire [39:0] raw,
    input wire sprite,hflip,
    input wire [2:0] x,
    output wire [4:0] pen
);
    wire [2:0] bsel=hflip ? x : (3'd7-x);
    assign pen={sprite & ~raw[{3'd4,bsel}],~raw[{3'd3,bsel}],
                ~raw[{3'd2,bsel}],~raw[{3'd1,bsel}],~raw[{3'd0,bsel}]};
endmodule
