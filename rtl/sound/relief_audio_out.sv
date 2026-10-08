// SPDX-License-Identifier: GPL-3.0-or-later
// Chip outputs to 16-bit sound through the daughterboard filters and volume.
// Pin levels use the datasheet typical swings: the YM2413 gives 1.6 V
// peak to peak over its 512 levels into 2.2K, and the MSM6295 gives VDD
// peak to peak over its 12-bit DAC. Voltages are Q20 volts about bias.
module relief_audio_out (
    input wire clk, reset, ce_3m58,
    input wire signed [9:0] melody, rhythm,
    input wire signed [15:0] adpcm,
    input wire [3:0] tm,
    input wire [7:0] dvc,
    output reg signed [15:0] sample,
    output wire late, clipped
);
    localparam signed [12:0] YM_Q20_PER_CODE = 13'sd3277;   // 3.125 mV
    localparam signed [7:0] OKI_Q20_PER_LSB = 8'sd80;       // 2.5 V / 32768

    // The YM pins change on the 3.58 MHz enable. The registered voltages
    // settle one clock later and the filter takes them a clock after that.
    reg settle, tick;
    reg signed [31:0] mo_volts, ro_volts, oki_volts;
    always @(posedge clk) begin
        settle <= !reset && ce_3m58;
        tick <= !reset && settle;
        mo_volts <= 32'(melody * YM_Q20_PER_CODE);
        ro_volts <= 32'(rhythm * YM_Q20_PER_CODE);
        oki_volts <= 32'(adpcm * OKI_Q20_PER_LSB);
    end

    wire signed [31:0] filtered_volts;
    wire valid, busy, path_clipped;
    relief_audio_path u_path (
        .clk(clk), .reset(reset), .tick(tick),
        .mo_volts(mo_volts), .ro_volts(ro_volts), .oki_volts(oki_volts),
        .tm(tm), .dvc(dvc), .filtered_volts(filtered_volts),
        .valid(valid), .busy(busy), .late(late), .clipped(path_clipped)
    );

    // Plus or minus 8 V at the volume stage output is full scale.
    wire signed [23:0] scaled = 24'(filtered_volts >>> 8);
    reg pcm_clipped;
    always @(posedge clk) begin
        if (reset) begin
            sample <= 16'sd0;
            pcm_clipped <= 1'b0;
        end else if (valid) begin
            if (scaled > 24'sd32767) begin sample <= 16'sh7FFF; pcm_clipped <= 1'b1; end
            else if (scaled < -24'sd32768) begin sample <= 16'sh8000; pcm_clipped <= 1'b1; end
            else sample <= scaled[15:0];
        end
    end
    assign clipped = path_clipped | pcm_clipped;
    wire unused = &{1'b0, busy, filtered_volts[7:0]};
endmodule
