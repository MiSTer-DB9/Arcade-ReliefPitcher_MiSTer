// SPDX-License-Identifier: GPL-3.0-or-later
// CPU, main-bus decode and daughterboard control.
module relief_main (
    input wire clk_sys, init_reset, reset, ce_7m, ce_3m58, clock_3m58,
    input wire hblank, vblank, vint_n, vdtack_n,
    input wire [15:0] video_data,
    input wire [7:0] player1_n, player2_n, player3_n, player4_n,
    input wire [3:0] service_n, coin_n,
    input wire self_test_n, vup_n, vdn_n, opt_sw,
    input wire [7:0] oki_status,
    input wire [17:0] sample_addr,
    input wire [1:0] eeprom_upper_address,
    input wire nv_active, nv_we, nv_protect_we, nv_protected,
    input wire [12:0] nv_address,
    input wire [7:0] nv_data,
    output wire [7:0] nv_read_data,
    output wire nv_busy, nv_sdp,
    output wire nv_cell_we,
    output wire [12:0] nv_cell_address,
    output wire [7:0] nv_cell_data,
    output wire [23:1] address,
    output wire [15:0] write_data, read_data,
    output wire as_n, uds_n, lds_n, rw, dtack_n, vpa_n, video_n,
    output wire [2:0] fc, ipl_n,
    output wire cpu_reset, halted_n,
    output wire [3:0] coin_counter,
    output wire sound_reset_n, ym_reset_n, oki_reset_n,
    output wire ym_write, ym_port, oki_write,
    output wire [7:0] sound_data, volume,
    output wire [8:0] control,
    output wire [19:0] sample_rom_addr,
    output wire c_req,
    output wire [23:0] c_addr,
    output wire [1:0] c_blen,
    input wire c_valid, c_last,
    input wire [15:0] c_data
);
    wire [1:0] rom_n;
    wire e0_n,e1_n,ioen_n,base_wait_n,handshake_wait_n,edt;
    relief_decode u_decode(.address(address[21:1]),.as_n(as_n),.edt(edt),.vdtack_n(vdtack_n),
        .rom_n(rom_n),.e0_n(e0_n),.e1_n(e1_n),.ioen_n(ioen_n),
        .base_wait_n(base_wait_n),.handshake_wait_n(handshake_wait_n));
    wire cio_n = ioen_n || address[21:17] != 5'b10011;
    wire watchdog_n = ioen_n || address[21:17] != 5'b10101;
    assign video_n = as_n || address[21:17] != 5'b11111;
    wire watchdog_reset_n;
    wire [3:0] watchdog_count,wait_count;
    relief_watchdog u_watchdog(.clk_sys(clk_sys),.reset(init_reset||reset),.vblank(vblank),
        .select_n(watchdog_n),.reset_n(watchdog_reset_n),.count(watchdog_count));
    assign cpu_reset = init_reset || reset || !watchdog_reset_n || nv_active;
    assign ipl_n = {vint_n,2'b11};
    assign vpa_n = as_n || fc != 3'b111;
    wire cpu_reset_instruction;
    relief_cpu u_cpu(.clk_sys(clk_sys),.ce_7m(ce_7m),.reset(cpu_reset),.ipl_n(ipl_n),
        .read_data(read_data),.dtack_n(dtack_n),.vpa_n(vpa_n),.address(address),
        .write_data(write_data),.as_n(as_n),.uds_n(uds_n),.lds_n(lds_n),.rw(rw),.fc(fc),
        .reset_instruction(cpu_reset_instruction),.halted_n(halted_n));
    wire rom_read = !as_n && rw && rom_n != 2'b11;
    wire [15:0] rom_data;
    wire rom_ready,rom_stall;
    relief_prog_rom u_rom(.clk(clk_sys),.reset(init_reset||reset),.rd(rom_read),
        .addr(address[18:1]),.data(rom_data),.ready(rom_ready),.stall(rom_stall),
        .c_req(c_req),.c_addr(c_addr),.c_blen(c_blen),.c_valid(c_valid),.c_last(c_last),.c_rdata(c_data));
    relief_dtack u_dtack(.clk_sys(clk_sys),.ce_7m(ce_7m),.reset(cpu_reset),.as_n(as_n),
        .base_wait_n(base_wait_n),.handshake_wait_n(handshake_wait_n),.vpa_n(vpa_n),
        .memory_ready(!rom_stall),.dtack_n(dtack_n),.count(wait_count));

    reg [15:0] held_data;
    reg [18:1] held_address;
    always @(posedge clk_sys) begin
        if(init_reset) begin held_data<=16'hffff;held_address<=0;end
        else if(!as_n) begin held_data<=rw ? 16'hffff : write_data;held_address<=address[18:1];end
    end
    wire [7:0] input_select;
    wire [15:0] input_data,input_drive;
    wire leta_reset;
    relief_inputs u_inputs(.clk_sys(clk_sys),.reset_n(!cpu_reset),.bas(!as_n),.cio_n(cio_n),
        .ma(address[6:1]),.data(held_data),.player1_n(player1_n),.player2_n(player2_n),
        .player3_n(player3_n),.player4_n(player4_n),.service_n(service_n),.coin_n(coin_n),
        .vblank_n(!vblank),.self_test_n(self_test_n),.audfull_n(1'b1),.audirq_n(1'b1),
        .vup_n(vup_n),.vdn_n(vdn_n),.opt_sw(opt_sw),.vidbl_n(!(vblank||hblank)),
        .select_n(input_select),.read_data(input_data),.read_drive(input_drive),
        .coin_counter(coin_counter),.sound_reset_n(sound_reset_n),.leta_reset(leta_reset));
    wire wrstb_n,ym_n,oki_write_n,oki_read_n,eeprom_n,eeprom_rw,unlock_n;
    wire [2:0] sample_cs_n;
    wire [3:0] tm;
    relief_audio_control u_audio(.clk_sys(clk_sys),.init_reset(init_reset),.sound_reset_n(sound_reset_n),
        .ce_3m58(ce_3m58),.clock_3m58(clock_3m58),.as_n(as_n),.e0_n(e0_n),.e1_n(e1_n),
        .rw(rw),.uds_n(uds_n),.ma(address[18:1]),.data(held_data),.sample_addr(sample_addr),
        .edt(edt),.wrstb_n(wrstb_n),.ym_n(ym_n),.oki_write_n(oki_write_n),.oki_read_n(oki_read_n),
        .eeprom_n(eeprom_n),.eeprom_rw(eeprom_rw),.unlock_n(unlock_n),
        .sample_rom_addr(sample_rom_addr),.sample_cs_n(sample_cs_n),.volume(volume),.control(control),
        .tm(tm),.ym_reset_n(ym_reset_n),.oki_reset_n(oki_reset_n),.ym_write(ym_write),
        .oki_write(oki_write),.write_data(sound_data),.ym_port(ym_port));

    reg unlocked,old_eeprom_rw,old_unlock_n;
    always @(posedge clk_sys) begin
        old_eeprom_rw<=eeprom_rw;
        old_unlock_n<=unlock_n;
        if(cpu_reset) begin unlocked<=0;old_eeprom_rw<=1;old_unlock_n<=1;end
        else if(!unlock_n || !old_unlock_n) unlocked<=1;
        else if(!old_eeprom_rw && eeprom_rw) unlocked<=0;
    end
    wire [7:0] ee_data;
    wire ee_drive;
    relief_eeprom u_eeprom(.clk_sys(clk_sys),.power_reset(init_reset),.ce_n(eeprom_n),
        .oe_n(unlocked),.we_n(eeprom_rw),.address({eeprom_upper_address,address[11:1]}),
        .data_in(held_data[15:8]),.data_out(ee_data),.data_drive(ee_drive),.busy(nv_busy),.sdp_enabled(nv_sdp),
        .host_active(nv_active),.host_we(nv_we),.host_protect_we(nv_protect_we),
        .host_address(nv_address),.host_data_in(nv_data),.host_protected(nv_protected),.host_data_out(nv_read_data),
        .cell_we(nv_cell_we),.cell_address(nv_cell_address),.cell_data(nv_cell_data));
    assign read_data = rom_read ? rom_data : !video_n ? video_data :
        ee_drive ? {ee_data,8'hff} : !oki_read_n ? {8'hff,oki_status} : (input_data | ~input_drive);
    wire unused=&{1'b0,watchdog_count,wait_count,rom_ready,cpu_reset_instruction,
        held_address,input_select,leta_reset,wrstb_n,ym_n,oki_write_n,sample_cs_n,tm};
endmodule
