// PLL wrapper for the Relief Pitcher core. The parameters are in
// rtl/pll/pll_0002.v. Adapted from the Batman MiSTer core.
//
//   refclk   = CLK_50M (50 MHz)
//   outclk_0 = clk_sys   57.272727 MHz (4 x the board's 14.318181 MHz crystal)
//   outclk_1 = clk_sdram 57.272727 MHz, phase-shifted for the SDRAM_CLK pin

`timescale 1 ps / 1 ps
module pll (
		input  wire  refclk,   //  refclk.clk
		input  wire  rst,      //   reset.reset
		output wire  outclk_0, // outclk0.clk  clk_sys
		output wire  outclk_1, // outclk1.clk  SDRAM clock (phase-shifted)
		output wire  locked    //  locked.export
	);

	pll_0002 pll_inst (
		.refclk   (refclk),   //  refclk.clk
		.rst      (rst),      //   reset.reset
		.outclk_0 (outclk_0), // outclk0.clk
		.outclk_1 (outclk_1), // outclk1.clk
		.locked   (locked)    //  locked.export
	);

endmodule
