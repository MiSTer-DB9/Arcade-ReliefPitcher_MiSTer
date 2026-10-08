// Adapted for ReliefPitcher from the Skull & Crossbones core's rtl/mem/skullxbo_sdram_loader.sv (GPL-3.0); see NOTICE.md
`timescale 1ns/1ps
//============================================================================
//  ReliefPitcher SDRAM loader-writer (MiSTer only): packs the download byte stream
//  into 16-bit words and writes them through the relief_gfx_mem write port.
//
//  Copyright (C) 2026 the Skull & Crossbones MiSTer core authors.
//  GPL-3.0-or-later; see LICENSE, NOTICE.md.  Ported from the Badlands MiSTer
//  core (GPL-3.0, same author; itself from Blasteroids / Xybots / Toobin').
//
//  Program words retain big-endian byte order. Graphics become row-pair
//  fetch groups, with separate four-plane PF and five-plane object regions.
//  Sample ROM and EEPROM seed follow the padded object region. wr_busy must
//  drive ioctl_wait while all generated writes drain through the arbiter.
//============================================================================

module relief_sdram_loader #(
	parameter int AW = 24
)(
	input  logic          clk,
	input  logic          reset,

	// Input remains the linear MRA stream; graphics are scattered on receipt.
	input  logic          ld_wr,
	input  logic [23:0]   ld_addr,        // SDRAM BYTE address
	input  logic  [7:0]   ld_data,
	output logic          wr_busy,        // -> ioctl_wait (back-pressure)

	// ---- gfx_mem write port ----
	output logic          dl_wr,
	output logic [AW-1:0] dl_waddr,       // SDRAM WORD address
	output logic [15:0]   dl_wdata,
	input  logic          dl_ack
);

	wire any_ev = ld_wr && !ld_addr[0];   // the even (first) byte of a word
	wire any_od = ld_wr &&  ld_addr[0];   // the word-completing (odd) byte

	logic [7:0] hi_buf;
	logic [7:0] pf_first, mo_first, pf_second;
	wire graphics = ld_addr >= 24'h080000 && ld_addr < 24'h300000;
	wire [21:0] gfx_offset = ld_addr[21:0] - 22'h080000;
	wire [2:0] plane = gfx_offset[21:19];
	wire [23:0] translated = ld_addr >= 24'h300000 ? ld_addr + 24'h080000 : ld_addr;
	wire [AW-1:0] pf_word = AW'(24'h040000) + AW'({gfx_offset[18:4],gfx_offset[3:2],plane[1:0]});
	wire [AW-1:0] mo_word = AW'(24'h0c0000) + AW'({gfx_offset[18:4],gfx_offset[3:2],plane});
	logic [AW-1:0] queued_addr [0:3];
	logic [15:0] queued_data [0:3];
	logic [2:0] remaining;
	logic [1:0] position;

	wire [AW-1:0] word_addr = AW'(translated[23:1]);
	wire [15:0]   word_data = {hi_buf, ld_data};   // even -> D15:8, odd -> D7:0

	typedef enum logic [1:0] { L_IDLE, L_WR, L_GAP } lstate_t;
	lstate_t st;
	wire unused = &{1'b0,gfx_offset[1:0],translated[0]};

	// busy while writing, and in the cycle a word completes
	assign wr_busy = (st != L_IDLE) || (ld_wr && (graphics ? ld_addr[1:0]==2'b11 : ld_addr[0]));

	always_ff @(posedge clk) begin
		if (reset) begin
			st <= L_IDLE; dl_wr <= 1'b0; remaining <= 0; position <= 0;
			hi_buf<=0;pf_first<=0;mo_first<=0;pf_second<=0;dl_waddr<=0;dl_wdata<=0;
		end else begin
			// Latch the even byte in any state, so an early even byte can
			// never pair with a stale one (wr_busy normally prevents this).
			if (any_ev && !graphics) hi_buf <= ld_data;
			case (st)
				L_IDLE: begin
					dl_wr <= 1'b0;
					if (ld_wr && graphics) begin
						case(ld_addr[1:0])
							0: pf_first <= ld_data;
							1: mo_first <= ld_data;
							2: pf_second <= ld_data;
							3: begin
								position<=0;
								if(plane<4) begin
									dl_waddr<=pf_word;dl_wdata<={pf_first,pf_second};
									queued_addr[0]<=mo_word;queued_data[0]<={mo_first,ld_data};
									remaining<=1;
								end else begin
									dl_waddr<=mo_word;dl_wdata<={mo_first,ld_data};
									// Fill the unused lanes of each five-plane fetch group.
									for(integer i=0;i<3;i=i+1) begin
										queued_addr[i]<=mo_word+AW'(i+1);queued_data[i]<=0;
									end
									remaining<=3;
								end
								dl_wr<=1;st<=L_WR;
							end
						endcase
					end else if (any_od) begin
						dl_waddr <= word_addr;
						dl_wdata <= word_data;
						dl_wr    <= 1'b1;
						st       <= L_WR;
						remaining <= 0;
					end
				end
				L_WR: begin
					if (dl_ack) begin
						dl_wr <= 1'b0;
						st <= remaining==0 ? L_IDLE : L_GAP;
					end
				end
				L_GAP: begin
					dl_waddr<=queued_addr[position];dl_wdata<=queued_data[position];
					position<=position+1'b1;remaining<=remaining-1'b1;dl_wr<=1;st<=L_WR;
				end
				default: st <= L_IDLE;
			endcase
		end
	end

	// Simulation-only check: an odd byte arriving while a word is still
	// outstanding means ioctl_wait is not wired to wr_busy.
`ifndef ALTERA_RESERVED_QIS
	always @(posedge clk)
		if (!reset && st == L_WR && any_od)
			$display("ERROR: relief_sdram_loader overrun - a word-completing byte arrived while a write was outstanding; ioctl_wait is not wired to wr_busy");
`endif

endmodule
