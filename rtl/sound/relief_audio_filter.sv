// SPDX-License-Identifier: GPL-3.0-or-later
// Component-derived small-signal path. Inputs and output use Q20 volts.
module relief_audio_filter #(parameter YM_INPUT_FILTERED = 1'b0) (
    input wire clk, reset, tick,
    input wire signed [31:0] mo_volts, ro_volts, oki_volts,
    input wire [3:0] tm,
    input wire [7:0] dvc,
    output reg signed [31:0] mixed_volts,
    output reg valid, busy, late, clipped
);
    reg signed [31:0] x1 [0:5], x2 [0:5], y1 [0:5], y2 [0:5];
    reg signed [31:0] mo, ro, oki, current;
    reg [3:0] held_tm;
    reg [7:0] held_dvc;
    reg [2:0] section, term;
    reg [1:0] phase;
    wire signed [31:0] rom_coefficient;
    wire signed [31:0] coefficient = YM_INPUT_FILTERED && section<2 ?
        (term==0 ? 32'sd67108864 : 32'sd0) : rom_coefficient;
    relief_audio_coeff u_coeff(.section(section),.term(term),.tm(held_tm),
        .dvc(held_dvc),.coefficient(rom_coefficient));
    wire signed [31:0] input_sample = section==0 ? mo : section==1 ? ro : section==2 ? oki : current;
    reg signed [31:0] operand;
    always @* begin
        operand = 0;
        if(section==6) begin
            case(term)
                0: operand=y1[0];
                1: operand=y1[1];
                2: operand=current;
                default: ;
            endcase
        end else if(section==7) begin
            if(term==0) operand=current;
        end else begin
            case(term)
                0: operand=input_sample;
                1: operand=x1[section];
                2: operand=x2[section];
                3: operand=y1[section];
                4: operand=y2[section];
                default: ;
            endcase
        end
    end
    reg signed [31:0] coefficient_r, operand_r;
    reg signed [63:0] product;
    reg signed [66:0] accumulator;
    wire signed [66:0] rounded = (accumulator + 67'sd33554432) >>> 26;
    wire overflow = rounded>67'sd2147483647 || rounded< -67'sd2147483648;
    wire signed [31:0] result = rounded>67'sd2147483647 ? 32'sh7fffffff :
                               rounded< -67'sd2147483648 ? 32'sh80000000 : rounded[31:0];
    always @(posedge clk) begin
        valid<=0;
        if(reset) begin
            busy<=0;late<=0;clipped<=0;mixed_volts<=0;
            mo<=0;ro<=0;oki<=0;current<=0;held_tm<=0;held_dvc<=0;
            section<=0;term<=0;phase<=0;coefficient_r<=0;operand_r<=0;product<=0;accumulator<=0;
            for(integer i=0;i<6;i=i+1) begin x1[i]<=0;x2[i]<=0;y1[i]<=0;y2[i]<=0;end
        end else begin
            if(tick && busy) late<=1;
            if(!busy) begin
                if(tick) begin
                    mo<=mo_volts;ro<=ro_volts;oki<=oki_volts;
                    held_tm<=tm;held_dvc<=dvc;
                    section<=0;term<=0;phase<=0;accumulator<=0;busy<=1;
                end
            end else case(phase)
                0: begin coefficient_r<=coefficient;operand_r<=operand;phase<=1;end
                1: begin product<=coefficient_r*operand_r;phase<=2;end
                2: begin
                    accumulator<=accumulator+{{3{product[63]}},product};
                    if(term==4) phase<=3;
                    else begin term<=term+1'b1;phase<=0;end
                end
                3: begin
                    if(overflow) clipped<=1;
                    current<=result;
                    if(section<6) begin
                        x2[section]<=x1[section];x1[section]<=input_sample;
                        y2[section]<=y1[section];y1[section]<=result;
                    end
                    if(section==7) begin mixed_volts<=result;valid<=1;busy<=0;end
                    else begin section<=section+1'b1;term<=0;phase<=0;accumulator<=0;end
                end
            endcase
        end
    end
endmodule
