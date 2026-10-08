// SPDX-License-Identifier: GPL-3.0-or-later
// Adapted from the Batman and Skull & Crossbones graphics arbiter.
// Copyright (C) 2026 the Skull & Crossbones MiSTer core authors.
`timescale 1ns/1ps
module relief_gfx_mem #(
	parameter int AW = 24,
	parameter logic [AW-1:0] PF_BASE  = 24'h040000,
	parameter logic [AW-1:0] MO_BASE  = 24'h0C0000,
	parameter logic [AW-1:0] OKI_BASE = 24'h1C0000,
	parameter int RFSH_DEFER_MAX = 512
)(
	input  logic          clk,
	input  logic          reset,
	input  logic          downloading,
	input  logic          cpu_req,
	input  logic [AW-1:0] cpu_addr,
	input  logic  [1:0]   cpu_blen,
	output logic          cpu_valid,
	output logic          cpu_last,
	output logic [15:0]   cpu_rdata,
	input  logic          pf1_req,
	input  logic [19:0]   pf1_addr,
	output logic          pf1_ack,
	output logic  [7:0]   pf1_data,
	output logic [63:0]   pf1_group,
	input  logic          pf2_req,
	input  logic [19:0]   pf2_addr,
	output logic          pf2_ack,
	output logic  [7:0]   pf2_data,
	output logic [63:0]   pf2_group,
	input  logic          mo_req,
	input  logic [20:0]   mo_addr,
	output logic          mo_ack,
	output logic  [7:0]   mo_data,
	output logic [127:0]  mo_group,
	input  logic          oki_req,
	input  logic [19:0]   oki_addr,
	output logic          oki_ack,
	output logic  [7:0]   oki_data,
	input  logic          dl_wr,
	input  logic [AW-1:0] dl_waddr,
	input  logic [15:0]   dl_wdata,
	output logic          dl_ack,
	output logic          sd_req,
	output logic [AW-1:0] sd_addr,
	output logic          sd_we,
	output logic  [2:0]   sd_blen,
	output logic [15:0]   sd_wdata,
	output logic          rfsh_ok,
	output wire           idle,
	input  logic          sd_ready,
	input  logic          sd_valid,
	input  logic [15:0]   sd_rdata
);
	logic [15:0] pf1_buf [0:3];   logic [16:0] pf1_tag;  logic pf1_bufv;
	logic [15:0] pf2_buf [0:3];   logic [16:0] pf2_tag;  logic pf2_bufv;
	logic [15:0] mo_buf  [0:7];   logic [16:0] mo_tag;   logic mo_bufv;
	logic [15:0] oki_buf [0:3];   logic [16:0] oki_tag;  logic oki_bufv;
	wire pf1_hit = pf1_bufv && (pf1_tag == pf1_addr[19:3]);
	wire pf2_hit = pf2_bufv && (pf2_tag == pf2_addr[19:3]);
	wire mo_hit  = mo_bufv  && (mo_tag  == mo_addr[20:4]);
	wire oki_hit = oki_bufv && (oki_tag == oki_addr[19:3]);
	typedef enum logic [1:0] { C_IDLE, C_MISS, C_HOLD } cstate_t;
	cstate_t pf1_st, pf2_st, mo_st, oki_st;
	logic pf1_fill, pf2_fill, mo_fill, oki_fill;
	typedef enum logic [1:0] { G_IDLE, G_REQ, G_WAIT, G_HOLD } gstate_t;
	gstate_t st;
	typedef enum logic [2:0] { OP_WR, OP_CPU, OP_MO, OP_PF1, OP_PF2, OP_OKI } op_t;
	op_t op;
	logic [2:0]  wcnt;
	logic flushing, cpu_claimed;
	wire clients_reset = downloading || flushing;
	assign idle = st == G_IDLE && sd_ready && !dl_wr && !flushing;
	logic [19:0] pf1_addr_l, pf2_addr_l, oki_addr_l;
	logic [20:0] mo_addr_l;
	always_ff @(posedge clk) begin
		if (reset) begin
			flushing <= 1'b0;
			cpu_claimed <= 1'b0;
		end else begin
			if (downloading) flushing <= 1'b1;
			else if (st == G_IDLE && sd_ready) flushing <= 1'b0;
			if (!cpu_req) cpu_claimed <= 1'b0;
			else if (st == G_IDLE && !dl_wr && take_cpu && sd_ready)
				cpu_claimed <= 1'b1;
		end
	end
	wire pf1_need = (pf1_st == C_MISS);
	wire pf2_need = (pf2_st == C_MISS);
	wire mo_need  = (mo_st  == C_MISS);
	wire oki_need = (oki_st == C_MISS);
	wire pf1_pending = pf1_need || (pf1_req && pf1_st == C_IDLE);
	wire pf2_pending = pf2_need || (pf2_req && pf2_st == C_IDLE);
	wire mo_pending = mo_need || (mo_req && mo_st == C_IDLE);
	wire gfx_pending = pf1_pending || pf2_pending || mo_pending;
	wire take_cpu = cpu_req && !cpu_claimed && !clients_reset && !gfx_pending;
	localparam int DEFER_W = $clog2(RFSH_DEFER_MAX + 1);
	logic [DEFER_W-1:0] defer;
	wire rfsh_win = (st == G_IDLE) && !dl_wr
	             && !cpu_req && !pf1_req && !pf2_req && !mo_req && !oki_req
	             && !pf1_need && !pf2_need && !mo_need && !oki_need;
	assign rfsh_ok = rfsh_win || (defer >= DEFER_W'(RFSH_DEFER_MAX));
	always_ff @(posedge clk) begin
		if (reset)         defer <= '0;
		else if (rfsh_ok)  defer <= '0;
		else if (defer != DEFER_W'(RFSH_DEFER_MAX)) defer <= defer + 1'b1;
	end
	wire take_pf1 = pf1_need && !clients_reset;
	wire take_pf2 = pf2_need && !pf1_pending && !clients_reset;
	wire take_mo  = mo_need  && !pf1_pending && !pf2_pending && !clients_reset;
	wire [AW-1:0] pf1_wa = PF_BASE  + {{(AW-19){1'b0}}, pf1_addr_l[19:3], 2'b00};
	wire [AW-1:0] pf2_wa = PF_BASE  + {{(AW-19){1'b0}}, pf2_addr_l[19:3], 2'b00};
	wire [AW-1:0] mo_wa  = MO_BASE  + {{(AW-20){1'b0}}, mo_addr_l[20:4],  3'b000};
	wire [AW-1:0] oki_wa = OKI_BASE + {{(AW-19){1'b0}}, oki_addr_l[19:3], 2'b00};
	logic [16:0] pf1_tag_l;
	logic [16:0] pf2_tag_l;
	logic [16:0] mo_tag_l;
	logic [16:0] oki_tag_l;
	logic [2:0] blen_l;
	wire  [2:0] wlast = blen_l;
	always_ff @(posedge clk) begin
		if (reset) begin
			st <= G_IDLE; sd_req <= 1'b0; sd_we <= 1'b0; sd_blen <= 3'd0;
			dl_ack <= 1'b0;
			pf1_fill <= 1'b0; pf2_fill <= 1'b0;
			mo_fill <= 1'b0; oki_fill <= 1'b0;
			pf1_bufv <= 1'b0; pf2_bufv <= 1'b0;
			mo_bufv <= 1'b0; oki_bufv <= 1'b0;
			cpu_valid <= 1'b0; cpu_last <= 1'b0;
			op <= OP_WR; blen_l <= 3'd0;
		end else begin
			dl_ack    <= 1'b0;
			sd_req    <= 1'b0;
			pf1_fill  <= 1'b0;
			pf2_fill  <= 1'b0;
			mo_fill   <= 1'b0;
			oki_fill  <= 1'b0;
			cpu_valid <= 1'b0;
			cpu_last  <= 1'b0;
			case (st)
				G_IDLE: begin
					wcnt <= 3'd0;
					if (dl_wr) begin
						op <= OP_WR; sd_addr <= dl_waddr; sd_we <= 1'b1;
						sd_blen <= 3'd0; blen_l <= 3'd0; sd_wdata <= dl_wdata;
						if (sd_ready) begin sd_req <= 1'b1; st <= G_REQ; end
					end else if (take_pf1) begin
						op <= OP_PF1; sd_addr <= pf1_wa; sd_we <= 1'b0;
						sd_blen <= 3'd3; blen_l <= 3'd3;
						pf1_tag_l <= pf1_addr_l[19:3];
						if (sd_ready) begin sd_req <= 1'b1; st <= G_REQ; end
					end else if (take_pf2) begin
						op <= OP_PF2; sd_addr <= pf2_wa; sd_we <= 1'b0;
						sd_blen <= 3'd3; blen_l <= 3'd3;
						pf2_tag_l <= pf2_addr_l[19:3];
						if (sd_ready) begin sd_req <= 1'b1; st <= G_REQ; end
					end else if (take_mo) begin
						op <= OP_MO; sd_addr <= mo_wa; sd_we <= 1'b0;
						sd_blen <= 3'd7; blen_l <= 3'd7;
						mo_tag_l <= mo_addr_l[20:4];
						if (sd_ready) begin sd_req <= 1'b1; st <= G_REQ; end
					end else if (take_cpu) begin
						op <= OP_CPU; sd_addr <= cpu_addr; sd_we <= 1'b0;
						sd_blen <= {1'b0, cpu_blen}; blen_l <= {1'b0, cpu_blen};
						if (sd_ready) begin sd_req <= 1'b1; st <= G_REQ; end
					end else if (oki_need && !clients_reset && !gfx_pending) begin
						op <= OP_OKI; sd_addr <= oki_wa; sd_we <= 1'b0;
						sd_blen <= 3'd3; blen_l <= 3'd3;
						oki_tag_l <= oki_addr_l[19:3];
						if (sd_ready) begin sd_req <= 1'b1; st <= G_REQ; end
					end
				end
				G_REQ: begin
					sd_req <= 1'b0; sd_we <= 1'b0;
					st <= G_WAIT;
				end
				G_WAIT: begin
					if (op == OP_WR) begin
						if (sd_ready) begin dl_ack <= 1'b1; st <= G_HOLD; end
					end else if (sd_valid) begin
						wcnt <= wcnt + 3'd1;
						case (op)
							OP_CPU: begin
								cpu_rdata <= sd_rdata;
								cpu_valid <= 1'b1;
								if (wcnt == wlast) begin cpu_last <= 1'b1; st <= G_HOLD; end
							end
							OP_MO: begin
								mo_buf[wcnt] <= sd_rdata;
								if (wcnt == wlast) begin
									mo_tag  <= mo_tag_l;
									mo_bufv <= 1'b1;
									mo_fill <= 1'b1;
									st      <= G_HOLD;
								end
							end
							OP_PF1: begin
								pf1_buf[wcnt[1:0]] <= sd_rdata;
								if (wcnt == wlast) begin
									pf1_tag  <= pf1_tag_l;
									pf1_bufv <= 1'b1;
									pf1_fill <= 1'b1;
									st       <= G_HOLD;
								end
							end
							OP_PF2: begin
								pf2_buf[wcnt[1:0]] <= sd_rdata;
								if (wcnt == wlast) begin
									pf2_tag  <= pf2_tag_l;
									pf2_bufv <= 1'b1;
									pf2_fill <= 1'b1;
									st       <= G_HOLD;
								end
							end
							default: begin
								oki_buf[wcnt[1:0]] <= sd_rdata;
								if (wcnt == wlast) begin
									oki_tag  <= oki_tag_l;
									oki_bufv <= 1'b1;
									oki_fill <= 1'b1;
									st       <= G_HOLD;
								end
							end
						endcase
					end
				end
				G_HOLD: begin
					case (op)
						OP_WR:   if (!dl_wr)           st <= G_IDLE;
						OP_CPU:                       st <= G_IDLE;
						OP_MO:   if (mo_st  != C_MISS) st <= G_IDLE;
						OP_PF1:  if (pf1_st != C_MISS) st <= G_IDLE;
						OP_PF2:  if (pf2_st != C_MISS) st <= G_IDLE;
						default: if (oki_st != C_MISS) st <= G_IDLE;
					endcase
				end
				default: st <= G_IDLE;
			endcase
			if (dl_wr || clients_reset) begin
				pf1_bufv <= 1'b0; pf2_bufv <= 1'b0;
				mo_bufv <= 1'b0; oki_bufv <= 1'b0;
			end
		end
	end
	wire [2:0] pf1_offset = pf1_st == C_IDLE ? pf1_addr[2:0] : pf1_addr_l[2:0];
	wire [15:0] pf1_w = pf1_buf[pf1_offset[2:1]];
	wire [2:0] pf2_offset = pf2_st == C_IDLE ? pf2_addr[2:0] : pf2_addr_l[2:0];
	wire [15:0] pf2_w = pf2_buf[pf2_offset[2:1]];
	wire [3:0] mo_offset = mo_st == C_IDLE ? mo_addr[3:0] : mo_addr_l[3:0];
	wire [15:0] mo_w  = mo_buf [mo_offset[3:1]];
	wire [2:0] oki_offset = oki_st == C_IDLE ? oki_addr[2:0] : oki_addr_l[2:0];
	wire [15:0] oki_w = oki_buf[oki_offset[2:1]];
	wire  [7:0] pf1_b = pf1_offset[0] ? pf1_w[7:0] : pf1_w[15:8];
	wire  [7:0] pf2_b = pf2_offset[0] ? pf2_w[7:0] : pf2_w[15:8];
	wire  [7:0] mo_b  = mo_offset[0]  ? mo_w[7:0]  : mo_w[15:8];
	wire  [7:0] oki_b = oki_offset[0] ? oki_w[7:0] : oki_w[15:8];
	wire [63:0] pf1_grp_w = { pf1_buf[3][7:0], pf1_buf[3][15:8],
	                          pf1_buf[2][7:0], pf1_buf[2][15:8],
	                          pf1_buf[1][7:0], pf1_buf[1][15:8],
	                          pf1_buf[0][7:0], pf1_buf[0][15:8] };
	wire [63:0] pf2_grp_w = { pf2_buf[3][7:0], pf2_buf[3][15:8],
	                          pf2_buf[2][7:0], pf2_buf[2][15:8],
	                          pf2_buf[1][7:0], pf2_buf[1][15:8],
	                          pf2_buf[0][7:0], pf2_buf[0][15:8] };
	wire [127:0] mo_grp_w = { mo_buf[7][7:0], mo_buf[7][15:8],
	                          mo_buf[6][7:0], mo_buf[6][15:8],
	                          mo_buf[5][7:0], mo_buf[5][15:8],
	                          mo_buf[4][7:0], mo_buf[4][15:8],
	                          mo_buf[3][7:0], mo_buf[3][15:8],
	                          mo_buf[2][7:0], mo_buf[2][15:8],
	                          mo_buf[1][7:0], mo_buf[1][15:8],
	                          mo_buf[0][7:0], mo_buf[0][15:8] };
	always_ff @(posedge clk) begin
		if (reset || clients_reset) begin
			pf1_st <= C_IDLE; pf1_ack <= 1'b0; pf1_data <= 8'h00;
			pf2_st <= C_IDLE; pf2_ack <= 1'b0; pf2_data <= 8'h00;
			pf1_group <= 64'd0; pf2_group <= 64'd0; mo_group <= 128'd0;
			mo_st  <= C_IDLE; mo_ack  <= 1'b0; mo_data  <= 8'h00;
			oki_st <= C_IDLE; oki_ack <= 1'b0; oki_data <= 8'h00;
		end else begin
			pf1_ack <= 1'b0;
			pf2_ack <= 1'b0;
			mo_ack  <= 1'b0;
			oki_ack <= 1'b0;
			case (pf1_st)
				C_IDLE: if (pf1_req && !dl_wr) begin
					pf1_addr_l <= pf1_addr;
					if (pf1_hit) begin
						pf1_data  <= pf1_b;
						pf1_group <= pf1_grp_w;
						pf1_ack   <= 1'b1;
						pf1_st    <= C_HOLD;
					end else pf1_st <= C_MISS;
				end
				C_MISS: if (pf1_fill) begin
					pf1_data  <= pf1_b;
					pf1_group <= pf1_grp_w;
					pf1_ack   <= 1'b1;
					pf1_st    <= C_HOLD;
				end
				default: if (!pf1_req) pf1_st <= C_IDLE;
			endcase
			case (pf2_st)
				C_IDLE: if (pf2_req && !dl_wr) begin
					pf2_addr_l <= pf2_addr;
					if (pf2_hit) begin
						pf2_data  <= pf2_b;
						pf2_group <= pf2_grp_w;
						pf2_ack   <= 1'b1;
						pf2_st    <= C_HOLD;
					end else pf2_st <= C_MISS;
				end
				C_MISS: if (pf2_fill) begin
					pf2_data  <= pf2_b;
					pf2_group <= pf2_grp_w;
					pf2_ack   <= 1'b1;
					pf2_st    <= C_HOLD;
				end
				default: if (!pf2_req) pf2_st <= C_IDLE;
			endcase
			case (mo_st)
				C_IDLE: if (mo_req && !dl_wr) begin
					mo_addr_l <= mo_addr;
					if (mo_hit) begin
						mo_data  <= mo_b;
						mo_group <= mo_grp_w;
						mo_ack   <= 1'b1;
						mo_st   <= C_HOLD;
					end else mo_st <= C_MISS;
				end
				C_MISS: if (mo_fill) begin
					mo_data  <= mo_b;
					mo_group <= mo_grp_w;
					mo_ack   <= 1'b1;
					mo_st   <= C_HOLD;
				end
				default: if (!mo_req) mo_st <= C_IDLE;
			endcase
			case (oki_st)
				C_IDLE: if (oki_req && !dl_wr) begin
					oki_addr_l <= oki_addr;
					if (oki_hit) begin
						oki_data <= oki_b;
						oki_ack  <= 1'b1;
						oki_st   <= C_HOLD;
					end else oki_st <= C_MISS;
				end
				C_MISS: if (oki_fill) begin
					oki_data <= oki_b;
					oki_ack  <= 1'b1;
					oki_st   <= C_HOLD;
				end
				default: if (!oki_req) oki_st <= C_IDLE;
			endcase
		end
	end
endmodule
