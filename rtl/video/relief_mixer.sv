// SPDX-License-Identifier: GPL-3.0-or-later
// Colour RAM address from the two mixer GALs (3F and 5F).
// The motion object pen nibble reaches the GALs active low, and an empty
// line-buffer pixel reads as all ones, so it looks like pen 16 and never wins.
// Playfield colour bit 0 reaches 3F inverted and 3F pin 13 drives colour RAM
// address bit 4 inverted. No schematic shows these polarities; they were
// worked out from the GAL logic.
module relief_mixer (
	input  logic        clk, reset, ce,
	input  logic [8:0]  mo,          // line-buffer word; pen 0 is never written
	input  logic [3:0]  pf_pen, pf_colour,
	input  logic        background,  // front playfield transparent
	output logic [10:0] index
);
	// Motion object colour and pen share bit 4, as the 5-bit pen adds to the colour.
	wire [7:0] mpx = (mo[4:0] == 5'd0) ? 8'hF0 : {mo[8:5], 4'd0} + {3'd0, mo[4:0]};

	wire [19:12] q_3f, q_5f, drive_3f, drive_5f;
	// Pin vectors are numbered from 19 down to 1; unused pins are tied low.
	wire [19:1] pin_5f = {1'b0, q_3f[19], 8'd0, pf_pen, ~mpx[3:0], 1'b0};
	wire [19:1] pin_3f = {1'b0, background, 5'd0, q_5f[17], 2'd0,
	                      pf_colour[3:1], ~pf_colour[0], mpx[7:4], 1'b0};

	relief_gal_0005 u_3f (.clk(clk), .ce(ce), .reset(reset), .pin(pin_3f), .value(q_3f), .drive(drive_3f));
	relief_gal_0006 u_5f (.clk(clk), .ce(ce), .reset(reset), .pin(pin_5f), .value(q_5f), .drive(drive_5f));

	assign index = {1'b0, q_3f[17], q_5f[12], q_3f[16:14], ~q_3f[13], q_5f[16:13]};
	wire unused = &{1'b0, q_3f[18], q_3f[12], q_5f[19:18], drive_3f, drive_5f};
endmodule
