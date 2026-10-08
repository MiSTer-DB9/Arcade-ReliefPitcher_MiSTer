// SPDX-License-Identifier: GPL-3.0-or-later
// KM28C64A 8K x 8 EEPROM, with a second port that MiSTer uses to load and
// save its contents.
module relief_eeprom #(
    parameter longint unsigned CLK_HZ = 57272727,
    parameter int LOAD_CYCLES = int'((CLK_HZ * 150 + 999999) / 1000000),
    parameter int WRITE_CYCLES = int'((CLK_HZ * 5 + 999) / 1000),
    parameter int POWERUP_CYCLES = WRITE_CYCLES
)(
    input  logic clk_sys, power_reset,
    input  logic ce_n, oe_n, we_n,
    input  logic [12:0] address,
    input  logic [7:0] data_in,
    output logic [7:0] data_out,
    output logic data_drive, busy, sdp_enabled,
    input  logic host_active, host_we, host_protect_we,
    input  logic [12:0] host_address,
    input  logic [7:0] host_data_in,
    input  logic host_protected,
    output logic [7:0] host_data_out,
    output wire cell_we,
    output wire [12:0] cell_address,
    output wire [7:0] cell_data
);
    localparam int LW = $clog2(LOAD_CYCLES + 1);
    localparam int WW = $clog2(WRITE_CYCLES + 1);
    localparam int PW = $clog2(POWERUP_CYCLES + 1);
    typedef enum logic [1:0] {IDLE, LOAD, PROGRAM} phase_t;
    phase_t phase;
    logic [LW-1:0] load_left;
    logic [WW-1:0] write_left;
    logic [PW-1:0] powerup_left;
    logic [7:0] mem [0:8191];
    logic [7:0] page_buffer [0:63];
    logic [63:0] page_valid;
    logic [6:0] page_address;
    logic [12:0] latched_address;
    logic last_msb;
    logic [7:0] read_q;
    logic wr_prev, rd_prev, load_closed, toggle;
    logic authorized, protect_pending, protect_next;
    logic [2:0] command;

    wire writing = !ce_n && !we_n && oe_n;
    wire reading = !ce_n && we_n && !oe_n;
    wire write_start = writing && !wr_prev;
    wire write_end = wr_prev && (ce_n || we_n) && oe_n;
    wire accept_write = write_end && phase != PROGRAM && !load_closed && powerup_left == 0;
    wire aa = latched_address == 13'h1555 && data_in == 8'haa;
    wire fifty_five = latched_address == 13'h0aaa && data_in == 8'h55;
    wire at_command = latched_address == 13'h1555;
    wire enable_command = !authorized && command == 2 && at_command && data_in == 8'ha0;
    wire disable_command = !authorized && command == 5 && at_command && data_in == 8'h20;
    wire [5:0] commit_index = 6'(64 - write_left);
    wire commit = phase == PROGRAM && write_left <= WW'(64) && write_left != 0;
    assign cell_we = (host_active && host_we) ||
                     (!host_active && !power_reset && commit && page_valid[commit_index]);
    assign cell_address = host_active ? host_address : {page_address,commit_index};
    assign cell_data = host_active ? host_data_in : page_buffer[commit_index];

    initial begin
        if (LOAD_CYCLES < 2 || WRITE_CYCLES <= LOAD_CYCLES + 64 || POWERUP_CYCLES < 2)
            $error("Invalid EEPROM timing parameters");
        sdp_enabled = 0;
        for (integer bank = 0; bank < 2; bank = bank + 1)
            for (integer i = 0; i < 4096; i = i + 1) mem[bank * 4096 + i] = 8'hff;
    end

    // The MiSTer port owns the array while the board is held in reset.
    always_ff @(posedge clk_sys) begin
        if (host_active && host_we) mem[host_address] <= host_data_in;
        else if (!host_active && !power_reset && commit && page_valid[commit_index])
            mem[{page_address, commit_index}] <= page_buffer[commit_index];
        read_q <= mem[host_active ? host_address : address];
    end

    assign busy = phase != IDLE || powerup_left != 0;
    assign host_data_out = read_q;
    assign data_drive = reading && !host_active && !power_reset;
    assign data_out = phase != IDLE ? {~last_msb, toggle, 6'b111111} : read_q;

    always @(posedge clk_sys) begin
        if (host_active && host_protect_we) sdp_enabled <= host_protected;
        if (power_reset || host_active) begin
            phase <= IDLE;
            load_left <= 0;
            write_left <= 0;
            powerup_left <= PW'(POWERUP_CYCLES);
            page_valid <= 0;
            page_address <= 0;
            latched_address <= 0;
            last_msb <= 0;
            wr_prev <= 0;
            rd_prev <= 0;
            load_closed <= 0;
            toggle <= 0;
            authorized <= 0;
            protect_pending <= 0;
            protect_next <= 0;
            command <= 0;
        end else begin
            if (powerup_left != 0) powerup_left <= powerup_left - 1'b1;
            wr_prev <= writing;
            rd_prev <= reading;
            if (reading && !rd_prev && phase != IDLE) toggle <= !toggle;
            if (write_start) latched_address <= address;

            if (phase == LOAD) begin
                if (!oe_n) load_closed <= 1;
                if (writing && !load_closed) load_left <= LW'(LOAD_CYCLES);
                else if (load_left > 1) load_left <= load_left - 1'b1;
                else begin
                    phase <= PROGRAM;
                    load_left <= 0;
                end
            end
            if (phase != IDLE && !(phase == LOAD && writing && !load_closed)) begin
                if (write_left > 1) write_left <= write_left - 1'b1;
                else begin
                    phase <= IDLE;
                    write_left <= 0;
                    page_valid <= 0;
                    load_closed <= 0;
                    authorized <= 0;
                    command <= 0;
                    protect_pending <= 0;
                    if (protect_pending) sdp_enabled <= protect_next;
                end
            end

            if (accept_write) begin
                if (!sdp_enabled || authorized || command != 0 || aa) begin
                    phase <= LOAD;
                    load_left <= LW'(LOAD_CYCLES);
                    write_left <= WW'(WRITE_CYCLES);
                    last_msb <= data_in[7];
                    toggle <= 0;
                    page_address <= latched_address[12:6];
                end
                if (!sdp_enabled || authorized) begin
                    page_buffer[latched_address[5:0]] <= data_in;
                    page_valid[latched_address[5:0]] <= 1;
                end

                if (enable_command || disable_command) begin
                    page_valid <= 0;
                    authorized <= 1;
                    protect_pending <= 1;
                    protect_next <= enable_command;
                    command <= 0;
                end else if (!authorized) begin
                    case (command)
                        0: command <= aa ? 3'd1 : 3'd0;
                        1: command <= fifty_five ? 3'd2 : 3'd0;
                        2: command <= (at_command && data_in == 8'h80) ? 3'd3 : 3'd0;
                        3: command <= aa ? 3'd4 : 3'd0;
                        4: command <= fifty_five ? 3'd5 : 3'd0;
                        default: command <= 0;
                    endcase
                end
            end
        end
    end
endmodule
