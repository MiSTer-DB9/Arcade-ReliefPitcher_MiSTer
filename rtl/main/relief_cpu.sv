// SPDX-License-Identifier: GPL-3.0-or-later
// Adapted from the Batman/Skull & Crossbones CPU wrapper.
// Copyright (C) 2026 the Batman MiSTer core authors.
module relief_cpu (
    input wire clk_sys, ce_7m, reset,
    input wire [2:0] ipl_n,
    input wire [15:0] read_data,
    input wire dtack_n, vpa_n,
    output wire [23:1] address,
    output wire [15:0] write_data,
    output wire as_n, uds_n, lds_n, rw,
    output wire [2:0] fc,
    output wire reset_instruction, halted_n
);
    reg [2:0] phase;
    always @(posedge clk_sys) begin
        if(ce_7m) phase <= 3'd1;
        else phase <= phase+3'd1;
    end
    wire phi2 = phase==3'd4;
    reg [2:0] ipl_meta, ipl_sync;
    always @(posedge clk_sys) begin
        if(reset) begin ipl_meta<=3'b111;ipl_sync<=3'b111;end
        else begin ipl_meta<=ipl_n;ipl_sync<=ipl_meta;end
    end
    wire fx_reset_n, e, vma_n, bg_n;
    assign reset_instruction = !fx_reset_n;
    fx68k u_cpu(.clk(clk_sys),.extReset(reset),.pwrUp(reset),.HALTn(1'b1),
        .enPhi1(ce_7m),.enPhi2(phi2),.eRWn(rw),.ASn(as_n),.LDSn(lds_n),.UDSn(uds_n),
        .E(e),.VMAn(vma_n),.FC0(fc[0]),.FC1(fc[1]),.FC2(fc[2]),.BGn(bg_n),
        .oRESETn(fx_reset_n),.oHALTEDn(halted_n),.DTACKn(dtack_n),.VPAn(vpa_n),
        .BERRn(1'b1),.BRn(1'b1),.BGACKn(1'b1),
        .IPL0n(ipl_sync[0]),.IPL1n(ipl_sync[1]),.IPL2n(ipl_sync[2]),
        .iEdb(read_data),.oEdb(write_data),.eab(address));
    wire unused=&{1'b0,e,vma_n,bg_n};
endmodule
