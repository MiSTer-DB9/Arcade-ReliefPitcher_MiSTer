// SPDX-License-Identifier: GPL-3.0-or-later
// Adapted from the Batman and Skull & Crossbones video models.
// Copyright (C) 2026 the Batman MiSTer core authors.
`timescale 1ns/1ps
module relief_pf #(
	parameter bit ATTR_HIGH_BYTE = 1'b1,

	parameter int XOFF           = 0,

	parameter int H_PIX          = 456
)(
	input  logic        clk,
	input  logic        reset,
	input  logic        ce_7m,
	input  logic  [8:0] px,
	input  logic  [8:0] line,
	input  logic  [8:0] line_next,
	input  logic  [8:0] xscroll,
	input  logic  [8:0] yscroll,
	input  logic [14:0] base_code,
	input  logic [14:0] base_attr,
	output logic [14:0] code_a,
	output logic [14:0] attr_a,
	input  logic [15:0] code_q,
	input  logic [15:0] attr_q,
	output logic        rom_fetch,
	output logic [19:0] rom_addr,
	input  logic [31:0] rom_group,
	input  logic        rom_valid,
	output logic        rom_late,
	output logic  [3:0] pen,
	output logic  [3:0] colour
);
	localparam int LEAD = 4;
	localparam logic [8:0] XOFFV = XOFF[8:0];
	wire [8:0] mx = px + xscroll + XOFFV;
	wire [2:0] fine_x = mx[2:0];
	wire adv = ce_7m & (fine_x == 3'd7);
	localparam logic [9:0] HPIXV = H_PIX[9:0];
	wire [9:0] pxa   = {1'b0, px} + 10'(8 * LEAD);
	wire       wrapf = (pxa >= HPIXV);
	wire [8:0] pxf   = wrapf ? 9'(pxa - HPIXV) : pxa[8:0];
	wire [8:0] linef = wrapf ? line_next : line;
	wire [8:0] mxf = pxf   + xscroll + XOFFV;
	wire [8:0] myf = linef + yscroll;
	logic [5:0] col_l, row_l;
	logic [2:0] finey_l;
	always_ff @(posedge clk) begin
		if (reset) begin
			col_l   <= 6'd0;
			row_l   <= 6'd0;
			finey_l <= 3'd0;
		end else if (adv) begin
			col_l   <= mxf[8:3];
			row_l   <= myf[8:3];
			finey_l <= myf[2:0];
		end
	end
	wire [14:0] tile_idx = {3'b000, col_l, row_l};
	assign code_a = base_code + tile_idx;
	assign attr_a = base_attr + tile_idx;
	localparam int DEPTH = (LEAD < 2) ? 1 : (LEAD - 1);
	logic [15:0] rcode [0:DEPTH-1];
	logic [15:0] rattr [0:DEPTH-1];
	integer i;
	logic [31:0] gp, g1, g0;
	logic        busy, arm;
	wire rom_done = arm & rom_valid;
	always_ff @(posedge clk) begin
		rom_fetch <= 1'b0;
		rom_late  <= 1'b0;
		if (reset) begin
			for (i = 0; i < DEPTH; i = i + 1) begin
				rcode[i] <= 16'h0000;
				rattr[i] <= 16'h0000;
			end
			gp <= 32'd0; g1 <= 32'd0; g0 <= 32'd0;
			busy     <= 1'b0;
			arm      <= 1'b0;
			rom_addr <= 20'd0;
		end else begin
			if (!adv && !rom_fetch) arm <= 1'b1;
			if (rom_done) begin
				gp   <= rom_group;
				busy <= 1'b0;
			end
			if (adv) begin
				arm <= 1'b0;
				for (i = 0; i < DEPTH-1; i = i + 1) begin
					rcode[i] <= rcode[i+1];
					rattr[i] <= rattr[i+1];
				end
				rcode[DEPTH-1] <= code_q;
				rattr[DEPTH-1] <= attr_q;
				g0 <= g1;
				g1 <= rom_done ? rom_group : gp;
				rom_addr  <= {code_q[14:0], finey_l[2:1], 2'b00, finey_l[0]};
				rom_fetch <= 1'b1;
				rom_late  <= busy && !rom_done;
				busy      <= 1'b1;
			end
		end
	end
	wire       hflip = rcode[0][15];
	wire [2:0] bsel  = hflip ? fine_x : (3'd7 - fine_x);
	wire [3:0] raw_pen = { g0[{2'd3, bsel}], g0[{2'd2, bsel}],
	                       g0[{2'd1, bsel}], g0[{2'd0, bsel}] };
	logic [15:0] attr_w;
	always_ff @(posedge clk) begin
		if (reset) begin
			pen    <= 4'd0;
			attr_w <= 16'h0000;
		end else if (ce_7m) begin
			pen    <= ~raw_pen;
			attr_w <= rattr[0];
		end
	end
	assign colour = ATTR_HIGH_BYTE ? attr_w[11:8]  : attr_w[3:0];

	/* verilator lint_off UNUSEDSIGNAL */
	wire _unused = &{1'b0, attr_w[15:12], attr_w[7:4], mx[8:3], mxf[2:0],
	                 pxa[9], 1'b0};
	/* verilator lint_on UNUSEDSIGNAL */
endmodule
