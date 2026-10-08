// SPDX-License-Identifier: GPL-3.0-or-later
// Loaded chip-pin volts to the mixer output, before the output trim.
module relief_audio_network (
    input wire clk, reset, tick,
    input wire signed [31:0] mo_volts, ro_volts, oki_volts,
    input wire [3:0] tm,
    input wire [7:0] dvc,
    output wire signed [31:0] mixed_volts,
    output wire valid, busy, late, clipped
);
    reg [3:0] divider;
    wire sample = tick && divider==0;
    reg signed [31:0] held_oki;
    reg [3:0] held_tm;
    reg [7:0] held_dvc;
    always @(posedge clk) begin
        if (reset) begin
            divider<=0; held_oki<=0; held_tm<=0; held_dvc<=0;
        end else if (tick) begin
            divider <= divider==9 ? 4'd0 : divider+1'b1;
            if (sample) begin
                held_oki<=oki_volts; held_tm<=tm; held_dvc<=dvc;
            end
        end
    end
    wire signed [31:0] filtered_mo, filtered_ro;
    wire rc_valid, rc_busy, rc_late, filter_busy, filter_late;
    relief_ym_rc u_rc (
        .clk(clk), .reset(reset), .tick(tick), .sample(sample),
        .mo_volts(mo_volts), .ro_volts(ro_volts),
        .mo_filtered(filtered_mo), .ro_filtered(filtered_ro),
        .valid(rc_valid), .busy(rc_busy), .late(rc_late)
    );
    relief_audio_filter #(.YM_INPUT_FILTERED(1'b1)) u_filter (
        .clk(clk), .reset(reset), .tick(rc_valid),
        .mo_volts(filtered_mo), .ro_volts(filtered_ro), .oki_volts(held_oki),
        .tm(held_tm), .dvc(held_dvc), .mixed_volts(mixed_volts),
        .valid(valid), .busy(filter_busy), .late(filter_late), .clipped(clipped)
    );
    assign busy = rc_busy | filter_busy;
    assign late = rc_late | filter_late;
endmodule
