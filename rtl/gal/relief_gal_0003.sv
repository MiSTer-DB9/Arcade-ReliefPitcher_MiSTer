// SPDX-License-Identifier: GPL-3.0-or-later
// Atari 136093-0003, a GAL16V8 at 11R. Its board wiring is unknown, so the
// core does not use this model; it is kept as a tested copy of the chip.
module relief_gal_0003(input wire clk, ce, reset,
    input wire [19:1] pin, output wire [19:12] value, drive);
    assign value = {1'b0, 1'b1, pin[7], pin[6], ~pin[3], 1'b1, pin[2], pin[1]};
    assign drive = 8'hff;
    wire unused = &{1'b0, clk, ce, reset, pin};
endmodule
