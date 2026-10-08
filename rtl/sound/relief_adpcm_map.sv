// SPDX-License-Identifier: GPL-3.0-or-later
// 9B/10B mask ROM addressing. The unpopulated 12B socket stays deselected.
module relief_adpcm_map(input wire [17:0] va, input wire [2:0] bank,
    output wire [19:0] rom_addr, output wire empty_socket);
    assign rom_addr = {(!va[17] & bank[2]), (!va[17] & bank[1]),
                       (va[17] | bank[0]), va[16:0]};
    assign empty_socket = 1'b0;
endmodule
