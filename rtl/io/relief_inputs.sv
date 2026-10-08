// SPDX-License-Identifier: GPL-3.0-or-later
// Physical switch muxes, CIO decoder and six-bit output latch.
module relief_inputs (
    input wire clk_sys, reset_n, bas, cio_n,
    input wire [6:1] ma,
    input wire [15:0] data,
    input wire [7:0] player1_n, player2_n, player3_n, player4_n,
    input wire [3:0] service_n, coin_n,
    input wire vblank_n, self_test_n, audfull_n, audirq_n,
    input wire vup_n, vdn_n, opt_sw, vidbl_n,
    output wire [7:0] select_n,
    output wire [15:0] read_data, read_drive,
    output reg [3:0] coin_counter,
    output reg sound_reset_n, leta_reset
);
    assign select_n = (!cio_n && bas) ? ~(8'b1 << ma[6:4]) : 8'hff;
    wire [15:0] players = ma[1] ? {player2_n,player4_n} : {player1_n,player3_n};
    wire [7:0] status = ma[1] ? {service_n,coin_n} :
        {vblank_n,self_test_n,audfull_n,audirq_n,vup_n,vdn_n,opt_sw,vidbl_n};
    assign read_data = !select_n[0] ? players : !select_n[1] ? {8'hff,status} : 16'hffff;
    assign read_drive = !select_n[0] ? 16'hffff : !select_n[1] ? 16'h00ff : 16'h0000;
    reg old_latch_n;
    always @(posedge clk_sys) begin
        old_latch_n <= select_n[5];
        if (!reset_n) begin
            coin_counter <= 4'd0;
            sound_reset_n <= 1'b0;
            leta_reset <= 1'b0;
            old_latch_n <= 1'b1;
        end else if (!old_latch_n && select_n[5]) begin
            coin_counter <= data[3:0];
            sound_reset_n <= data[4];
            leta_reset <= data[8];
        end
    end
    wire unused = &{1'b0,ma[3:2],data[15:9],data[7:5]};
endmodule
