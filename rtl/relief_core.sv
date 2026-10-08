// SPDX-License-Identifier: GPL-3.0-or-later
// Main board and shared video memory; the mixer connects separately.
// SOUND_OUT selects the analogue sound path; with it clear the core is silent.
module relief_core #(parameter bit SOUND_OUT = 1'b0) (
    input wire clk_sys, reset, init_reset,
    input wire ioctl_download, ioctl_wr,
    input wire [26:0] ioctl_addr,
    input wire [7:0] ioctl_dout,
    input wire [15:0] ioctl_index,
    output wire ioctl_wait,
    input wire nv_restore_hold,nv_restore_active,nv_restore_we,nv_restore_protect_we,nv_restore_protected,
    input wire [12:0] nv_restore_address,
    input wire [7:0] nv_restore_data,
    output wire nv_cell_we,nv_busy,nv_sdp,nv_board_idle,
    output wire [12:0] nv_cell_address,
    output wire [7:0] nv_cell_data,
    input wire self_test, service, tilt, volume_up, volume_down,
    input wire [3:0] p1_joy, p2_joy,
    input wire p1_b1, p1_b2, p1_b3, p1_start,
    input wire p2_b1, p2_b2, p2_b3, p2_start, coin1, coin2,
    output wire cctr1, cctr2, ce_pix,
    output wire [7:0] vga_r, vga_g, vga_b,
    output wire hsync, vsync, hblank, vblank,
    output wire [10:0] pix_index,
    input wire [10:0] mix_index,
    output wire [3:0] mix_pf_pen, mix_pf_colour,
    output wire mix_background,
    output wire [8:0] mix_mo,
    output wire gfx_late, eof_late,
    output wire [8:0] beam_h, beam_v,
    output wire signed [9:0] melody, rhythm,
    output wire melody_en, rhythm_en,
    output wire signed [15:0] adpcm,
    output wire adpcm_stb, oki_late, ym_overflow,
    output wire signed [15:0] aud_l, aud_r,
    output reg rom_loaded,
    // CPU bus as seen by the board, for MiSTer-side monitoring only.
    output wire [23:1] bus_address,
    output wire [15:0] bus_write,
    output wire bus_as_n, bus_rw, bus_uds_n, bus_lds_n,
    inout wire [15:0] SDRAM_DQ,
    output wire [12:0] SDRAM_A,
    output wire [1:0] SDRAM_BA,
    output wire SDRAM_DQML, SDRAM_DQMH, SDRAM_CKE, SDRAM_nCS,
    output wire SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE
);
    localparam [26:0] STREAM_BYTES = 27'h400800;
    wire downloading = ioctl_download && ioctl_index == 16'd0;
    wire ld_wr = downloading && ioctl_wr && ioctl_addr < STREAM_BYTES;
    wire busy, dl_wr, sd_ready, sd_req, dl_ack, sd_we, memory_idle;
    wire [23:0] dl_addr,sd_addr;
    wire [15:0] dl_data, sd_data,sd_wdata;
    wire [2:0] sd_blen;
    wire c_req,c_valid,c_last;
    wire [23:0] c_addr;
    wire [1:0] c_blen;
    wire [15:0] c_data;
    wire sd_valid;
    wire [7:0] pf1_byte,pf2_byte,mo_byte,oki_byte;
    wire oki_ack;
    wire oki_req;
    wire [17:0] oki_addr;
    wire [7:0] oki_status;
    wire [10:0] mo_words_line,cpu_words_line,dma_words_line;
    wire [15:0] cpu_wait_worst,cram_steal;
    wire rfsh_ok, pf1_req, pf2_req, mo_req, pf1_ack, pf2_ack, mo_ack;
    wire [19:0] pf1_addr, pf2_addr;
    wire [20:0] mo_addr;
    wire [63:0] pf1_group, pf2_group;
    wire [127:0] mo_group;
    assign ioctl_wait = busy || !sd_ready;
    relief_sdram_loader u_loader(.clk(clk_sys),.reset(init_reset),
        .ld_wr(ld_wr),.ld_addr(ioctl_addr[23:0]),.ld_data(ioctl_dout),.wr_busy(busy),
        .dl_wr(dl_wr),.dl_waddr(dl_addr),.dl_wdata(dl_data),.dl_ack(dl_ack));
    relief_gfx_mem u_arbiter(.clk(clk_sys),.reset(init_reset),.downloading(downloading),
        .dl_wr(dl_wr),.dl_waddr(dl_addr),.dl_wdata(dl_data),.dl_ack(dl_ack),
        .cpu_req(c_req),.cpu_addr(c_addr),.cpu_blen(c_blen),.cpu_valid(c_valid),.cpu_last(c_last),.cpu_rdata(c_data),
        .pf1_req(pf1_req),.pf1_addr(pf1_addr),.pf1_ack(pf1_ack),.pf1_data(pf1_byte),.pf1_group(pf1_group),
        .pf2_req(pf2_req),.pf2_addr(pf2_addr),.pf2_ack(pf2_ack),.pf2_data(pf2_byte),.pf2_group(pf2_group),
        .mo_req(mo_req),.mo_addr(mo_addr),.mo_ack(mo_ack),.mo_data(mo_byte),.mo_group(mo_group),
        .oki_req(oki_req),.oki_addr(sample_rom_addr),.oki_ack(oki_ack),.oki_data(oki_byte),.rfsh_ok(rfsh_ok),
        .sd_ready(sd_ready),.sd_valid(sd_valid),.sd_rdata(sd_data),.sd_req(sd_req),.sd_we(sd_we),
        .sd_addr(sd_addr),.sd_wdata(sd_wdata),.sd_blen(sd_blen),.idle(memory_idle));
    relief_sdram u_sdram(.clk(clk_sys),.reset(init_reset),.addr(sd_addr),.wdata(sd_wdata),
        .we(sd_we),.blen(sd_blen),.req(sd_req),.rdata(sd_data),.valid(sd_valid),
        .ready(sd_ready),.rfsh_ok(rfsh_ok),.SDRAM_DQ(SDRAM_DQ),.SDRAM_A(SDRAM_A),
        .SDRAM_BA(SDRAM_BA),.SDRAM_DQML(SDRAM_DQML),.SDRAM_DQMH(SDRAM_DQMH),
        .SDRAM_CKE(SDRAM_CKE),.SDRAM_nCS(SDRAM_nCS),.SDRAM_nRAS(SDRAM_nRAS),
        .SDRAM_nCAS(SDRAM_nCAS),.SDRAM_nWE(SDRAM_nWE));
    reg [26:0] received;
    reg was_download, bad_download;
    always @(posedge clk_sys) begin
        if(init_reset) begin
            received<=0; was_download<=0; bad_download<=0; rom_loaded<=0;
        end else begin
            was_download<=downloading;
            if(downloading && !was_download) begin
                received<=0; bad_download<=0; rom_loaded<=0;
            end
            if(downloading && ioctl_wr) begin
                if(ioctl_addr != ((!was_download) ? 27'd0 : received) || ioctl_addr>=STREAM_BYTES)
                    bad_download<=1;
                received<=ioctl_addr+27'd1;
            end
            if(!downloading && received==STREAM_BYTES && !bad_download && !busy && memory_idle)
                rom_loaded<=1;
        end
    end
    wire ce_14m, ce_7m, ce_3m58, ce_1m19, clk_3m58, clk_1m19;
    relief_clocks u_clocks(.clk_sys(clk_sys),.reset(init_reset),.ce_14m(ce_14m),
        .ce_7m(ce_7m),.ce_3m58(ce_3m58),.ce_1m19(ce_1m19),
        .clock_3m58(clk_3m58),.clock_1m19(clk_1m19));
    wire hblank_board, vblank_board;
    wire [23:1] cpu_address;
    wire [15:0] cpu_write,cpu_read,video_data;
    wire cpu_as_n,cpu_uds_n,cpu_lds_n,cpu_rw,cpu_dtack_n,cpu_vpa_n,video_n,vdtack_n,vint_n;
    wire [2:0] cpu_fc,cpu_ipl_n;
    wire cpu_reset,cpu_halted_n;
    wire [3:0] coins;
    wire sound_reset_n,ym_reset_n,oki_reset_n,ym_write,ym_port,oki_write;
    wire [7:0] sound_data,volume,nv_read;
    wire [8:0] control;
    wire [19:0] sample_rom_addr;
    assign nv_board_idle=cpu_reset && cpu_as_n && cpu_uds_n && cpu_lds_n;
    wire seed_write=ld_wr && ioctl_addr>=27'h400000;
    relief_main u_main(.clk_sys(clk_sys),.init_reset(init_reset),.reset(reset||!rom_loaded||downloading||nv_restore_hold),
        .ce_7m(ce_7m),.ce_3m58(ce_3m58),.clock_3m58(clk_3m58),
        .hblank(hblank_board),.vblank(vblank_board),.vint_n(vint_n),.vdtack_n(vdtack_n),.video_data(video_data),
        .player1_n(~{p1_joy,p1_b3,p1_b2,p1_b1,p1_start}),
        .player2_n(~{p2_joy,p2_b3,p2_b2,p2_b1,p2_start}),
        .player3_n(8'hff),.player4_n(8'hff),.service_n({3'b111,!service}),.coin_n({2'b11,!coin2,!coin1}),
        .self_test_n(!self_test),.vup_n(!volume_up),.vdn_n(!volume_down),.opt_sw(1'b1),.oki_status(oki_status),
        .sample_addr(oki_addr),.eeprom_upper_address(2'b00),.nv_active(downloading||nv_restore_active),.nv_we(nv_restore_active ? nv_restore_we : seed_write),
        .nv_protect_we(nv_restore_active ? nv_restore_protect_we : (seed_write && ioctl_addr==27'h400000)),.nv_protected(nv_restore_active ? nv_restore_protected : 1'b0),
        .nv_address(nv_restore_active ? nv_restore_address : {2'b00,ioctl_addr[10:0]}),.nv_data(nv_restore_active ? nv_restore_data : ioctl_dout),.nv_read_data(nv_read),.nv_busy(nv_busy),.nv_sdp(nv_sdp),
        .nv_cell_we(nv_cell_we),.nv_cell_address(nv_cell_address),.nv_cell_data(nv_cell_data),
        .address(cpu_address),.write_data(cpu_write),.read_data(cpu_read),.as_n(cpu_as_n),
        .uds_n(cpu_uds_n),.lds_n(cpu_lds_n),.rw(cpu_rw),.dtack_n(cpu_dtack_n),.vpa_n(cpu_vpa_n),
        .video_n(video_n),.fc(cpu_fc),.ipl_n(cpu_ipl_n),.cpu_reset(cpu_reset),.halted_n(cpu_halted_n),
        .coin_counter(coins),.sound_reset_n(sound_reset_n),.ym_reset_n(ym_reset_n),.oki_reset_n(oki_reset_n),
        .ym_write(ym_write),.ym_port(ym_port),.oki_write(oki_write),.sound_data(sound_data),.volume(volume),.control(control),
        .sample_rom_addr(sample_rom_addr),.c_req(c_req),.c_addr(c_addr),.c_blen(c_blen),.c_valid(c_valid),.c_last(c_last),.c_data(c_data));
    relief_ym u_ym(.clk(clk_sys),.reset(init_reset||!ym_reset_n),.ce_3m58(ce_3m58),
        .wr(ym_write),.a0(ym_port),.data(sound_data),.melody(melody),.rhythm(rhythm),
        .melody_en(melody_en),.rhythm_en(rhythm_en),.overflow(ym_overflow));
    relief_oki u_oki(.clk(clk_sys),.ce_1m19(ce_1m19),.okires_n(!init_reset&&oki_reset_n),
        .wr_stb(oki_write),.wr_data(sound_data),.rd_data(oki_status),
        .oki_req(oki_req),.oki_addr(oki_addr),.oki_ack(oki_ack),.oki_data(oki_byte),
        .audio(adpcm),.audio_stb(adpcm_stb),.late(oki_late));
    relief_video u_video(.clk(clk_sys),.reset(init_reset||reset||downloading||!rom_loaded||nv_restore_hold),.ce_14m(ce_14m),
        .vram_n(video_n),.rw(cpu_rw),.wl_n(cpu_lds_n),.wu_n(cpu_uds_n),.ma(cpu_address[16:1]),
        .din(cpu_write),.dout(video_data),.vdtack_n(vdtack_n),.vint_n(vint_n),.iack(cpu_fc==3'b111),
        .snap_wr(1'b0),.snap_cr(1'b0),.snap_a(15'd0),.snap_d(16'd0),
        .pf1_req(pf1_req),.pf1_addr(pf1_addr),.pf1_ack(pf1_ack),.pf1_group(pf1_group),
        .pf2_req(pf2_req),.pf2_addr(pf2_addr),.pf2_ack(pf2_ack),.pf2_group(pf2_group),
        .mo_req(mo_req),.mo_addr(mo_addr),.mo_ack(mo_ack),.mo_group(mo_group),
        .mix_index(mix_index),.mix_pf_pen(mix_pf_pen),.mix_pf_colour(mix_pf_colour),
        .mix_background(mix_background),.mix_mo(mix_mo),
        .ce_pix(ce_pix),.vga_r(vga_r),.vga_g(vga_g),.vga_b(vga_b),.pix_index(pix_index),
        .hblank(hblank),.vblank(vblank),.hsync(hsync),.vsync(vsync),
        .hblank_board(hblank_board),.vblank_board(vblank_board),.beam_h(beam_h),.beam_v(beam_v),
        .gfx_late(gfx_late),.eof_late(eof_late),.mo_words_line(mo_words_line),.cpu_words_line(cpu_words_line),.dma_words_line(dma_words_line),
        .cpu_wait_worst(cpu_wait_worst),.cram_steal(cram_steal));
    generate if (SOUND_OUT) begin: sound_out
        wire signed [15:0] sample;
        wire sound_late, sound_clipped;
        relief_audio_out u_audio(.clk(clk_sys),.reset(init_reset),.ce_3m58(ce_3m58),
            .melody(melody),.rhythm(rhythm),.adpcm(adpcm),.tm(control[4:1]),.dvc(volume),
            .sample(sample),.late(sound_late),.clipped(sound_clipped));
        assign aud_l=sample;
        assign aud_r=sample;
        wire unused_sound=&{1'b0,sound_late,sound_clipped};
    end else begin: silent
        assign aud_l=16'sd0;
        assign aud_r=16'sd0;
    end endgenerate
    assign {bus_address,bus_write,bus_as_n,bus_rw,bus_uds_n,bus_lds_n}=
        {cpu_address,cpu_write,cpu_as_n,cpu_rw,cpu_uds_n,cpu_lds_n};
    assign cctr1=coins[0];
    assign cctr2=coins[3];
    wire unused=&{1'b0,tilt,clk_1m19,coins[2:1],cpu_read,cpu_dtack_n,cpu_vpa_n,cpu_fc,cpu_ipl_n,cpu_reset,cpu_halted_n,
        sound_reset_n,ym_reset_n,oki_reset_n,ym_write,ym_port,oki_write,sound_data,volume,control,
        sample_rom_addr,nv_read,pf1_byte,pf2_byte,mo_byte,oki_byte,oki_ack,
        mo_words_line,cpu_words_line,dma_words_line,cpu_wait_worst,cram_steal};
endmodule
