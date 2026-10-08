// SPDX-License-Identifier: GPL-3.0-or-later
// Atari 136093-0008, a GAL16V8 at 3E on the audio daughterboard. Its board
// wiring is unknown, so the core does not use this model; it is kept as a
// tested copy of the chip.
module relief_gal_0008(input wire clk, ce, reset,
    input wire [19:1] pin, output wire [19:12] value, drive);
    reg [18:12] q;
    always @(posedge clk) begin
        if (reset) q <= 7'b0;
        else if (ce) begin
            q[12] <= q[13];
            q[13] <= ~((~pin[3]&q[17]) | (~pin[4]&~q[17]));
            q[14] <= q[17];
            q[15] <= ~(pin[7]&~q[16]);
            q[16] <= pin[7]&~q[16];
            q[17] <= ~((~pin[5]&~pin[6]&~pin[7]&~pin[8]&~pin[9]) |
                       (pin[5]&~q[17]) | (pin[6]&~q[17]) |
                       (pin[7]&~q[17]) | (pin[9]&~q[17]));
            q[18] <= q[14];
        end
    end
    assign value = {~(~pin[5]&~pin[6]&~pin[7]&~pin[9]),q};
    assign drive = {1'b1,{7{~pin[11]}}};
    wire unused = &{1'b0, pin};
endmodule
