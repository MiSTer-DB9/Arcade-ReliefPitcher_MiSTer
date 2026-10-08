// SPDX-License-Identifier: GPL-3.0-or-later
// Atari 136093-0002, a GAL16V8 at 15F: main address decoder.
// Pin levels are kept separate from output enables.
module relief_gal_0002(input wire clk, ce, reset,
    input wire [19:1] pin, output wire [19:12] value, drive);
    assign value[12] = 1'b1;
    assign value[13] = ~((~pin[2]&pin[3]&pin[4]&~pin[5]&~pin[6]&~pin[7]&~pin[8]) |
                          (~pin[2]&pin[3]&~pin[4]&~pin[5]&pin[6]&~pin[7]) |
                          (pin[2]&pin[3]&pin[4]&pin[5]&pin[6]));
    assign value[14] = ~((pin[3]&~pin[11]) | (pin[2]&~pin[11]));
    assign value[15] = ~((~pin[1]&~pin[2]&pin[3]&~pin[4]&pin[5]&~pin[6]&~pin[7]) |
                          (pin[2]&pin[3]&pin[4]&pin[5]&pin[6]&pin[9]));
    assign value[16] = ~(~pin[2]&pin[3]&pin[4]);
    assign value[17] = ~(~pin[2]&pin[3]&~pin[4]&pin[5]&~pin[6]&~pin[7]);
    assign value[18] = ~(~pin[2]&~pin[3]&~pin[4]&pin[5]);
    assign value[19] = ~(~pin[2]&~pin[3]&~pin[4]&~pin[5]);
    assign drive = 8'hff;
    wire unused = &{1'b0, clk, ce, reset, pin};
endmodule
