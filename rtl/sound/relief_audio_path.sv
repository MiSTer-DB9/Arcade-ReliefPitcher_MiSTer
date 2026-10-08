// SPDX-License-Identifier: GPL-3.0-or-later
// Reconstruct and band-limit loaded pin voltages before output calibration.
module relief_audio_path (
    input wire clk, reset, tick,
    input wire signed [31:0] mo_volts, ro_volts, oki_volts,
    input wire [3:0] tm,
    input wire [7:0] dvc,
    output wire signed [31:0] filtered_volts,
    output wire valid, busy, late, clipped
);
    wire signed [31:0] network_volts;
    wire network_valid, network_busy, network_late, network_clipped;
    wire fir_busy, fir_late, fir_clipped;
    relief_audio_network u_network (
        .clk(clk), .reset(reset), .tick(tick),
        .mo_volts(mo_volts), .ro_volts(ro_volts), .oki_volts(oki_volts),
        .tm(tm), .dvc(dvc), .mixed_volts(network_volts),
        .valid(network_valid), .busy(network_busy),
        .late(network_late), .clipped(network_clipped)
    );
    relief_audio_bandlimit u_bandlimit (
        .clk(clk), .reset(reset), .tick(network_valid),
        .sample_in(network_volts), .sample_out(filtered_volts),
        .valid(valid), .busy(fir_busy), .late(fir_late), .clipped(fir_clipped)
    );
    assign busy = network_busy | fir_busy;
    assign late = network_late | fir_late;
    assign clipped = network_clipped | fir_clipped;
endmodule
