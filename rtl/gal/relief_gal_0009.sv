// SPDX-License-Identifier: GPL-3.0-or-later
// Atari 136093-0009, a GAL16V8 at 8A on the audio daughterboard. Pin 2 is
// the 3.579 MHz clock level, not an enable.
module relief_gal_0009(input wire clk, ce, reset,
    input wire [19:1] pin, output wire [19:12] value, drive);
    reg q17, q19;
    always @(posedge clk) begin
        if (reset) begin q17 <= 1'b0; q19 <= 1'b0; end
        else if (ce) begin
            q17 <= pin[8];
            q19 <= ~pin[8]&~q17;
        end
    end
    assign value[12] = ~(~pin[4]&~pin[5]);
    assign value[13] = ~pin[4]&pin[9];
    assign value[14] = ~(~pin[4]&pin[9]);
    assign value[15] = 1'b1;
    assign value[16] = ~pin[4]&pin[6];
    assign value[17] = q17;
    assign value[18] = ~(~pin[2]&~pin[7]&~q17&~q19);
    assign value[19] = q19;
    assign drive = {~pin[11],1'b1,~pin[11],5'b11111};
    wire unused = &{1'b0, pin};
endmodule
