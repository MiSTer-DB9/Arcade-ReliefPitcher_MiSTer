// SPDX-License-Identifier: GPL-3.0-or-later
// Atari 136093-0004, a GAL16V8 at 5N. Its board wiring is unknown, so the
// core does not use this model; it is kept as a tested copy of the chip.
// Reset gives the register a known startup state.
module relief_gal_0004(input wire clk, ce, reset,
    input wire [19:1] pin, output wire [19:12] value, drive);
    reg q13;
    always @(posedge clk) if (reset) q13 <= 1'b0; else if (ce) q13 <= ~pin[9];
    assign value[12] = ~(~value[14] & pin[18]);
    assign value[13] = q13;
    assign value[14] = pin[9] & ~pin[18];
    assign value[15] = 1'b0;
    assign value[16] = q13 | (pin[2]&pin[3]&pin[4]&pin[5]&~pin[7]&pin[15]) | (~pin[7]&~pin[8]);
    assign value[17] = q13 | (pin[2]&pin[3]&pin[4]&pin[5]&pin[7]&pin[15]) | (pin[7]&~pin[8]);
    assign value[18] = 1'b0;
    assign value[19] = ~((pin[6]&~pin[7]) | (~pin[6]&pin[7]));
    assign drive = {1'b1,1'b0,2'b11,1'b0,1'b1,~pin[11],1'b1};
    wire unused = &{1'b0, pin};
endmodule
