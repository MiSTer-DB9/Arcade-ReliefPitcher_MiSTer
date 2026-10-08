// SPDX-License-Identifier: GPL-3.0-or-later
// Band-limit the voltage-domain output before platform audio sampling.
module relief_audio_bandlimit (
    input wire clk, reset, tick,
    input wire signed [31:0] sample_in,
    output reg signed [31:0] sample_out,
    output reg valid, busy, late, clipped
);
    reg [8:0] head, cursor;
    reg [9:0] filled;
    reg [6:0] group_index;
    reg issuing, read_valid, product_valid, last_read, last_product;
    wire signed [56:0] product [0:3];
    genvar lane;
    generate for(lane=0;lane<4;lane=lane+1) begin: bank
        localparam [1:0] BANK = 2'(lane);
        reg signed [31:0] history [0:127];
        reg signed [31:0] history_q;
        reg sample_present;
        wire signed [31:0] sample_q = sample_present ? history_q : 32'sd0;
        reg signed [24:0] coefficient_q;
        reg signed [56:0] product_q;
        wire [1:0] offset = cursor[1:0] - BANK;
        wire [8:0] tap_index = {group_index,2'b00} + {7'd0,offset};
        wire [8:0] history_address = cursor - tap_index;
        wire signed [24:0] coefficient;
        relief_audio_fir_coeff u_coeff(.address(tap_index),.coefficient(coefficient));
        always @(posedge clk) begin
            if(tick && !busy && !reset && head[1:0]==BANK)
                history[head[8:2]]<=sample_in;
            if(busy && issuing) begin
                history_q <= history[history_address[8:2]];
                sample_present <= {1'b0,tap_index}<filled;
                coefficient_q<=coefficient;
            end
            if(read_valid) product_q<=sample_q*coefficient_q;
        end
        assign product[lane]=product_q;
        wire unused = &{1'b0,history_address[1:0]};
    end endgenerate
    reg signed [65:0] accumulator;
    wire signed [65:0] sum = accumulator +
        {{9{product[0][56]}},product[0]} + {{9{product[1][56]}},product[1]} +
        {{9{product[2][56]}},product[2]} + {{9{product[3][56]}},product[3]};
    wire signed [65:0] rounded = (sum + 66'sd8388608) >>> 24;
    wire overflow = rounded>66'sd2147483647 || rounded< -66'sd2147483648;
    wire signed [31:0] result = rounded>66'sd2147483647 ? 32'sh7fffffff :
        rounded< -66'sd2147483648 ? 32'sh80000000 : rounded[31:0];
    always @(posedge clk) begin
        valid<=0;
        if(reset) begin
            head<=0;cursor<=0;filled<=0;group_index<=0;
            issuing<=0;read_valid<=0;product_valid<=0;last_read<=0;last_product<=0;
            accumulator<=0;sample_out<=0;busy<=0;late<=0;clipped<=0;
        end else begin
            read_valid<=busy && issuing;
            product_valid<=read_valid;
            last_read<=busy && issuing && group_index==127;
            last_product<=last_read;
            if(tick && busy) late<=1;
            if(tick && !busy) begin
                cursor<=head;head<=head+1'b1;
                if(filled<512) filled<=filled+1'b1;
                group_index<=0;issuing<=1;busy<=1;accumulator<=0;
            end
            if(busy && issuing) begin
                if(group_index==127) issuing<=0;
                else group_index<=group_index+1'b1;
            end
            if(product_valid) begin
                accumulator<=sum;
                if(last_product) begin
                    sample_out<=result;valid<=1;busy<=0;
                    if(overflow) clipped<=1;
                end
            end
        end
    end
endmodule
