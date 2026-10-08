// SPDX-License-Identifier: GPL-3.0-or-later
// Atari 136093-0010, a GAL16V8 at 15A: daughterboard address decoder.
module relief_gal_0010(input wire clk, ce, reset,
    input wire [19:1] pin, output wire [19:12] value, drive);
    assign value[12] = ~(pin[2]&~pin[3]&~pin[4]&~pin[7]&pin[8]);
    assign value[13] = ~(~pin[1]&~pin[2]&~pin[3]&~pin[4]&~pin[7]);
    assign value[14] = ~(~pin[1]&pin[2]&~pin[3]&~pin[4]&~pin[7]);
    assign value[15] = ~(~pin[1]&~pin[2]&pin[3]&~pin[4]&~pin[7]);
    assign value[16] = ~(~pin[1]&pin[2]&pin[3]&~pin[4]&~pin[7]);
    assign value[17] = ~(~pin[8]&~pin[9]);
    assign value[18] = ~(~pin[5]&~pin[6]&~pin[9]);
    assign value[19] = ~(pin[2]&pin[3]&~pin[4]&pin[5]&~pin[6]);
    assign drive = 8'hff;
    wire unused = &{1'b0, clk, ce, reset, pin};
endmodule
