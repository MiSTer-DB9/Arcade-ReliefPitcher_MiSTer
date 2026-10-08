// SPDX-License-Identifier: GPL-3.0-or-later
// Adapted from the Batman VAD model.
// Copyright (C) 2026 the Batman MiSTer core authors.
`timescale 1ns/1ps
module relief_vad_sync #(
	parameter int H_TOTAL   = 912,
	parameter int H_VISIBLE = 336,
	parameter int HB_MODE   = 0,
	parameter int HB_PHASE  = 0,
	parameter int HB_ACTIVE = 2 * H_VISIBLE,
	parameter bit IRQ_ONESHOT = 1'b0
)(
	input  logic        clk,
	input  logic        reset,
	input  logic        ce_14m,
	input  logic        vad_enable,
	input  logic [15:0] reg_vsy,
	input  logic [15:0] reg_vbl,
	input  logic [15:0] reg_vint,
	input  logic [15:0] reg_hsy,
	input  logic [15:0] reg_hbl,
	input  logic        irq_arm,
	input  logic        irq_ack,
	output logic [9:0]  h,
	output logic [8:0]  v,
	output logic [9:0]  hd,
	output logic        hsync_n,
	output logic        vsync_n,
	output logic        hblank,
	output logic        vblank,
	output logic        hde, vde,
	output logic [9:0]  hpos,
	output logic [8:0]  vpos,
	output logic [8:0]  v_next,
	output logic        line_start,
	output logic        frame_start,
	output logic        vblank_start,
	output logic        eof_window,
	output logic        vint_n
);
	wire [8:0] v_sy_s = reg_vsy[11:3];
	wire [2:0] v_sy_e = reg_vsy[2:0];
	wire [6:0] v_last = reg_vbl[15:9];
	wire [8:0] v_bl_s = reg_vbl[8:0];
	wire [8:0] v_int  = reg_vint[8:0];
	wire [5:0] h_sy_e2= reg_hsy[15:10];
	wire [9:0] h_sy_s = reg_hsy[9:0];
	wire [9:0] h_bl_s = reg_hbl[9:0];
	wire [4:0] h_bl_e = {reg_hbl[11], 3'b000, reg_hbl[10]};
	wire [6:0] hs_e_lo = {h_sy_e2, 1'b0};
	localparam logic [9:0] HTOT = H_TOTAL[9:0];
	wire        last_h  = (h == HTOT - 10'd1);
	wire        last_v  = v[8] & (v[6:0] == v_last);
	wire [9:0]  h_next  = last_h ? 10'd0 : (h + 10'd1);
	wire [8:0]  v_step  = last_h ? (last_v ? 9'd0 : (v + 9'd1)) : v;
	always_ff @(posedge clk) begin
		if (reset) begin
			h <= 10'd0;
			v <= 9'd0;
		end else if (ce_14m) begin
			h <= h_next;
			v <= v_step;
		end
	end
	localparam logic [9:0] HPHASE = HB_PHASE[9:0];
	always_ff @(posedge clk) begin
		if (reset)                        hd <= 10'd0;
		else if (ce_14m)                  hd <= (h_next == HPHASE) ? 10'd0
		                                        : ((hd == HTOT - 10'd1) ? 10'd0 : hd + 10'd1);
	end
	logic hs, vs;
	always_ff @(posedge clk) begin
		if (reset) begin
			hs <= 1'b0;
			vs <= 1'b0;
		end else if (ce_14m) begin
			if      (h_next == h_sy_s)                 hs <= 1'b1;
			else if (hs && (h_next[6:0] == hs_e_lo))   hs <= 1'b0;
			if (last_h) begin
				if      (v_step == v_sy_s)                 vs <= 1'b1;
				else if (vs && (v_step[2:0] == v_sy_e))    vs <= 1'b0;
			end
		end
	end
	assign hsync_n = ~hs;
	assign vsync_n = ~vs;
	logic vb;
	always_ff @(posedge clk) begin
		if (reset)                                vb <= 1'b1;
		else if (ce_14m && last_h) begin
			if      (last_v)          vb <= 1'b0;
			else if (v == v_bl_s)     vb <= 1'b1;
		end
	end
	assign vblank = vb;
	localparam logic [9:0] HBACT = HB_ACTIVE[9:0];
	logic hb_lit;
	always_ff @(posedge clk) begin
		if (reset)                        hb_lit <= 1'b1;
		else if (ce_14m) begin
			if      (h_next == h_bl_s)                            hb_lit <= 1'b1;
			else if (hb_lit && ((h_next[4:0] & h_bl_e) == h_bl_e)
			         && (h_bl_e != 5'd0))                         hb_lit <= 1'b0;
		end
	end
	assign hblank = (HB_MODE == 0) ? (hd >= HBACT) : hb_lit;
	assign hde  = ~hblank;
	assign vde  = ~vblank;
	assign hpos = {1'b0, hd[9:1]};
	assign vpos = v;
	assign v_next = last_v ? 9'd0 : (v + 9'd1);
	assign line_start   = ce_14m & (h == 10'd0);
	assign frame_start  = line_start & (v == 9'd0);
	assign vblank_start = ce_14m & last_h & (v == v_bl_s);
	assign eof_window   = vb;
	logic irq, armed;
	wire  hit = ce_14m & vad_enable & last_h & (v_step == v_int);
	always_ff @(posedge clk) begin
		if (reset) begin
			irq   <= 1'b0;
			armed <= 1'b0;
		end else begin
			if (irq_arm) armed <= 1'b1;
			if (irq_ack) irq   <= 1'b0;
			else if (hit && (armed | ~IRQ_ONESHOT)) begin
				irq <= 1'b1;
				if (IRQ_ONESHOT) armed <= 1'b0;
			end
		end
	end
	assign vint_n = ~irq;
	/* verilator lint_off UNUSEDSIGNAL */
	wire _unused = &{1'b0, reg_vsy[15:12], reg_vint[15:9], reg_hbl[15:12], 1'b0};
	/* verilator lint_on UNUSEDSIGNAL */
endmodule
