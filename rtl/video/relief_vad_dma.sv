// SPDX-License-Identifier: GPL-3.0-or-later
// Adapted from the Batman VAD DMA model.
// Copyright (C) 2026 the Batman MiSTer core authors.
`timescale 1ns/1ps
module relief_vad_dma #(
    parameter bit AS_LATCH_DMA = 1'b0
)(
    input logic clk, reset,
    input logic line_start,
    input logic [8:0] vpos,
    input logic vblank, dma_enable, oas_en,
    input logic [14:0] base_pf1, base_pf2, base_attr, base_slip,
    input logic eof_req,
    input logic [5:0] eof_idx,
    output logic [15:0] eof_data,
    output logic eof_ack,
    input logic [7:0] pf1_attr_latch, pf2_attr_latch,
    input logic cpu_wr_stb,
    input logic [14:0] cpu_wr_a,
    output logic as_req,
    output logic [14:0] as_a,
    output logic [15:0] as_d,
    output logic [1:0] as_ds,
    output logic dma_rq,
    output logic [14:0] dma_a,
    input logic dma_ack,
    input logic [15:0] dma_q,
    output logic [10:0] eof_words,
    output logic eof_late
);
    typedef enum logic [1:0] {IDLE, READ, RELEASE} state_t;
    state_t state;
    assign dma_rq = state == READ;
    always_ff @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
            dma_a <= 15'd0;
            eof_data <= 16'd0;
            eof_ack <= 1'b0;
            eof_words <= 11'd0;
            eof_late <= 1'b0;
        end else begin
            eof_ack <= 1'b0;
            if (line_start && vpos == 0) eof_words <= 11'd0;
            if (!vblank && (state == READ || (eof_req && dma_enable)))
                eof_late <= 1'b1;
            case (state)
                IDLE: if (eof_req && dma_enable && vblank) begin
                    dma_a <= base_slip - 15'd64 + {9'd0, eof_idx};
                    state <= READ;
                end
                READ: if (dma_ack) begin
                    eof_data <= dma_q;
                    eof_ack <= 1'b1;
                    eof_words <= eof_words + 11'd1;
                    state <= RELEASE;
                end
                RELEASE: if (!eof_req) state <= IDLE;
                default: state <= IDLE;
            endcase
        end
    end

    wire in_pf1 = cpu_wr_a[14:12] == base_pf1[14:12];
    wire in_pf2 = cpu_wr_a[14:12] == base_pf2[14:12];
    logic [7:0] as_byte_lat;
    logic as_hi_lat;
    always_ff @(posedge clk) begin
        if (reset) begin
            as_req <= 1'b0;
            as_a <= 15'd0;
            as_ds <= 2'b00;
            as_byte_lat <= 8'd0;
            as_hi_lat <= 1'b0;
        end else begin
            as_req <= 1'b0;
            if (cpu_wr_stb && dma_enable && oas_en && (in_pf1 || in_pf2)) begin
                as_req <= 1'b1;
                as_a <= base_attr + {3'd0, cpu_wr_a[11:0]};
                as_ds <= in_pf1 ? 2'b10 : 2'b01;
                as_hi_lat <= in_pf1;
                as_byte_lat <= in_pf1 ? pf1_attr_latch : pf2_attr_latch;
            end
        end
    end
    wire [7:0] as_byte = AS_LATCH_DMA
        ? (as_hi_lat ? pf1_attr_latch : pf2_attr_latch) : as_byte_lat;
    assign as_d = {as_byte, as_byte};
    /* verilator lint_off UNUSEDSIGNAL */
    wire unused_bases = &{1'b0, base_pf1[11:0], base_pf2[11:0]};
    /* verilator lint_on UNUSEDSIGNAL */
endmodule
