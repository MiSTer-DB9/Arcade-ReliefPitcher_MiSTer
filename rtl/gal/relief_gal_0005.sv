// SPDX-License-Identifier: GPL-3.0-or-later
// Atari 136093-0005, a GAL16V8 at 3F: colour select and upper pixel bits.
module relief_gal_0005(input wire clk, ce, reset,
    input wire [19:1] pin, output wire [19:12] value, drive);
    reg [17:13] q;
    wire select_pf = ~((pin[3]&pin[4]&pin[5]&~pin[12]) |
                       (~pin[2]&pin[3]&pin[4]&pin[5]) |
                       (~pin[12]&pin[18]) | (~pin[2]&pin[18]));
    always @(posedge clk) begin
        if (reset) q <= 5'b0;
        else if (ce) begin
            q[13] <= ~((pin[2]&~select_pf) | (~pin[6]&select_pf));
            q[14] <= ~((~pin[3]&~select_pf) | (~pin[7]&select_pf));
            q[15] <= ~((~pin[4]&~select_pf) | (~pin[8]&select_pf));
            q[16] <= ~((~pin[5]&~select_pf) | (~pin[9]&select_pf));
            q[17] <= pin[18]&select_pf;
        end
    end
    assign value = {select_pf,1'b0,q,1'b0};
    assign drive = {1'b1,1'b0,{5{~pin[11]}},1'b0};
    wire unused = &{1'b0, pin};
endmodule
