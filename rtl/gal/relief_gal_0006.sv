// SPDX-License-Identifier: GPL-3.0-or-later
// Atari 136093-0006, a GAL16V8 at 5F: low pixel bits and transparent-pen
// detection.
module relief_gal_0006(input wire clk, ce, reset,
    input wire [19:1] pin, output wire [19:12] value, drive);
    reg [16:12] q;
    always @(posedge clk) begin
        if (reset) q <= 5'b0;
        else if (ce) begin
            q[12] <= ~pin[18];
            q[13] <= ~((pin[2]&~pin[18]) | (~pin[6]&pin[18]));
            q[14] <= ~((pin[3]&~pin[18]) | (~pin[7]&pin[18]));
            q[15] <= ~((pin[4]&~pin[18]) | (~pin[8]&pin[18]));
            q[16] <= ~((pin[5]&~pin[18]) | (~pin[9]&pin[18]));
        end
    end
    assign value = {2'b0,(pin[2]&pin[3]&pin[4]&pin[5]),q};
    assign drive = {2'b0,1'b1,{5{~pin[11]}}};
    wire unused = &{1'b0, pin};
endmodule
