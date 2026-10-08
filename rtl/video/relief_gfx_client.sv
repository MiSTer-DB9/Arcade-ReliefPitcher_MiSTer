// SPDX-License-Identifier: GPL-3.0-or-later
// Adapted from the Batman and Skull & Crossbones video models.
// Copyright (C) 2026 the Skull & Crossbones MiSTer core authors.
`timescale 1ns/1ps
module relief_gfx_client #(
	parameter int AW     = 21,
	parameter int GROUP  = 16,
	parameter int BEATS  = 5,
	parameter int STRIDE = 2
)(
	input  logic          clk,
	input  logic          reset,
	input  logic          fetch,
	input  logic [AW-1:0] fetch_addr,
	output logic [8*BEATS-1:0] data,
	output logic          data_valid,
	output logic          late,
	output logic          req,
	output logic [AW-1:0] addr,
	output logic [3:0]    blen,
	input  logic          ack,
	input  logic [8*GROUP-1:0] group
);
	localparam int GB = $clog2(GROUP);
	logic [8*BEATS-1:0] data_r;
	logic               busy;
	logic [GB-1:0]      base;
	assign data = data_r;
	assign blen = BEATS[3:0];
	logic [8*BEATS-1:0] pick;
	always_comb begin
		pick = '0;
		for (int k = 0; k < BEATS; k++)
			pick[8*k +: 8] = group[8*((int'(base) + k*STRIDE) % GROUP) +: 8];
	end
	always_ff @(posedge clk) begin
		late <= 1'b0;
		if (reset) begin
			req        <= 1'b0;
			addr       <= '0;
			base       <= '0;
			busy       <= 1'b0;
			data_r     <= '0;
			data_valid <= 1'b0;
		end else begin
			if (fetch) begin
				data_valid <= 1'b0;
				if (busy) late <= 1'b1;
			end
			if (busy) begin
				if (req && ack) begin
					req        <= 1'b0;
					busy       <= 1'b0;
					data_valid <= 1'b1;
					data_r     <= pick;
				end
			end else if (fetch) begin
				busy <= 1'b1;
				addr <= fetch_addr;
				base <= fetch_addr[GB-1:0];
				req  <= 1'b1;
			end
		end
	end
endmodule
