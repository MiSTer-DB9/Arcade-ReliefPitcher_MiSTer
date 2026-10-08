// SPDX-License-Identifier: GPL-3.0-or-later
// Audio daughterboard bus, chips and sample-ROM interface.
module relief_sound (
    input wire clk_sys, init_reset, sound_reset_n,
    input wire ce_3m58, clock_3m58, ce_1m19,
    input wire as_n, e0_n, e1_n, rw, uds_n,
    input wire [18:1] ma,
    input wire [15:0] data,
    output wire edt, eeprom_n, eeprom_rw, unlock_n,
    output wire oki_read_n,
    output wire [7:0] oki_status, dvc_volume,
    output wire [8:0] control,
    output wire sample_req,
    output wire [19:0] sample_addr,
    input wire sample_ack,
    input wire [7:0] sample_data,
    output wire signed [9:0] melody, rhythm,
    output wire melody_en, rhythm_en,
    output wire signed [15:0] adpcm,
    output wire adpcm_stb, oki_late, ym_overflow
);
    wire [17:0] chip_addr;
    wire [2:0] sample_cs_n;
    wire [3:0] tm;
    wire wrstb_n, ym_n, oki_write_n, ym_reset_n, oki_reset_n;
    wire ym_write, oki_write, ym_port;
    wire [7:0] write_data;
    relief_audio_control u_control (
        .clk_sys(clk_sys), .init_reset(init_reset), .sound_reset_n(sound_reset_n),
        .ce_3m58(ce_3m58), .clock_3m58(clock_3m58),
        .as_n(as_n), .e0_n(e0_n), .e1_n(e1_n), .rw(rw), .uds_n(uds_n),
        .ma(ma), .data(data), .sample_addr(chip_addr), .edt(edt),
        .wrstb_n(wrstb_n), .ym_n(ym_n), .oki_write_n(oki_write_n),
        .oki_read_n(oki_read_n), .eeprom_n(eeprom_n), .eeprom_rw(eeprom_rw),
        .unlock_n(unlock_n), .sample_rom_addr(sample_addr), .sample_cs_n(sample_cs_n),
        .volume(dvc_volume), .control(control), .tm(tm),
        .ym_reset_n(ym_reset_n), .oki_reset_n(oki_reset_n),
        .ym_write(ym_write), .oki_write(oki_write), .write_data(write_data), .ym_port(ym_port)
    );
    relief_ym u_ym (
        .clk(clk_sys), .reset(init_reset || !ym_reset_n), .ce_3m58(ce_3m58),
        .wr(ym_write), .a0(ym_port), .data(write_data),
        .melody(melody), .rhythm(rhythm), .melody_en(melody_en), .rhythm_en(rhythm_en),
        .overflow(ym_overflow)
    );
    relief_oki u_oki (
        .clk(clk_sys), .ce_1m19(ce_1m19), .okires_n(!init_reset && oki_reset_n),
        .wr_stb(oki_write), .wr_data(write_data), .rd_data(oki_status),
        .oki_req(sample_req), .oki_addr(chip_addr), .oki_ack(sample_ack), .oki_data(sample_data),
        .audio(adpcm), .audio_stb(adpcm_stb), .late(oki_late)
    );
    wire unused = &{1'b0, sample_cs_n, tm, wrstb_n, ym_n, oki_write_n};
endmodule
