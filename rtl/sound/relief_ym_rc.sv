// SPDX-License-Identifier: GPL-3.0-or-later
// Integrate the loaded YM pin voltages before reducing the sample rate.
module relief_ym_rc (
    input wire clk, reset, tick, sample,
    input wire signed [31:0] mo_volts, ro_volts,
    output reg signed [31:0] mo_filtered, ro_filtered,
    output reg valid, busy, late
);
    // 1-exp(-16/(630MHz/11)/(4.7K*1nF)), in Q30.
    localparam signed [31:0] ATTACK = 32'sd61962790;
    reg signed [31:0] held_mo, held_ro, state_mo, state_ro;
    reg signed [32:0] delta_mo, delta_ro;
    reg signed [64:0] product_mo, product_ro;
    wire signed [64:0] next_mo =
        {{33{state_mo[31]}},state_mo} + ((product_mo + 65'sd536870912) >>> 30);
    wire signed [64:0] next_ro =
        {{33{state_ro[31]}},state_ro} + ((product_ro + 65'sd536870912) >>> 30);
    reg emit_sample;
    reg [1:0] phase;
    always @(posedge clk) begin
        valid <= 0;
        if (reset) begin
            held_mo<=0; held_ro<=0; state_mo<=0; state_ro<=0;
            delta_mo<=0; delta_ro<=0; product_mo<=0; product_ro<=0;
            mo_filtered<=0; ro_filtered<=0;
            emit_sample<=0; phase<=0; busy<=0; late<=0;
        end else begin
            if ((tick && busy) || (sample && !tick)) late<=1;
            if (!busy) begin
                if (tick) begin
                    // Finish the preceding held-input interval.
                    delta_mo <= {held_mo[31],held_mo} - {state_mo[31],state_mo};
                    delta_ro <= {held_ro[31],held_ro} - {state_ro[31],state_ro};
                    held_mo<=mo_volts; held_ro<=ro_volts;
                    emit_sample<=sample; phase<=1; busy<=1;
                end
            end else case (phase)
                1: begin
                    product_mo<=delta_mo*ATTACK;
                    product_ro<=delta_ro*ATTACK;
                    phase<=2;
                end
                2: begin
                    state_mo<=next_mo[31:0]; state_ro<=next_ro[31:0]; phase<=3;
                end
                3: begin
                    if (emit_sample) begin
                        mo_filtered<=state_mo; ro_filtered<=state_ro; valid<=1;
                    end
                    busy<=0; phase<=0;
                end
                default: begin busy<=0; late<=1; end
            endcase
        end
    end
    wire unused = &{1'b0,next_mo[64:32],next_ro[64:32]};
endmodule
