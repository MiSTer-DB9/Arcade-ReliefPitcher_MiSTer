// SPDX-License-Identifier: GPL-3.0-or-later
// Adapted from the Batman MiSTer integration shell.
// Copyright (C) 2026 the Batman MiSTer core authors.
`timescale 1ns/1ps

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [45:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,
	output        HDMI_BLACKOUT,
	output        HDMI_BOB_DEINT,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: USER_OSD + per-pin push-pull mask, USER_IO widened to 8 bits
	output        USER_OSD,
	output  [7:0] USER_PP,
	input   [7:0] USER_IN,
	output  [7:0] USER_OUT,
	// [MiSTer-DB9 END]

	input         OSD_STATUS
);

assign ADC_BUS  = 'Z;
// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: USER_PP driven by wrapper; USER_OUT driven by joydb (USER_OUT_DRIVE) below
assign USER_PP = USER_PP_DRIVE;
// [MiSTer-DB9 END]
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

assign VGA_F1        = 0;
assign VGA_SCALER    = 0;
assign VGA_DISABLE   = 0;
assign HDMI_FREEZE   = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT= 0;
assign FB_FORCE_BLANK= 0;

assign AUDIO_MIX = 0;

assign LED_DISK  = 0;
assign LED_POWER = 0;
assign BUTTONS   = 0;

wire  [1:0] ar  = status[122:121];
wire [11:0] arx = (ar == 2'd0) ? 12'd4 : 12'(ar - 1'd1);
wire [11:0] ary = (ar == 2'd0) ? 12'd3 : 12'd0;

`include "build_id.v"
localparam CONF_STR = {
	"ReliefPitcher;;",
	"-;",
	"O[122:121],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"O[4],Orientation,Original,Flip;",
	"O[22:20],Scale,Normal,V-Integer,HV-Integer,Narrower HV-Integer;",
	"-;",

	// CRT Adjust (rtl/video/relief_analog_adjust.sv). Off is a bit-exact bypass;
	// H1 hides the amounts while the stage is off.
	"P1,CRT Adjust;",
	"P1-;",
	"P1O[47],CRT Adjust,Off,On;",
	"H1P1O[52:48],CRT H-Size,0,+1,+2,+3,+4,+5,+6,+7,+8,+9,+10,+11,+12,+13,+14,+15,-16,-15,-14,-13,-12,-11,-10,-9,-8,-7,-6,-5,-4,-3,-2,-1;",
	"H1P1O[59:53],CRT H-Position,0,+1,+2,+3,+4,+5,+6,+7,+8,+9,+10,+11,+12,+13,+14,+15,+16,+17,+18,+19,+20,+21,+22,+23,+24,+25,+26,+27,+28,+29,+30,+31,+32,+33,+34,+35,+36,+37,+38,+39,+40,+41,+42,+43,+44,+45,+46,+47,+48,+49,+50,+51,+52,+53,+54,+55,+56,+57,+58,+59,+60,+61,+62,+63,-64,-63,-62,-61,-60,-59,-58,-57,-56,-55,-54,-53,-52,-51,-50,-49,-48,-47,-46,-45,-44,-43,-42,-41,-40,-39,-38,-37,-36,-35,-34,-33,-32,-31,-30,-29,-28,-27,-26,-25,-24,-23,-22,-21,-20,-19,-18,-17,-16,-15,-14,-13,-12,-11,-10,-9,-8,-7,-6,-5,-4,-3,-2,-1;",
	"H1P1O[65:60],CRT V-Shift,0,+1,+2,+3,+4,+5,+6,+7,+8,+9,+10,+11,+12,+13,+14,+15,+16,+17,+18,+19,+20,+21,+22,+23,+24,+25,+26,+27,+28,+29,+30,+31,-32,-31,-30,-29,-28,-27,-26,-25,-24,-23,-22,-21,-20,-19,-18,-17,-16,-15,-14,-13,-12,-11,-10,-9,-8,-7,-6,-5,-4,-3,-2,-1;",
	"-;",

	"O[7],Controls,One Set,Original;",
	"O[6],Service,Off,On;",
	"-;",
	// [MiSTer-DB9-Pro BEGIN] - Saturn-first joy_type (canonical bit notation)
	"O[127:126],UserIO Joystick,Off,Saturn,DB9MD,DB15;",
	"O[125],UserIO Players, 1 Player,2 Players;",
	// [MiSTer-DB9-Pro END]
	"T[0],Reset;",

	"J1,Fast Ball/Swing,Curve Ball/Power Swing,Special Pitch/Bunt,Start,Coin,Service credit;",
	"jn,A,B,X,Start,Select,L;",
	"V,v",`BUILD_DATE
};

wire        forced_scandoubler;
wire  [1:0] buttons;
wire [127:0] status;
wire [10:0] ps2_key;
wire        direct_video;
wire [21:0] gamma_bus;

wire        ioctl_download;
wire        ioctl_wr;
wire [26:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire [15:0] ioctl_index;
wire        ioctl_wait, core_ioctl_wait, nv_ioctl_wait;
assign ioctl_wait=core_ioctl_wait | nv_ioctl_wait;
wire        ioctl_upload, ioctl_upload_req, ioctl_rd;
wire  [7:0] ioctl_upload_index, ioctl_din;

wire [31:0] joystick_0, joystick_1;

// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: joydb wrapper
wire         CLK_JOY = CLK_50M;                 // Assign clock between 40-50Mhz
wire   [1:0] joy_type_raw    = status[127:126]; // 0=Off, 1=Saturn, 2=DB9MD, 3=DB15
wire         joy_2p          = status[125];
// SNAC cores: replace 1'b0 with the core's SNAC enable expression so SNAC
// preempts the joydb wrapper on shared USER_IO pins. Default 1'b0 is no-op.
wire         snac_active     = 1'b0;
// MT32-pi cores on primary USER_IO: replace 1'b0 with the core's MT32-active
// expression (e.g. `mt32_use` under `ifndef SECOND_MT32`, `~mt32_disable` for
// TRS-80's inverted polarity). Suppresses the OSD-open autodetect probe so it
// doesn't read the RPi's I2C master traffic as a ghost Saturn signature.
wire         mt32_primary_active = 1'b0;
wire   [1:0] joy_type        = snac_active ? 2'd0 : joy_type_raw;
wire         joy_db9md_en    = (joy_type == 2'd2);
wire         joy_db15_en     = (joy_type == 2'd3);
wire         joy_any_en      = |joy_type;
// [MiSTer-DB9 END]

// [MiSTer-DB9-Pro BEGIN] - Saturn key gate
wire         saturn_unlocked;                   // driven by hps_io UIO_DB9_KEY (0xFE)
// [MiSTer-DB9-Pro END]

// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: joydb wrapper wires + instance
wire   [7:0] USER_OUT_DRIVE;
wire   [7:0] USER_PP_DRIVE;
wire  [15:0] joydb_1, joydb_2;
wire         joydb_1ena, joydb_2ena;
wire  [15:0] joy_raw_payload;
// Programmable-remap matrix (joydb_remap inside joydb): clk_sys carries the
// 0xFD selector load (HPS-bus domain). joydb_*_mapped are the MiSTer-standard
// joystick words the core consumes at its joy0_USB merge point. db9_remap_*
// are driven by the hps_io instance (see the .db9_remap_* bindings there).
// Until a core consumes joydb_*_mapped (Layer B), the matrix stays at identity
// and synthesis prunes it -- binding these is dormant + fleet-safe.
wire  [15:0] joydb_1_mapped, joydb_2_mapped;
wire         db9_remap_cmd;
wire   [5:0] db9_remap_byte_cnt;
wire  [15:0] db9_remap_din;

// [MiSTer-DB9 BEGIN] - DB9 remap factory default (used until Main_MiSTer streams UIO 0xFD)
// Derived from CONF_STR J1, same rule as db9_map.cpp; lets the core work on a stock MiSTer binary.
// DB15:  Fast Ball/Swing=A, Curve Ball/Power Swing=B, Special Pitch/Bunt=C, Start=START, Coin=SELECT, Service credit=D
// DB9MD: Fast Ball/Swing=A, Curve Ball/Power Swing=B, Special Pitch/Bunt=C, Start=START, Coin=MODE, Service credit=X
wire  [35:0] db9_remap_default_db15  = 36'hFFF7BA654;
wire  [35:0] db9_remap_default_db9md = 36'hFFF7BA654;
// [MiSTer-DB9 END]
joydb joydb (
  .clk             ( CLK_JOY         ),
  .clk_sys         ( clk_sys            ),
  .USER_IN         ( USER_IN         ),
  .OSD_STATUS          ( OSD_STATUS          ),
  .snac_active         ( snac_active         ),
  .mt32_primary_active ( mt32_primary_active ),
  .joy_type        ( joy_type        ),
  .joy_2p          ( joy_2p          ),
  .saturn_unlocked ( saturn_unlocked ),
  .USER_OUT_DRIVE  ( USER_OUT_DRIVE  ),
  .USER_PP_DRIVE   ( USER_PP_DRIVE   ),
  .USER_OSD        ( USER_OSD        ),
  .joydb_1         ( joydb_1         ),
  .joydb_2         ( joydb_2         ),
  .joydb_1ena      ( joydb_1ena      ),
  .joydb_2ena      ( joydb_2ena      ),
  .remap_cmd       ( db9_remap_cmd      ),
  .remap_byte_cnt  ( db9_remap_byte_cnt ),
  .remap_din       ( db9_remap_din      ),
  .remap_default_db15  ( db9_remap_default_db15  ),
  .remap_default_db9md ( db9_remap_default_db9md ),
  .joydb_1_mapped  ( joydb_1_mapped     ),
  .joydb_2_mapped  ( joydb_2_mapped     ),
  .joy_raw         ( joy_raw_payload )
);

assign USER_OUT = USER_OUT_DRIVE;
// [MiSTer-DB9 END]

// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: rename USB joystick wires
wire [31:0] joystick_0_USB, joystick_1_USB;
// [MiSTer-DB9 END]

// The read rate assumes the native 15 kHz pixel, so the stage is off while
// the framework forces the scandoubler.
wire crt_enable = status[47] & ~forced_scandoubler;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(),
	.gamma_bus(gamma_bus),

	.forced_scandoubler(forced_scandoubler),
	.direct_video(direct_video),

	.buttons(buttons),
	.status(status),
	.status_menumask({14'd0, ~crt_enable, 1'b0}),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_index(ioctl_index),
	.ioctl_wait(ioctl_wait),

	.ioctl_upload(ioctl_upload),
	.ioctl_rd(ioctl_rd),
	.ioctl_upload_req(ioctl_upload_req),
	.ioctl_upload_index(ioctl_upload_index),
	.ioctl_din(ioctl_din),

	.joystick_0(joystick_0_USB),
	.joystick_1(joystick_1_USB),

	.ps2_key(ps2_key),
	// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: joy_raw
	.joy_raw(joy_raw_payload),
	// programmable remap matrix selector load (UIO_DB9_MAP 0xFD)
	.db9_remap_cmd(db9_remap_cmd),
	.db9_remap_byte_cnt(db9_remap_byte_cnt),
	.db9_remap_din(db9_remap_din),
	// [MiSTer-DB9 END]
	// [MiSTer-DB9-Pro BEGIN] - Saturn key gate
	.saturn_unlocked(saturn_unlocked)
	// [MiSTer-DB9-Pro END]
);

// [MiSTer-DB9-Pro BEGIN] - DB controllers muted while OSD is open
// joydb_*_mapped is already in MiSTer-standard J1 order, identical to the USB
// joystick word, so it replaces the USB input as-is.
assign joystick_0 = joydb_1ena ? (OSD_STATUS ? 16'b0 : joydb_1_mapped) : joystick_0_USB;
assign joystick_1 = joydb_2ena ? (OSD_STATUS ? 16'b0 : joydb_2_mapped) : joydb_1ena ? joystick_0_USB : joystick_1_USB;
// [MiSTer-DB9-Pro END]

wire clk_sys;
wire clk_sdram;
wire pll_locked;

pll pll
(
	.refclk(CLK_50M),
	.rst(1'b0),
	.outclk_0(clk_sys),
	.outclk_1(clk_sdram),
	.locked(pll_locked)
);

assign SDRAM_CLK = clk_sdram;

wire reset = RESET | status[0] | buttons[1] | ~pll_locked;

wire [3:0] p1_joy,p2_joy;
wire p1_b1,p1_b2,p1_b3,p1_start,p2_b1,p2_b2,p2_b3,p2_start;
wire coin1,coin2,self_test,service;
wire tilt = 1'b0;
wire side_known,side_batting;
relief_controls u_controls(.clk_sys(clk_sys),.reset(reset),.ps2_key(ps2_key),
    .joystick_0(joystick_0),.joystick_1(joystick_1),.osd_test(status[6]),.osd_original(status[7]),
    .side_known(side_known),.side_batting(side_batting),
    .p1_joy(p1_joy),.p2_joy(p2_joy),.p1_b1(p1_b1),.p1_b2(p1_b2),.p1_b3(p1_b3),
    .p1_start(p1_start),.p2_b1(p2_b1),.p2_b2(p2_b2),.p2_b3(p2_b3),.p2_start(p2_start),
    .coin1(coin1),.coin2(coin2),.self_test(self_test),.service(service));

wire        ce_pix;
wire  [7:0] core_r, core_g, core_b;
wire        core_hs, core_vs, core_hb, core_vb;
wire [10:0] core_pix_index;
wire        core_rom_loaded;
wire        cctr1, cctr2;
wire signed [15:0] aud_l, aud_r;

wire nv_restore_hold,nv_restore_active,nv_restore_we,nv_restore_protect_we,nv_restore_protected;
wire [12:0] nv_restore_address,nv_cell_address;
wire [7:0] nv_restore_data,nv_cell_data;
wire nv_cell_we,nv_busy,nv_sdp,nv_board_idle,nv_error;
relief_nvram_io u_nvram(.clk_sys(clk_sys),.init_reset(~pll_locked),
    .enabled(core_rom_loaded),.factory_active(ioctl_download && ioctl_index==16'd0),
    .ee_busy(nv_busy),.ee_sdp(nv_sdp),.board_idle(nv_board_idle),
    .ee_cell_we(nv_cell_we),.ee_cell_address(nv_cell_address),.ee_cell_data(nv_cell_data),
    .ioctl_download(ioctl_download),.ioctl_wr(ioctl_wr),.ioctl_addr(ioctl_addr),
    .ioctl_dout(ioctl_dout),.ioctl_index(ioctl_index),.ioctl_upload(ioctl_upload),.ioctl_rd(ioctl_rd),
    .ioctl_upload_req(ioctl_upload_req),.ioctl_upload_index(ioctl_upload_index),.ioctl_din(ioctl_din),
    .ioctl_wait(nv_ioctl_wait),.restore_error(nv_error),
    .restore_hold(nv_restore_hold),.restore_active(nv_restore_active),.restore_we(nv_restore_we),
    .restore_protect_we(nv_restore_protect_we),.restore_protected(nv_restore_protected),
    .restore_address(nv_restore_address),.restore_data(nv_restore_data));

wire [3:0] mix_pf_pen, mix_pf_colour;
wire mix_background;
wire [8:0] mix_mo;
wire [10:0] mix_index;
wire [23:1] bus_address;
wire [15:0] bus_write;
wire bus_as_n,bus_rw,bus_uds_n,bus_lds_n;

relief_side u_side(.clk_sys(clk_sys),.init_reset(~pll_locked),
    .ioctl_download(ioctl_download),.ioctl_wr(ioctl_wr),.ioctl_addr(ioctl_addr),
    .ioctl_dout(ioctl_dout),.ioctl_index(ioctl_index),
    .bus_address(bus_address),.bus_write(bus_write),.bus_as_n(bus_as_n),.bus_rw(bus_rw),
    .bus_uds_n(bus_uds_n),.bus_lds_n(bus_lds_n),.known(side_known),.batting(side_batting));

relief_core #(.SOUND_OUT(1'b1)) u_core
(
	.clk_sys(clk_sys), .reset(reset), .init_reset(~pll_locked),

	.ioctl_download(ioctl_download), .ioctl_wr(ioctl_wr), .ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout), .ioctl_index(ioctl_index), .ioctl_wait(core_ioctl_wait),
    .nv_restore_hold(nv_restore_hold),.nv_restore_active(nv_restore_active),.nv_restore_we(nv_restore_we),
    .nv_restore_protect_we(nv_restore_protect_we),.nv_restore_protected(nv_restore_protected),
    .nv_restore_address(nv_restore_address),.nv_restore_data(nv_restore_data),
    .nv_cell_we(nv_cell_we),.nv_cell_address(nv_cell_address),.nv_cell_data(nv_cell_data),
    .nv_busy(nv_busy),.nv_sdp(nv_sdp),.nv_board_idle(nv_board_idle),

	.self_test(self_test), .service(service), .tilt(tilt),
	// The game never reads the board's volume buttons; they stay released.
	.volume_up(1'b0), .volume_down(1'b0),
	.p1_joy(p1_joy), .p2_joy(p2_joy),
	.p1_b1(p1_b1), .p1_b2(p1_b2), .p1_b3(p1_b3), .p1_start(p1_start),
	.p2_b1(p2_b1), .p2_b2(p2_b2), .p2_b3(p2_b3), .p2_start(p2_start),
	.coin1(coin1), .coin2(coin2),

	.cctr1(cctr1), .cctr2(cctr2),

	.ce_pix(ce_pix), .vga_r(core_r), .vga_g(core_g), .vga_b(core_b),
	.hsync(core_hs), .vsync(core_vs), .hblank(core_hb), .vblank(core_vb),
	.pix_index(core_pix_index),
	.mix_index(mix_index), .mix_pf_pen(mix_pf_pen), .mix_pf_colour(mix_pf_colour),
	.mix_background(mix_background), .mix_mo(mix_mo),
	.gfx_late(), .eof_late(), .beam_h(), .beam_v(),

	.melody(),.rhythm(),.melody_en(),.rhythm_en(),.adpcm(),.adpcm_stb(),.oki_late(),.ym_overflow(),
	.aud_l(aud_l), .aud_r(aud_r),
	.rom_loaded(core_rom_loaded),
	.bus_address(bus_address), .bus_write(bus_write), .bus_as_n(bus_as_n), .bus_rw(bus_rw),
	.bus_uds_n(bus_uds_n), .bus_lds_n(bus_lds_n),

	.SDRAM_DQ(SDRAM_DQ), .SDRAM_A(SDRAM_A), .SDRAM_BA(SDRAM_BA), .SDRAM_DQML(SDRAM_DQML),
	.SDRAM_DQMH(SDRAM_DQMH), .SDRAM_CKE(SDRAM_CKE), .SDRAM_nCS(SDRAM_nCS),
	.SDRAM_nRAS(SDRAM_nRAS), .SDRAM_nCAS(SDRAM_nCAS), .SDRAM_nWE(SDRAM_nWE)
);

// The board's colour mixer GALs choose the colour RAM address.
relief_mixer u_mixer
(
	.clk(clk_sys), .reset(~pll_locked), .ce(ce_pix),
	.mo(mix_mo), .pf_pen(mix_pf_pen), .pf_colour(mix_pf_colour),
	.background(mix_background), .index(mix_index)
);

assign AUDIO_S = 1'b1;
assign AUDIO_L = aud_l;
assign AUDIO_R = aud_r;

wire [7:0] adj_r, adj_g, adj_b;
wire       adj_hs, adj_vs, adj_hb, adj_vb, adj_ce;

relief_analog_adjust #(
	.H_TOTAL(456), .V_TOTAL(262), .CLK_PER_PIX(8), .HPOS_MODE(1), .AW(11)
) u_analog_adjust
(
	.clk        (clk_sys),
	.ce_pix     (ce_pix),
	.osd_on     (crt_enable),
	.osd_hsize  (status[52:48]),
	.osd_hpos   (status[59:53]),
	.osd_vshift (status[65:60]),
	.r_in(core_r), .g_in(core_g), .b_in(core_b),
	.hs_in(core_hs), .vs_in(core_vs), .hb_in(core_hb), .vb_in(core_vb),
	.r_out(adj_r), .g_out(adj_g), .b_out(adj_b),
	.hs_out(adj_hs), .vs_out(adj_vs), .hb_out(adj_hb), .vb_out(adj_vb),
	.ce_out(adj_ce)
);

wire [2:0] fx = 3'b000;

wire       rotate_ccw = 1'b0;
wire       no_rotate  = 1'b1;
wire       flip       = status[4] & ~direct_video;
wire       video_rotated;

wire vga_de_raw;

arcade_video #(.WIDTH(336), .DW(24)) arcade_video
(
	.clk_video (clk_sys),
	.ce_pix    (adj_ce),
	.RGB_in    ({adj_r, adj_g, adj_b}),
	.HBlank    (adj_hb),
	.VBlank    (adj_vb),
	.HSync     (adj_hs),
	.VSync     (adj_vs),

	.CLK_VIDEO (CLK_VIDEO),
	.CE_PIXEL  (CE_PIXEL),
	.VGA_R     (VGA_R),
	.VGA_G     (VGA_G),
	.VGA_B     (VGA_B),
	.VGA_HS    (VGA_HS),
	.VGA_VS    (VGA_VS),
	.VGA_DE    (vga_de_raw),
	.VGA_SL    (VGA_SL),

	.fx                 (fx),
	.forced_scandoubler (forced_scandoubler),
	.gamma_bus          (gamma_bus)
);

wire [2:0] scale_sel = (status[22:20] == 3'd0) ? 3'd0 :
                       (status[22:20] == 3'd1) ? 3'd1 :
                       (status[22:20] == 3'd2) ? 3'd4 :
                                                 3'd2;

video_freak video_freak
(
	.CLK_VIDEO  (CLK_VIDEO),
	.CE_PIXEL   (CE_PIXEL),
	.VGA_VS     (VGA_VS),
	.HDMI_WIDTH (HDMI_WIDTH),
	.HDMI_HEIGHT(HDMI_HEIGHT),
	.VGA_DE     (VGA_DE),
	.VIDEO_ARX  (VIDEO_ARX),
	.VIDEO_ARY  (VIDEO_ARY),
	.VGA_DE_IN  (vga_de_raw),
	.ARX        (arx),
	.ARY        (ary),
	.CROP_SIZE  (12'd0),
	.CROP_OFF   (5'd0),
	.SCALE      (scale_sel)
);

screen_rotate screen_rotate (.*);

assign LED_USER = ioctl_download | nv_restore_hold | nv_error;

/* verilator lint_off UNUSEDSIGNAL */
wire _unused_emu = &{1'b0, core_pix_index, core_rom_loaded, cctr1, cctr2,
                      1'b0};
/* verilator lint_on UNUSEDSIGNAL */

endmodule

// Saves and restores the EEPROM through MiSTer's NVRAM file. A save copies
// the EEPROM one second after the game's last write, so the game keeps
// running while MiSTer reads the copy. A loaded file must have the right
// size, header and CRC; it is then written while the board is held in reset.
module relief_nvram_io #(
    parameter integer SETTLE_CYCLES=57272727
)(
    input wire clk_sys,init_reset,enabled,factory_active,
    input wire ee_busy,ee_sdp,board_idle,ee_cell_we,
    input wire [12:0] ee_cell_address,
    input wire [7:0] ee_cell_data,
    input wire ioctl_download,ioctl_wr,ioctl_upload,ioctl_rd,
    input wire [26:0] ioctl_addr,
    input wire [7:0] ioctl_dout,
    input wire [15:0] ioctl_index,
    output wire ioctl_upload_req,
    output wire [7:0] ioctl_upload_index,
    output reg [7:0] ioctl_din,
    output wire ioctl_wait,restore_hold,restore_active,restore_we,restore_protect_we,
    output wire restore_protected,
    output wire [12:0] restore_address,
    output wire [7:0] restore_data,
    output reg restore_error
);
    localparam integer SW=(SETTLE_CYCLES<2)?1:$clog2(SETTLE_CYCLES+1);
    localparam [13:0] IMAGE_BYTES=14'd8212;
    typedef enum logic [3:0] {N_IDLE,N_COPY_READ,N_COPY_STORE,N_READY,N_UPLOAD,
        N_LOAD,N_APPLY_WAIT,N_APPLY_READ,N_APPLY_WRITE,N_APPLY_SDP,N_FINISH} state_t;
    state_t state;
    reg [7:0] mirror[0:8191],buffer[0:8191];
    reg [7:0] mirror_q,buffer_q;
    reg [12:0] position;
    reg [SW-1:0] settle;
    reg dirty,last_sdp;
    reg [2:0] quiet;
    reg [13:0] received,uploaded;
    reg bad_load,bad_upload,image_sdp;
    reg [31:0] crc,expected_crc,image_crc;
    wire load=ioctl_download && ioctl_index==16'd2;
    wire upload=ioctl_upload && ioctl_index==16'd2;
    wire applying=state==N_APPLY_WAIT || state==N_APPLY_READ ||
                  state==N_APPLY_WRITE || state==N_APPLY_SDP || state==N_FINISH;
    wire copying=state==N_COPY_READ || state==N_COPY_STORE;
    wire [12:0] buffer_address=applying ? position : (ioctl_addr[12:0]-13'd16);
    wire new_load=state!=N_LOAD;
    wire [13:0] next_received=new_load ? 14'd0 : received;

    function automatic [31:0] crc_byte(input [31:0] prior,input [7:0] data);
        reg [31:0] value;
        begin
            value=prior ^ {24'd0,data};
            for(integer i=0;i<8;i=i+1)
                value=(value>>1) ^ (value[0] ? 32'hedb88320 : 32'd0);
            crc_byte=value;
        end
    endfunction

    function automatic [7:0] fixed_byte(input [13:0] address);
        begin
            case(address)
                0:fixed_byte=8'h52; 1:fixed_byte=8'h50;
                2:fixed_byte=8'h4e; 3:fixed_byte=8'h56;
                4:fixed_byte=8'h01; 7:fixed_byte=8'h20;
                8208:fixed_byte=8'h45; 8209:fixed_byte=8'h4e;
                8210:fixed_byte=8'h44; 8211:fixed_byte=8'h21;
                default:fixed_byte=0;
            endcase
        end
    endfunction

    initial begin
        for(integer bank=0;bank<2;bank=bank+1)
            for(integer i=0;i<4096;i=i+1) mirror[bank*4096+i]=8'hff;
    end
    always @(posedge clk_sys) begin
        if(ee_cell_we) mirror[ee_cell_address]<=ee_cell_data;
        mirror_q<=mirror[position];
        buffer_q<=buffer[buffer_address];
        if(!init_reset && !applying && !factory_active && load && ioctl_wr &&
           ioctl_addr>=27'd16 && ioctl_addr<27'd8208)
            buffer[ioctl_addr[12:0]-13'd16]<=ioctl_dout;
        else if(!init_reset && !factory_active && !load && state==N_COPY_STORE && !ee_busy)
            buffer[position]<=mirror_q;
    end

    assign restore_hold=applying;
    assign restore_active=state==N_APPLY_READ || state==N_APPLY_WRITE || state==N_APPLY_SDP;
    assign restore_we=state==N_APPLY_WRITE;
    assign restore_protect_we=state==N_APPLY_SDP;
    assign restore_protected=image_sdp;
    assign restore_address=position;
    assign restore_data=buffer_q;
    assign ioctl_wait=applying;
    assign ioctl_upload_index=8'd2;
    assign ioctl_upload_req=state==N_READY && !factory_active && !load;
    always @* begin
        ioctl_din=0;
        if((state==N_READY || state==N_UPLOAD) && ioctl_index==16'd2 && ioctl_addr<27'd8212) begin
            if(ioctl_addr>=27'd16 && ioctl_addr<27'd8208) ioctl_din=buffer_q;
            else if(ioctl_addr==5) ioctl_din={7'd0,image_sdp};
            else if(ioctl_addr>=8 && ioctl_addr<12) ioctl_din=image_crc[ioctl_addr[1:0]*8+:8];
            else ioctl_din=fixed_byte(ioctl_addr[13:0]);
        end
    end

    always @(posedge clk_sys) begin
        last_sdp<=ee_sdp;
        if(init_reset) begin
            state<=N_IDLE;position<=0;settle<=0;dirty<=0;quiet<=0;
            received<=0;uploaded<=0;bad_load<=0;bad_upload<=0;image_sdp<=0;
            crc<=32'hffffffff;expected_crc<=0;image_crc<=0;restore_error<=0;
        end else begin
            if(applying) begin
                case(state)
                    N_APPLY_WAIT: begin
                        if(ee_busy || !board_idle) quiet<=0;
                        else if(quiet==3) begin position<=0;state<=N_APPLY_READ;end
                        else quiet<=quiet+1'b1;
                    end
                    N_APPLY_READ:state<=N_APPLY_WRITE;
                    N_APPLY_WRITE:begin
                        if(position==13'd8191) state<=N_APPLY_SDP;
                        else begin position<=position+1'b1;state<=N_APPLY_READ;end
                    end
                    N_APPLY_SDP:state<=N_FINISH;
                    default:begin state<=N_IDLE;dirty<=0;settle<=0;end
                endcase
            end else if(factory_active) begin
                state<=N_IDLE;dirty<=0;settle<=0;restore_error<=0;
            end else if(load) begin
                state<=N_LOAD;
                if(new_load) begin
                    received<=0;bad_load<=0;crc<=32'hffffffff;expected_crc<=0;
                    restore_error<=0;dirty<=dirty || state!=N_IDLE;settle<=0;
                end
                if(ioctl_wr) begin
                    if(ioctl_addr!={13'd0,next_received} || ioctl_addr>=27'd8212 || upload)
                        bad_load<=1;
                    if(next_received<IMAGE_BYTES) received<=next_received+1'b1;
                    if(ioctl_addr==5) begin
                        image_sdp<=ioctl_dout[0];
                        if(ioctl_dout>1) bad_load<=1;
                        crc<=crc_byte(32'hffffffff,ioctl_dout);
                    end else if(ioctl_addr>=8 && ioctl_addr<12)
                        expected_crc[ioctl_addr[1:0]*8+:8]<=ioctl_dout;
                    else if(ioctl_addr>=16 && ioctl_addr<8208) crc<=crc_byte(crc,ioctl_dout);
                    else if(ioctl_addr<27'd8212 && ioctl_dout!=fixed_byte(ioctl_addr[13:0])) bad_load<=1;
                end
            end else if(state==N_LOAD) begin
                if(received==IMAGE_BYTES && !bad_load && (~crc)==expected_crc) begin
                    state<=N_APPLY_WAIT;quiet<=0;
                end else begin state<=N_IDLE;restore_error<=1;end
            end else if(copying && (!enabled || ee_busy)) begin
                state<=N_IDLE;dirty<=1;settle<=0;
            end else begin
                case(state)
                    N_IDLE:begin
                        if(!enabled || ee_busy || !dirty) settle<=0;
                        else if(settle==SW'(SETTLE_CYCLES)) begin
                            position<=0;image_sdp<=ee_sdp;
                            crc<=crc_byte(32'hffffffff,{7'd0,ee_sdp});
                            dirty<=0;state<=N_COPY_READ;
                        end else settle<=settle+1'b1;
                    end
                    N_COPY_READ:state<=N_COPY_STORE;
                    N_COPY_STORE:begin
                        crc<=crc_byte(crc,mirror_q);
                        if(position==13'd8191) begin
                            image_crc<=~crc_byte(crc,mirror_q);state<=N_READY;
                        end else begin position<=position+1'b1;state<=N_COPY_READ;end
                    end
                    N_READY:if(upload) begin
                        state<=N_UPLOAD;uploaded<=0;
                        bad_upload<=ioctl_rd && ioctl_addr!=0;
                    end
                    N_UPLOAD:begin
                        if(!upload) begin
                            state<=N_IDLE;
                            if(bad_upload || uploaded!=IMAGE_BYTES) begin dirty<=1;settle<=0;end
                        end else if(ioctl_rd) begin
                            if(ioctl_addr=={13'd0,uploaded}+27'd1 && uploaded<IMAGE_BYTES)
                                uploaded<=uploaded+1'b1;
                            else if(ioctl_addr!=0 || uploaded!=0) bad_upload<=1;
                        end
                    end
                    default:state<=N_IDLE;
                endcase
            end
            if(enabled && !factory_active && !applying && (ee_cell_we || ee_sdp!=last_sdp)) begin
                dirty<=1;settle<=0;
            end
        end
    end
endmodule

// Merges keyboard and joystick inputs into the cabinet switches. Keys follow
// MAME, plus F1 for a service credit and F2 for the self-test switch.
module relief_controls (
    input wire clk_sys, reset,
    input wire [10:0] ps2_key,
    input wire [31:0] joystick_0,joystick_1,
    input wire osd_test,osd_original,side_known,side_batting,
    output wire [3:0] p1_joy,p2_joy,
    output wire p1_b1,p1_b2,p1_b3,p1_start,p2_b1,p2_b2,p2_b3,p2_start,
    output wire coin1,coin2,self_test,service
);
    reg event_seen;
    reg [8:0] keys1,keys2;
    reg key_test,key_service;
    always @(posedge clk_sys) begin
        event_seen <= ps2_key[10];
        if(reset) begin
            keys1<=0;keys2<=0;key_test<=0;key_service<=0;
        end else if(event_seen != ps2_key[10]) begin
            case(ps2_key[8:0])
                9'h174: keys1[0]<=ps2_key[9];
                9'h16b: keys1[1]<=ps2_key[9];
                9'h172: keys1[2]<=ps2_key[9];
                9'h175: keys1[3]<=ps2_key[9];
                9'h014: keys1[4]<=ps2_key[9];
                9'h011: keys1[5]<=ps2_key[9];
                9'h029: keys1[6]<=ps2_key[9];
                9'h016: keys1[7]<=ps2_key[9];
                9'h02e: keys1[8]<=ps2_key[9];
                9'h034: keys2[0]<=ps2_key[9];
                9'h023: keys2[1]<=ps2_key[9];
                9'h02b: keys2[2]<=ps2_key[9];
                9'h02d: keys2[3]<=ps2_key[9];
                9'h01c: keys2[4]<=ps2_key[9];
                9'h01b: keys2[5]<=ps2_key[9];
                9'h015: keys2[6]<=ps2_key[9];
                9'h01e: keys2[7]<=ps2_key[9];
                9'h036: keys2[8]<=ps2_key[9];
                9'h005: key_service<=ps2_key[9];
                9'h006: key_test<=ps2_key[9];
                default: ;
            endcase
        end
    end
    wire [8:0] player1=keys1 | joystick_0[8:0];
    wire [8:0] player2=keys2 | joystick_1[8:0];
    // One Set sends every stick and its buttons to the side the game is
    // waiting on: the pitcher's while the player fields, the batter's while
    // the player bats. Both sides get them if that cannot be told.
    wire [6:0] shared=player1[6:0] | player2[6:0];
    wire [6:0] left=(side_known && side_batting) ? 7'd0 : shared;
    wire [6:0] right=(side_known && !side_batting) ? 7'd0 : shared;
    assign {coin1,p1_start}=player1[8:7];
    assign {coin2,p2_start}=player2[8:7];
    assign {p1_b3,p1_b2,p1_b1,p1_joy}=osd_original ? player1[6:0] : left;
    assign {p2_b3,p2_b2,p2_b1,p2_joy}=osd_original ? player2[6:0] : right;
    assign self_test=osd_test | key_test;
    assign service=key_service | joystick_0[9] | joystick_1[9];
    wire unused=&{1'b0,joystick_0[31:10],joystick_1[31:10]};
endmodule

// Follows which side of the panel the game expects in a one-player game.
// Revisions D, C and B pick their "you should be pitching/batting" message
// with the same routine, which starts tst.w $FFFFxxxx; beq; moveq #$16,D2;
// move.l #imm,D3. The tested word is 0 while the player pitches and 1 while
// the player bats. Its address differs by revision, so it is taken from the
// program as it downloads; CPU writes to it are then shadowed here.
module relief_side (
    input wire clk_sys, init_reset,
    input wire ioctl_download, ioctl_wr,
    input wire [26:0] ioctl_addr,
    input wire [7:0] ioctl_dout,
    input wire [15:0] ioctl_index,
    input wire [23:1] bus_address,
    input wire [15:0] bus_write,
    input wire bus_as_n, bus_rw, bus_uds_n, bus_lds_n,
    output wire known, batting
);
    localparam [31:0] HEAD=32'h4a79ffff;
    localparam [47:0] TAIL=48'h670a7416263c;
    wire rom_download=ioctl_download && ioctl_index==16'd0;
    wire program_byte=rom_download && ioctl_wr && ioctl_addr<27'h080000;
    reg [87:0] history;
    reg was_download, found, repeated;
    reg [15:0] target, word;
    // The pattern starts on an instruction boundary, so it ends on an odd byte.
    wire match=program_byte && ioctl_addr[0] && ioctl_addr>=27'd11 &&
               history[87:56]==HEAD && {history[39:0],ioctl_dout}==TAIL;
    // The board decodes 22 address bits; the game addresses work RAM as $FFxxxx.
    wire hit=known && !bus_as_n && !bus_rw && bus_address[21:1]=={6'h3f,target[15:1]};
    always @(posedge clk_sys) begin
        if(init_reset) begin
            history<=0;was_download<=0;found<=0;repeated<=0;target<=0;word<=0;
        end else begin
            was_download<=rom_download;
            if(rom_download && !was_download) begin found<=0;repeated<=0;word<=0;end
            if(program_byte) begin
                history<={history[79:0],ioctl_dout};
                if(match) begin
                    if(found) repeated<=1;
                    found<=1;target<=history[55:40];
                end
            end
            if(hit && !bus_uds_n) word[15:8]<=bus_write[15:8];
            if(hit && !bus_lds_n) word[7:0]<=bus_write[7:0];
        end
    end
    assign known=found && !repeated && !target[0] && !rom_download;
    assign batting=word!=16'd0;
    wire unused=&{1'b0,bus_address[23:22]};
endmodule
