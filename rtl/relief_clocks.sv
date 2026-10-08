// SPDX-License-Identifier: GPL-3.0-or-later
// One fabric domain. The two toggle flops reproduce the audio divider.
module relief_clocks(input wire clk_sys, reset,
    output wire ce_14m, ce_7m, ce_3m58, ce_1m19,
    output wire clock_3m58, clock_1m19);
    reg [3:0] phase;
    reg div_a, div_b;
    wire half_tick = phase[2:0] == 3'd7;
    wire xor_rise = half_tick && (phase[3] == div_b);
    always @(posedge clk_sys) begin
        if (reset) begin phase <= 0; div_a <= 0; div_b <= 0; end
        else begin
            phase <= phase + 4'd1;
            if (xor_rise) begin
                div_a <= ~div_a;
                if (!div_a) div_b <= ~div_b;
            end
        end
    end
    assign ce_14m = !reset && phase[1:0] == 2'd3;
    assign ce_7m = !reset && half_tick;
    assign ce_3m58 = !reset && phase == 4'd7;
    assign ce_1m19 = !reset && xor_rise && !div_a && !div_b;
    assign clock_3m58 = phase[3];
    assign clock_1m19 = div_b;
endmodule
