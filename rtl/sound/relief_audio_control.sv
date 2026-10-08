// SPDX-License-Identifier: GPL-3.0-or-later
// Daughterboard GALs, access synchronizer and physical data latches.
module relief_audio_control (
    input wire clk_sys, init_reset, sound_reset_n,
    input wire ce_3m58, clock_3m58,
    input wire as_n, e0_n, e1_n, rw, uds_n,
    input wire [18:1] ma,
    input wire [15:0] data,
    input wire [17:0] sample_addr,
    output wire edt, wrstb_n, ym_n, oki_write_n, oki_read_n,
    output wire eeprom_n, eeprom_rw, unlock_n,
    output wire [19:0] sample_rom_addr,
    output wire [2:0] sample_cs_n,
    output reg [7:0] volume,
    output reg [8:0] control,
    output wire [3:0] tm,
    output wire ym_reset_n, oki_reset_n,
    output wire ym_write, oki_write,
    output wire [7:0] write_data,
    output wire ym_port
);
    reg audsel_n;
    always @(posedge clk_sys) begin
        if(init_reset || as_n) audsel_n <= 1'b1;
        else if(ce_3m58) audsel_n <= e1_n;
    end
    wire [19:1] bank_pin, decode_pin;
    wire [19:12] bank_value, bank_drive, decode_value, decode_drive;
    assign bank_pin = {8'd0,1'b0,1'b0,control[8],audsel_n,rw,
        control[7],control[6],sample_addr[17],sample_addr[16],clock_3m58,clock_3m58};
    relief_gal_0009 u_bank(.clk(clk_sys),.ce(ce_3m58),.reset(init_reset),
        .pin(bank_pin),.value(bank_value),.drive(bank_drive));
    assign wrstb_n = bank_value[18];
    assign edt = bank_value[19];
    assign sample_rom_addr = {bank_value[13],bank_value[16],bank_value[12],sample_addr[16:0]};
    assign sample_cs_n = {bank_value[15],bank_value[14],bank_value[13]};
    assign decode_pin = {8'd0,as_n,1'b0,uds_n,rw,e1_n,e0_n,ma[18],ma[6:4],wrstb_n};
    relief_gal_0010 u_decode(.clk(clk_sys),.ce(1'b1),.reset(init_reset),
        .pin(decode_pin),.value(decode_value),.drive(decode_drive));
    assign oki_read_n = decode_value[12];
    assign ym_n = decode_value[13];
    assign oki_write_n = decode_value[14];
    assign eeprom_rw = decode_value[17];
    assign eeprom_n = decode_value[18];
    assign unlock_n = decode_value[19];
    reg old_dvc_n, old_latch_n, old_ym_n, old_oki_n;
    always @(posedge clk_sys) begin
        old_dvc_n <= decode_value[15];
        old_latch_n <= decode_value[16];
        old_ym_n <= ym_n;
        old_oki_n <= oki_write_n;
        if(init_reset) begin
            old_dvc_n <= 1'b1;
            old_latch_n <= 1'b1;
            old_ym_n <= 1'b1;
            old_oki_n <= 1'b1;
        end
        if(init_reset || !sound_reset_n) begin
            volume <= 8'd0;
            control <= 9'd0;
        end else begin
            if(!old_dvc_n && decode_value[15]) volume <= data[7:0];
            if(!old_latch_n && decode_value[16]) control <= data[8:0];
        end
    end
    assign tm = control[4:1];
    assign ym_reset_n = sound_reset_n && control[0];
    assign oki_reset_n = sound_reset_n && control[5];
    assign ym_write = !old_ym_n && ym_n && !init_reset && sound_reset_n;
    assign oki_write = !old_oki_n && oki_write_n && !init_reset && sound_reset_n;
    assign write_data = data[7:0];
    assign ym_port = ma[1];
    wire unused = &{1'b0,bank_drive,decode_drive,bank_value[17],data[15:9],ma[17:7],ma[3:2]};
endmodule
