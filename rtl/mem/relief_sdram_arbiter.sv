// SPDX-License-Identifier: GPL-3.0-or-later
// Downloads have priority; accepted CPU bursts always drain completely.
module relief_sdram_arbiter (
    input wire clk_sys,init_reset,downloading,
    input wire dl_wr,
    input wire [23:0] dl_addr,
    input wire [15:0] dl_data,
    output wire dl_ack,
    input wire c_req,
    input wire [23:0] c_addr,
    input wire [1:0] c_blen,
    output wire c_valid,c_last,
    output wire [15:0] c_data,
    input wire sd_ready,sd_valid,
    input wire [15:0] sd_data,
    output wire sd_req,sd_we,
    output wire [23:0] sd_addr,
    output wire [15:0] sd_wdata,
    output wire [2:0] sd_blen,
    output wire idle
);
    reg reading,claimed;
    reg [1:0] beat,last;
    wire take_write=dl_wr && sd_ready && !reading;
    wire take_read=c_req && !claimed && !reading && !downloading && !dl_wr && sd_ready;
    assign sd_req=take_write || take_read;
    assign sd_we=take_write;
    assign sd_addr=take_write ? dl_addr : c_addr;
    assign sd_wdata=dl_data;
    assign sd_blen=take_write ? 3'd0 : {1'b0,c_blen};
    assign dl_ack=take_write;
    assign c_valid=reading && sd_valid;
    assign c_last=c_valid && beat==last;
    assign c_data=sd_data;
    assign idle=!reading && !dl_wr && sd_ready;
    always @(posedge clk_sys) begin
        if(init_reset) begin reading<=0;claimed<=0;beat<=0;last<=0;end
        else begin
            if(!c_req) claimed<=0;
            if(take_read) begin reading<=1;claimed<=1;beat<=0;last<=c_blen;end
            if(c_valid) begin
                beat<=beat+2'd1;
                if(c_last) reading<=0;
            end
        end
    end
endmodule
