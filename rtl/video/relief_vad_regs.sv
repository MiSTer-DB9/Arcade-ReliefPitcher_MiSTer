// SPDX-License-Identifier: GPL-3.0-or-later
// Adapted from the Batman VAD model.
// Copyright (C) 2026 the Batman MiSTer core authors.
`timescale 1ns/1ps
module relief_vad_regs #(
	parameter int  EOF_LAST       = 'h1B,
	parameter bit  EOF_SKIP_ZERO  = 1'b1,
	parameter bit  READBACK_SHADOW= 1'b1,
	parameter bit  HONOUR_ENABLE14= 1'b0,
	parameter bit  COUPLE_FINE    = 1'b1
)(
	input  logic        clk,
	input  logic        reset,
	input  logic        cpu_cs,
	input  logic        cpu_we,
	input  logic  [4:0] cpu_a,
	input  logic [15:0] cpu_din,
	input  logic [1:0] cpu_ds,
	output logic [15:0] cpu_dout,
	input  logic  [8:0] vpos,
	input  logic        vblank,
	input  logic        vblank_start,
	output logic        eof_req,
	output logic  [5:0] eof_idx,
	input  logic [15:0] eof_data,
	input  logic        eof_ack,
	input  logic        ls_wr,
	input  logic [15:0] ls_d,
	output logic [15:0] reg_enable,
	output logic [15:0] reg_vsy,
	output logic [15:0] reg_vbl,
	output logic [15:0] reg_vint,
	output logic [15:0] reg_hsy,
	output logic [15:0] reg_hbl,
	output logic [15:0] reg_slip,
	output logic [15:0] reg_apdma,
	output logic [15:0] reg_pmbase,
	output logic [15:0] reg_albase,
	output logic [15:0] reg_opt,
	output logic [15:0] reg_mocon,
	output logic [15:0] reg_pcon,
	output logic [15:0] reg_grcon,
	output logic        mob_wr,
	output logic  [1:0] mob_sel,
	output logic  [8:0] mo_xscroll,
	output logic  [8:0] pf1_xscroll,
	output logic  [8:0] pf2_xscroll,
	output logic  [8:0] pf2_xscroll_raw,
	output logic  [8:0] mo_yscroll,
	output logic  [8:0] pf1_yscroll,
	output logic  [8:0] pf2_yscroll,
	output logic  [7:0] pf1_attr_latch,
	output logic  [7:0] pf2_attr_latch,
	output logic        oas_en,
	output logic        ols_en,
	output logic        oslpink,
	output logic        osloram,
	output logic        o_dcdma,
	output logic        o_dvdma,
	output logic        oadroen,
	output logic        ocrdwe,
	output logic        ovrdtack,
	output logic        ocrdtack,
	output logic        opium,
	output logic        opfhsiz_pf2at,
	output logic        vad_enable,
	output logic        dma_enable,
	output logic        irq_arm,
	output logic        irq_ack
);
	logic [15:0] regs [0:31];
	assign reg_enable = regs[5'h00];
	assign reg_vsy    = regs[5'h01];
	assign reg_vbl    = regs[5'h02];
	assign reg_vint   = regs[5'h03];
	assign reg_hsy    = regs[5'h04];
	assign reg_hbl    = regs[5'h05];
	assign reg_slip   = regs[5'h06];
	assign reg_apdma  = regs[5'h07];
	assign reg_pmbase = regs[5'h08];
	assign reg_albase = regs[5'h09];
	assign reg_opt    = regs[5'h0A];
	assign reg_mocon  = regs[5'h10];
	assign reg_pcon   = regs[5'h11];
	assign reg_grcon  = regs[5'h12];
	assign vad_enable = reg_enable[15];
	assign dma_enable = HONOUR_ENABLE14 ? (reg_enable[15] & ~reg_enable[14])
	                                    : reg_enable[15];
	assign oas_en     = reg_opt[7];
	assign opfhsiz_pf2at = reg_opt[15];
	assign opium         = reg_opt[14];
	assign ols_en        = reg_opt[13];
	assign oslpink       = reg_opt[12];
	assign osloram       = reg_opt[11];
	assign o_dcdma       = reg_opt[10];
	assign o_dvdma       = reg_opt[9];
	assign oadroen       = reg_opt[8];
	assign ocrdwe        = reg_opt[6];
	assign ovrdtack      = reg_opt[5];
	assign ocrdtack      = reg_opt[4];
	typedef enum logic [1:0] { EOF_IDLE, EOF_READ, EOF_WAIT } eof_state_t;
	eof_state_t eof_st;
	logic [5:0] eof_i;
    logic eof_received;
    logic [15:0] eof_hold;
    wire eof_available = eof_received || eof_ack;
    wire [15:0] eof_word = eof_received ? eof_hold : eof_data;
	logic        wr;
	logic  [4:0] wr_a;
	logic [15:0] wr_d;
	wire cpu_wr = cpu_cs & cpu_we & (|cpu_ds);
	wire [4:0] eof_i_lo = eof_i[4:0];
	always_comb begin
		if (cpu_wr) begin
			wr   = 1'b1;
			wr_a = cpu_a;
			wr_d = {cpu_ds[1] ? cpu_din[15:8] : regs[cpu_a][15:8],
			        cpu_ds[0] ? cpu_din[7:0] : regs[cpu_a][7:0]};
		end else if ((eof_st == EOF_WAIT) && eof_available
		             && (!EOF_SKIP_ZERO || (eof_word != 16'h0000))) begin
			wr   = 1'b1;
			wr_a = eof_i_lo;
			wr_d = eof_word;
		end else begin
			wr   = 1'b0;
			wr_a = 5'd0;
			wr_d = 16'd0;
		end
	end
	wire        par_word = (wr & (wr_a >= 5'h10) & (wr_a <= 5'h1B)) | ls_wr;
	wire [15:0] par_src  = ls_wr ? ls_d : wr_d;
	wire [3:0]  par_tag  = par_src[3:0];
	wire [8:0]  par_val  = par_src[15:7];
	always_ff @(posedge clk) begin
		if (reset) begin
			mo_xscroll      <= 9'd0;
			pf1_xscroll     <= 9'd0;
			pf2_xscroll_raw <= 9'd0;
			mo_yscroll      <= 9'd0;
			pf1_yscroll     <= 9'd0;
			pf2_yscroll     <= 9'd0;
		end else if (par_word) begin
			case (par_tag)
				4'h9: mo_xscroll      <= par_val;
				4'hA: pf1_xscroll     <= par_val;
				4'hB: pf2_xscroll_raw <= par_val;
				4'hD: mo_yscroll      <= par_val;
				4'hE: pf1_yscroll     <= par_val;
				4'hF: pf2_yscroll     <= par_val;
				default: ;
			endcase
		end
	end
	assign pf2_xscroll = pf2_xscroll_raw
	                   + (COUPLE_FINE ? {6'd0, pf1_xscroll[2:0]} : 9'd0);
	integer k;
	always_ff @(posedge clk) begin
		if (reset) begin
			for (k = 0; k < 32; k = k + 1) regs[k] <= 16'h0000;
		end else if (wr) begin
			regs[wr_a] <= wr_d;
		end
	end
	assign pf1_attr_latch = regs[5'h1C][15:8];
	assign pf2_attr_latch = regs[5'h1D][7:0];
	assign mob_wr  = wr & (wr_a >= 5'h10) & (wr_a <= 5'h12);
	assign mob_sel = wr_a[1:0];
	assign irq_arm = wr & (wr_a == 5'h03);
	assign irq_ack = wr & (wr_a == 5'h1E);
	localparam logic [5:0] EOFLAST = EOF_LAST[5:0];
	always_ff @(posedge clk) begin
		if (reset) begin
			eof_st  <= EOF_IDLE;
            eof_received <= 1'b0;
            eof_hold <= 16'd0;
			eof_i   <= 6'd0;
			eof_req <= 1'b0;
		end else begin
			case (eof_st)
				EOF_IDLE: begin
					eof_req <= 1'b0;
					if (vblank_start && dma_enable) begin
						eof_i  <= 6'd0;
						eof_st <= EOF_READ;
					end
				end
				EOF_READ: begin
                    eof_received <= 1'b0;
					if (!cpu_wr) begin
						eof_req <= 1'b1;
						eof_st  <= EOF_WAIT;
					end
				end
				EOF_WAIT: begin
                    if(eof_ack) begin
                        eof_hold <= eof_data;
                        eof_received <= 1'b1;
                        eof_req <= 1'b0;
                    end
					if (eof_available && !cpu_wr) begin
                        eof_received <= 1'b0;
						eof_req <= 1'b0;
						if (eof_i == EOFLAST) eof_st <= EOF_IDLE;
						else begin
							eof_i  <= eof_i + 6'd1;
							eof_st <= EOF_READ;
						end
					end
				end
				default: eof_st <= EOF_IDLE;
			endcase
		end
	end
	assign eof_idx = eof_i;
	wire [7:0]  vclamp = vpos[8] ? 8'hFF : vpos[7:0];
	wire [15:0] beam   = {1'b0, vblank, 6'b0, vclamp};
	always_comb begin
		if (cpu_a == 5'h00)          cpu_dout = beam;
		else if (READBACK_SHADOW)    cpu_dout = regs[cpu_a];
		else                         cpu_dout = 16'h0000;
	end
	/* verilator lint_off UNUSEDSIGNAL */
	wire _unused = &{1'b0, regs[5'h1C][7:0], regs[5'h1D][15:8],
	                 par_src[6:4], 1'b0};
	/* verilator lint_on UNUSEDSIGNAL */
endmodule
