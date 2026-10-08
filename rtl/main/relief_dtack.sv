// SPDX-License-Identifier: GPL-3.0-or-later
// Wait-state counter (a 74F163 on the board) that times DTACK for the CPU.
// Adapted from the Batman core. The counter's wiring is inferred.
// Copyright (C) 2026 the Batman MiSTer core authors.
module relief_dtack (
    input wire clk_sys,ce_7m,reset,as_n,
    input wire base_wait_n,handshake_wait_n,vpa_n,
    input wire memory_ready,
    output wire dtack_n,
    output reg [3:0] count
);
    wire [3:0] parallel_data={vpa_n,handshake_wait_n,1'b1,base_wait_n};
    always @(posedge clk_sys) begin
        if(reset) count<=4'd0;
        else if(ce_7m) begin
            if(as_n) count<=4'd0;
            else if(!count[2]) count<=parallel_data;
            else if(count!=4'hf) count<=count+4'd1;
        end
    end
    // SDRAM stalls may extend a board cycle but must not shorten a board wait.
    assign dtack_n=as_n || count!=4'hf || !memory_ready;
endmodule
