// SPDX-License-Identifier: GPL-3.0-or-later
// Address-pin adapter for the 15F decode GAL.
module relief_decode (
    input wire [21:1] address,
    input wire as_n, edt, vdtack_n,
    output wire [1:0] rom_n,
    output wire e0_n,e1_n,ioen_n,base_wait_n,handshake_wait_n
);
    wire [19:1] pin;
    wire [19:12] value,drive;
    assign pin[19:12]=8'd0;
    assign pin[11]=as_n;
    assign pin[10]=1'b0;
    assign pin[9]=vdtack_n;
    assign pin[8]=address[15];
    assign pin[7]=address[16];
    assign pin[6]=address[17];
    assign pin[5]=address[18];
    assign pin[4]=address[19];
    assign pin[3]=address[20];
    assign pin[2]=address[21];
    assign pin[1]=edt;
    relief_gal_0002 u_gal(.clk(1'b0),.ce(1'b0),.reset(1'b0),.pin(pin),.value(value),.drive(drive));
    assign rom_n={value[18],value[19]};
    assign e0_n=value[16];
    assign e1_n=value[17];
    assign base_wait_n=value[13];
    assign handshake_wait_n=value[15];
    assign ioen_n=value[14];
    wire unused=&{1'b0,address[14:1],value[12],drive};
endmodule
