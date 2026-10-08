// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 RetroShrimp.
// Bus adapter derived from Rampart. Keep both impulse DAC pins separate.
module relief_ym (
    input wire clk, reset, ce_3m58, wr, a0,
    input wire [7:0] data,
    output wire signed [9:0] melody, rhythm,
    output wire melody_en, rhythm_en,
    output reg overflow
);
    reg pending, held_a0;
    reg [7:0] held_data;
    always @(posedge clk) begin
        if (reset) begin
            pending <= 1'b0;
            held_a0 <= 1'b0;
            held_data <= 8'd0;
            overflow <= 1'b0;
        end else begin
            if (ce_3m58) pending <= 1'b0;
            if (wr) begin
                if (pending && !ce_3m58) overflow <= 1'b1;
                pending <= 1'b1;
                held_a0 <= a0;
                held_data <= data;
            end
        end
    end
    wire signed [9:0] pin_mo, pin_ro;
    wire en_mo, en_ro;
    wire unused_xout, unused_oe, unused_sign, unused_stb;
    wire [1:0] unused_data;
    wire [7:0] unused_mag;
    wire signed [15:0] unused_acc;
    IKAOPLL #(.FULLY_SYNCHRONOUS(1), .FAST_RESET(0),
        .ALTPATCH_CONFIG_MODE(0), .USE_PIPELINED_MULTIPLIER(1)) u_opll (
        .i_XIN_EMUCLK(clk), .i_phiM_PCEN_n(~ce_3m58), .i_IC_n(~reset),
        .i_ALTPATCH_EN(1'b0), .i_CS_n(~pending), .i_WR_n(~pending),
        .i_A0(held_a0), .i_D(held_data), .o_XOUT(unused_xout),
        .o_D(unused_data), .o_D_OE(unused_oe),
        .o_DAC_EN_MO(en_mo), .o_DAC_EN_RO(en_ro),
        .o_IMP_NOFLUC_SIGN(unused_sign), .o_IMP_NOFLUC_MAG(unused_mag),
        .o_IMP_FLUC_SIGNED_MO(pin_mo), .o_IMP_FLUC_SIGNED_RO(pin_ro),
        .i_ACC_SIGNED_MOVOL(5'sd1), .i_ACC_SIGNED_ROVOL(5'sd1),
        .o_ACC_SIGNED_STRB(unused_stb), .o_ACC_SIGNED(unused_acc)
    );
    assign melody = reset ? 10'sd0 : pin_mo;
    assign rhythm = reset ? 10'sd0 : pin_ro;
    assign melody_en = !reset && en_mo;
    assign rhythm_en = !reset && en_ro;
    wire unused = &{1'b0,unused_xout,unused_oe,unused_sign,unused_stb,
                    unused_data,unused_mag,unused_acc};
endmodule
