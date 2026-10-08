// SPDX-License-Identifier: GPL-3.0-or-later
// Video datapath; the board mixer is connected separately.
// Copyright (C) 2026 the Batman MiSTer core authors.
`timescale 1ns/1ps
module relief_video #(
	parameter int  PF1_XOFF   = 4,
	parameter int  PF2_XOFF   = 0,
	parameter int  HB_PHASE   = 0,
	parameter int  PIPE       = 2,

	parameter int  MO_BUDGET  = 456,
	parameter int  MO_XOFF    = 0,

	parameter bit  MO_ERASE   = 1'b1,

	parameter bit  COUPLE     = 1'b1,
	parameter bit  MO_ENABLE  = 1'b1,

	parameter bit  IACK_STEALS  = 1'b0,
	parameter int  H_TOTAL    = 912,
	parameter int  H_VISIBLE  = 336
)(
	input  logic        clk,
	input  logic        reset,
	input  logic        ce_14m,
	input  logic        vram_n,
	input  logic        rw,
	input  logic [16:1] ma,
	input  logic [15:0] din,
	input  logic        wl_n,
	input  logic        wu_n,
	input  logic        iack,
	output logic [15:0] dout,
	output logic        vdtack_n,
	output logic        vint_n,




	input  logic        snap_wr,
	input  logic        snap_cr,
	input  logic [14:0] snap_a,
	input  logic [15:0] snap_d,
	output logic        pf1_req,
	output logic [19:0] pf1_addr,
	input  logic        pf1_ack,
	input  logic [63:0] pf1_group,
	output logic        pf2_req,
	output logic [19:0] pf2_addr,
	input  logic        pf2_ack,
	input  logic [63:0] pf2_group,
	output logic        mo_req,
	output logic [20:0] mo_addr,
	input  logic        mo_ack,
	input  logic [127:0] mo_group,
	input  logic [10:0] mix_index,
	output logic [3:0] mix_pf_pen, mix_pf_colour,
	output logic mix_background,
	output logic [8:0] mix_mo,
	output logic        ce_pix,
	output logic  [7:0] vga_r, vga_g, vga_b,
	output logic        hsync, vsync, hblank, vblank,
	output logic [10:0] pix_index,
	output logic        vblank_board,
	output wire         hblank_board,
	output wire [8:0]    beam_h, beam_v,
	output logic        gfx_late,
	output logic [10:0] mo_words_line,
	output logic [10:0] cpu_words_line,
	output logic [10:0] dma_words_line,
	output logic [15:0] cpu_wait_worst,
	output logic [15:0] cram_steal,
	output logic        eof_late
);
	wire        acc    = ~vram_n & ~iack;
	wire        is_vr  = ma[16];
	wire        is_reg = ~ma[16] & (ma[15:6] == 10'h3FF);
	wire        is_cr  = ~ma[16] & (ma[15:12] == 0);
	wire  [1:0] cpu_ds = {~wu_n, ~wl_n};
	wire        cpu_wr = acc & ~rw & (~wu_n | ~wl_n);
	wire        acc_arr = acc & (rw | cpu_wr);
	logic reg_written;
	always_ff @(posedge clk) begin
		if (reset || !acc) reg_written <= 1'b0;
		else if (cpu_wr && is_reg) reg_written <= 1'b1;
	end
	wire [15:0] reg_enable, reg_vsy, reg_vbl, reg_vint, reg_hsy, reg_hbl;
	wire [15:0] reg_slip, reg_apdma, reg_pmbase, reg_albase, reg_opt;
	wire [15:0] reg_mocon, reg_pcon, reg_grcon;
	wire        mob_wr;
	wire  [1:0] mob_sel;
	wire  [8:0] mo_xscroll, pf1_xscroll, pf2_xscroll, pf2_xscroll_raw;
	wire  [8:0] mo_yscroll, pf1_yscroll, pf2_yscroll;
	wire  [7:0] pf1_attr_latch, pf2_attr_latch;
	wire        oas_en, vad_enable, dma_enable, irq_arm, irq_ack;
	wire        ols_en, oslpink, osloram, o_dcdma, o_dvdma, oadroen;
	wire        ocrdwe, ovrdtack, ocrdtack, opium, opfhsiz_pf2at;
	wire        eof_req;
	wire  [5:0] eof_idx;
	wire [15:0] eof_data, reg_dout;
	wire        eof_ack;
	wire [9:0] h, hd, hpos;
	wire [8:0] v, vpos, v_next;
	wire       hsync_n, vsync_n, hblank_i, vblank_i, hde, vde;
	wire       line_start, frame_start, vblank_start, eof_window;
	relief_vad_regs #(.COUPLE_FINE(COUPLE)) u_regs (
		.clk(clk), .reset(reset),
		.cpu_cs(acc & is_reg), .cpu_we(cpu_wr & is_reg & !reg_written), .cpu_a(ma[5:1]),
		.cpu_din(din), .cpu_ds(cpu_ds), .cpu_dout(reg_dout),
		.vpos(v), .vblank(vblank_i), .vblank_start(vblank_start),
		.eof_req(eof_req), .eof_idx(eof_idx),
		.eof_data(eof_data), .eof_ack(eof_ack),
		.ls_wr(1'b0), .ls_d(16'd0),
		.reg_enable(reg_enable), .reg_vsy(reg_vsy), .reg_vbl(reg_vbl),
		.reg_vint(reg_vint), .reg_hsy(reg_hsy), .reg_hbl(reg_hbl),
		.reg_slip(reg_slip), .reg_apdma(reg_apdma), .reg_pmbase(reg_pmbase),
		.reg_albase(reg_albase), .reg_opt(reg_opt),
		.reg_mocon(reg_mocon), .reg_pcon(reg_pcon), .reg_grcon(reg_grcon),
		.mob_wr(mob_wr), .mob_sel(mob_sel),
		.mo_xscroll(mo_xscroll), .pf1_xscroll(pf1_xscroll),
		.pf2_xscroll(pf2_xscroll), .pf2_xscroll_raw(pf2_xscroll_raw),
		.mo_yscroll(mo_yscroll), .pf1_yscroll(pf1_yscroll),
		.pf2_yscroll(pf2_yscroll),
		.pf1_attr_latch(pf1_attr_latch), .pf2_attr_latch(pf2_attr_latch),
		.oas_en(oas_en),
		.ols_en(ols_en), .oslpink(oslpink), .osloram(osloram),
		.o_dcdma(o_dcdma), .o_dvdma(o_dvdma), .oadroen(oadroen),
		.ocrdwe(ocrdwe), .ovrdtack(ovrdtack), .ocrdtack(ocrdtack),
		.opium(opium), .opfhsiz_pf2at(opfhsiz_pf2at),
		.vad_enable(vad_enable), .dma_enable(dma_enable),
		.irq_arm(irq_arm), .irq_ack(irq_ack)
	);
	relief_vad_sync #(.H_TOTAL(H_TOTAL), .H_VISIBLE(H_VISIBLE),
	                  .HB_MODE(0), .HB_PHASE(HB_PHASE)) u_sync (
		.clk(clk), .reset(reset), .ce_14m(ce_14m),
		.vad_enable(vad_enable),
		.reg_vsy(reg_vsy), .reg_vbl(reg_vbl), .reg_vint(reg_vint),
		.reg_hsy(reg_hsy), .reg_hbl(reg_hbl),
		.irq_arm(irq_arm), .irq_ack(irq_ack),
		.h(h), .v(v), .hd(hd),
		.hsync_n(hsync_n), .vsync_n(vsync_n),
		.hblank(hblank_i), .vblank(vblank_i),
		.hde(hde), .vde(vde), .hpos(hpos), .vpos(vpos),
		.v_next(v_next),
		.line_start(line_start), .frame_start(frame_start),
		.vblank_start(vblank_start), .eof_window(eof_window),
		.vint_n(vint_n)
	);
	wire       pix_half = hd[0];
	wire       ce_7m    = ce_14m & hd[0];
	wire [8:0] px       = hd[9:1];
	wire       blank    = hblank_i | vblank_i;
	assign ce_pix = ce_7m;
	localparam int BD = (PIPE < 0) ? 0 : PIPE;
	logic [3:0] d_bl;
	always_ff @(posedge clk) begin
		if (reset)         d_bl <= 4'hF;
		else if (ce_7m)    d_bl <= {d_bl[2:0], blank};
	end
	wire blank_px = (BD == 0) ? blank : d_bl[(BD == 0) ? 0 : BD-1];
	wire [14:0] base_pf1  = {reg_pmbase[15:13], 12'b0};
	wire [14:0] base_pf2  = {reg_pmbase[12:10], 12'b0};
	wire [14:0] base_attr = {reg_pmbase[9:7],   12'b0};
	wire [14:0] base_al   = {reg_albase[9:6],   11'b0};
	wire [14:0] base_mo   = {reg_pmbase[5:1],   10'b0};
	wire [14:0] base_slip = base_al + {3'b000, reg_albase[5:0], 6'b0};
	wire [14:0] a_pf1c, a_pf1a, a_pf2c, a_pf2a;
	wire [15:0] q_pf1c, q_pf1a, q_pf2c, q_pf2a;
	wire        mo_vram_rd, mo_vram_ack;
	wire [14:0] mo_vram_a;
	wire [15:0] mo_vram_q;
	wire        dma_rq, dma_ack;
	wire [14:0] dma_a;
	wire [15:0] dma_q;
	wire        as_req;
	wire [14:0] as_a;
	wire [15:0] as_d;
	wire  [1:0] as_ds;
	wire        vr_grant, cpu_wr_stb;
	wire [14:0] cpu_wr_a;
	wire [15:0] vr_dout;
	wire        layer_late;
	relief_vram #(
		.IACK_STEALS(IACK_STEALS)
	) u_vram (
		.clk(clk), .reset(reset), .ce_14m(ce_14m), .hd(hd), .blank(blank),
		.pf1_code_a(a_pf1c), .pf1_attr_a(a_pf1a),
		.pf2_code_a(a_pf2c), .pf2_attr_a(a_pf2a),
		.pf1_code_q(q_pf1c), .pf1_attr_q(q_pf1a),
		.pf2_code_q(q_pf2c), .pf2_attr_q(q_pf2a),
		.mo_req(mo_vram_rd), .mo_a(mo_vram_a),
		.mo_ack(mo_vram_ack), .mo_q(mo_vram_q),
		.dma_req(dma_rq), .dma_we(1'b0), .dma_a(dma_a), .dma_d(16'd0),
		.dma_ack(dma_ack), .dma_q(dma_q),
		.cpu_cs(acc_arr & is_vr), .cpu_we(cpu_wr & is_vr), .cpu_ds(cpu_ds),
		.cpu_a(ma[15:1]), .cpu_din(din), .cpu_dout(vr_dout),
		.cpu_grant(vr_grant), .ovrdtack(ovrdtack), .iack(iack),
		.cpu_wr_stb(cpu_wr_stb), .cpu_wr_a(cpu_wr_a),
		.as_req(as_req), .as_a(as_a), .as_d(as_d), .as_ds(as_ds),
		.init_wr(snap_wr & ~snap_cr), .init_a(snap_a), .init_d(snap_d),
		.mo_words_line(mo_words_line), .cpu_words_line(cpu_words_line),
		.dma_words_line(dma_words_line), .cpu_wait_worst(cpu_wait_worst),
		.layer_late(layer_late)
	);
	/* verilator lint_off UNUSEDSIGNAL */
	wire [10:0] eof_words;
	/* verilator lint_on UNUSEDSIGNAL */
	relief_vad_dma u_dma (
		.clk(clk), .reset(reset),
		.line_start(line_start), .vpos(v), .vblank(vblank_i),
		.dma_enable(dma_enable), .oas_en(oas_en),
		.base_pf1(base_pf1), .base_pf2(base_pf2), .base_attr(base_attr),
		.base_slip(base_slip),
		.eof_req(eof_req), .eof_idx(eof_idx),
		.eof_data(eof_data), .eof_ack(eof_ack),
		.pf1_attr_latch(pf1_attr_latch), .pf2_attr_latch(pf2_attr_latch),
		.cpu_wr_stb(cpu_wr_stb), .cpu_wr_a(cpu_wr_a),
		.as_req(as_req), .as_a(as_a), .as_d(as_d), .as_ds(as_ds),
		.dma_rq(dma_rq), .dma_a(dma_a),
		.dma_ack(dma_ack), .dma_q(dma_q),
		.eof_words(eof_words), .eof_late(eof_late)
	);
	wire        pf1_fetch, pf1_valid, pf1_late;
	wire [19:0] pf1_raddr;
	wire [31:0] pf1_grp;
	wire        pf2_fetch, pf2_valid, pf2_late;
	wire [19:0] pf2_raddr;
	wire [31:0] pf2_grp;
	wire  [3:0] pen1, col1, pen2, col2;

	relief_pf #(.ATTR_HIGH_BYTE(1'b1), .XOFF(PF1_XOFF),
	            .H_PIX(H_TOTAL/2)) u_pf1 (
		.clk(clk), .reset(reset), .ce_7m(ce_7m), .px(px), .line(v), .line_next(v_next),
		.xscroll(pf1_xscroll), .yscroll(pf1_yscroll),
		.base_code(base_pf1), .base_attr(base_attr),
		.code_a(a_pf1c), .attr_a(a_pf1a), .code_q(q_pf1c), .attr_q(q_pf1a),
		.rom_fetch(pf1_fetch), .rom_addr(pf1_raddr), .rom_group(pf1_grp),
		.rom_valid(pf1_valid), .rom_late(pf1_late),
		.pen(pen1), .colour(col1));
	wire [3:0] pen2_g = opium ? pen2 : 4'd0;
	relief_pf #(.ATTR_HIGH_BYTE(1'b0), .XOFF(PF2_XOFF),
	            .H_PIX(H_TOTAL/2)) u_pf2 (
		.clk(clk), .reset(reset), .ce_7m(ce_7m), .px(px), .line(v), .line_next(v_next),
		.xscroll(pf2_xscroll), .yscroll(pf2_yscroll),
		.base_code(base_pf2), .base_attr(base_attr),
		.code_a(a_pf2c), .attr_a(a_pf2a), .code_q(q_pf2c), .attr_q(q_pf2a),
		.rom_fetch(pf2_fetch), .rom_addr(pf2_raddr), .rom_group(pf2_grp),
		.rom_valid(pf2_valid), .rom_late(pf2_late),
		.pen(pen2), .colour(col2));
	wire        mob_fetch, mob_valid;
	wire [20:0] mob_raddr;
	wire [39:0] mob_grp;
	wire        mob_lb_we, mo_busy, mo_budget_hit, mo_line_over;
	wire  [9:0] mob_lb_a;
	wire [8:0] mob_lb_d;
	wire [10:0] mo_words;
	logic       wbank;
	always_ff @(posedge clk) begin
		if (reset)           wbank <= 1'b0;
		else if (line_start) wbank <= ~wbank;
	end
	wire [8:0] mo_line = v_next;
	relief_mob #(.MO_XOFF(MO_XOFF), .MO_WORD_BUDGET(MO_BUDGET)) u_mob (
		.clk(clk), .reset(reset),
		.line_start(line_start & MO_ENABLE), .vline(mo_line),
		.xscroll(mo_xscroll), .yscroll(mo_yscroll),
		.base_mo(base_mo), .base_slip(base_slip),
		.vram_a(mo_vram_a), .vram_rd(mo_vram_rd),
		.vram_ack(mo_vram_ack), .vram_q(mo_vram_q),
		.rom_fetch(mob_fetch), .rom_addr(mob_raddr),
		.rom_group(mob_grp), .rom_valid(mob_valid),
		.lb_we(mob_lb_we), .lb_a(mob_lb_a), .lb_d(mob_lb_d),
		.busy(mo_busy), .words(mo_words), .budget_hit(mo_budget_hit),
		.line_over(mo_line_over));
	wire [8:0] lb_q;
	relief_lb #(.LB_ERASE(MO_ERASE)) u_lb (
		.clk(clk), .reset(reset),
		.wbank(wbank),
		.we(mob_lb_we), .wa(mob_lb_a), .wd(mob_lb_d),
		.rd_ce(ce_7m), .ra({1'b0, px}), .q(lb_q));
	wire pf1_cl_late, pf2_cl_late, mo_cl_late;
	/* verilator lint_off UNUSEDSIGNAL */
	wire [3:0] pf1_blen, pf2_blen, mo_blen;
	/* verilator lint_on UNUSEDSIGNAL */
	relief_gfx_client #(.AW(20), .GROUP(8), .BEATS(4), .STRIDE(2)) u_pf1_rom (
		.clk(clk), .reset(reset),
		.fetch(pf1_fetch), .fetch_addr(pf1_raddr),
		.data(pf1_grp), .data_valid(pf1_valid), .late(pf1_cl_late),
		.req(pf1_req), .addr(pf1_addr), .blen(pf1_blen), .ack(pf1_ack),
		.group(pf1_group));
	relief_gfx_client #(.AW(20), .GROUP(8), .BEATS(4), .STRIDE(2)) u_pf2_rom (
		.clk(clk), .reset(reset),
		.fetch(pf2_fetch), .fetch_addr(pf2_raddr),
		.data(pf2_grp), .data_valid(pf2_valid), .late(pf2_cl_late),
		.req(pf2_req), .addr(pf2_addr), .blen(pf2_blen), .ack(pf2_ack),
		.group(pf2_group));
	wire [20:0] mo_addr_w;
	relief_gfx_client #(.AW(21), .GROUP(16), .BEATS(5), .STRIDE(2)) u_mo_rom (
		.clk(clk), .reset(reset),
		.fetch(mob_fetch), .fetch_addr(mob_raddr),
		.data(mob_grp), .data_valid(mob_valid), .late(mo_cl_late),
		.req(mo_req), .addr(mo_addr_w), .blen(mo_blen), .ack(mo_ack),
		.group(mo_group));
	assign mo_addr = mo_addr_w;
	always_ff @(posedge clk) begin
		if (reset)      gfx_late <= 1'b0;
		else if (pf1_late | pf2_late | pf1_cl_late | pf2_cl_late | mo_cl_late
		         | layer_late | mo_budget_hit | mo_line_over)
		                gfx_late <= 1'b1;
	end
	assign mix_background = pen1 == 4'd0;
	assign mix_pf_pen = mix_background ? pen2_g : pen1;
	assign mix_pf_colour = mix_background ? col2 : col1;
	always_ff @(posedge clk) begin
		if (reset) mix_mo <= 9'd0;
		else if (ce_7m) mix_mo <= lb_q;
	end
	wire [15:0] colour, cr_dout;
	wire        cr_grant;
	relief_cram u_cram (
		.clk(clk), .reset(reset), .ce(ce_7m), .pix_half(pix_half),
		.pix_index(mix_index), .blank(blank_px),
		.cpu_cs(acc_arr & is_cr), .cpu_we(cpu_wr & is_cr), .cpu_ds(cpu_ds),
		.cpu_a(ma[11:1]), .cpu_din(din), .cpu_dout(cr_dout),
		.cpu_grant(cr_grant),
		.o_dcdma(o_dcdma), .ocrdtack(ocrdtack),
		.init_wr(snap_wr & snap_cr), .init_a(snap_a[10:0]), .init_d(snap_d),
		.colour(colour), .pix_index_out(pix_index), .steal(cram_steal));
	relief_dac u_dac (
		.colour(colour),
		.red(vga_r), .green(vga_g), .blue(vga_b));
	assign dout = is_reg ? reg_dout : (is_vr ? vr_dout : (is_cr ? cr_dout : 16'hFFFF));
	wire grant = acc & (is_reg ? 1'b1 : (is_vr ? vr_grant : (is_cr ? cr_grant : 1'b1)));
	assign vdtack_n = ~grant;
	localparam int SD = (PIPE < 0) ? 0 : (PIPE + 1);
	logic [3:0] d_hs, d_vs, d_hb, d_vb;
	always_ff @(posedge clk) begin
		if (reset) begin
			d_hs <= 4'hF; d_vs <= 4'hF; d_hb <= 4'hF; d_vb <= 4'hF;
		end else if (ce_7m) begin
			d_hs <= {d_hs[2:0], ~hsync_n};
			d_vs <= {d_vs[2:0], ~vsync_n};
			d_hb <= {d_hb[2:0],  hblank_i};
			d_vb <= {d_vb[2:0],  vblank_i};
		end
	end
	assign hsync  = d_hs[SD-1];
	assign vsync  = d_vs[SD-1];
	assign hblank = d_hb[SD-1];
	assign vblank = d_vb[SD-1];
	assign vblank_board = vblank_i;
	assign hblank_board = hblank_i;
	assign beam_h = hd[9:1];
	assign beam_v = v;
	/* verilator lint_off UNUSEDSIGNAL */
	wire _unused_vid = &{1'b0,
	                     h, hpos, vpos, hde, vde, frame_start, eof_window,
	                     reg_slip, reg_apdma, reg_enable, reg_opt,
	                     reg_pmbase[6], reg_pmbase[0], reg_albase[15:10],
	                     reg_mocon, reg_pcon,
	                     reg_grcon, mob_wr, mob_sel, pf2_xscroll_raw,
	                     ols_en, oslpink, osloram, o_dvdma, oadroen, ocrdwe,
	                     opfhsiz_pf2at, mo_busy, mo_budget_hit,
	                     mo_line_over, mo_words, eof_words,
	                     d_hs[3], d_vs[3], d_hb[3], d_vb[3],
	                     1'b0};
	/* verilator lint_on UNUSEDSIGNAL */
endmodule
