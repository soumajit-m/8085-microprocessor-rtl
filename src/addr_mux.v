`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////// 
// Engineer: Soumajit Mandal (Roll: 2023ETB016)
// 
// Create Date: 08/14/2026
// Design Name: 8085_Datapath
// Module Name: addr_mux
// Project Name: 8085
// Description: 16-bit multiplexer for external memory addressing
// 
// Revision:
// Revision 1.00 - 08/27/2026 - Address routing for PC, HL, SP, and WZ
// Revision 2.00 - 10/02/2026 - Integrated with stack and I/O bus multiplexing
//////////////////////////////////////////////////////////////////////////////////

module addr_mux(
    input wire [15:0] pc_in,        // Program Counter
    input wire [15:0] hl_in,        // HL Register Pair
    input wire [15:0] sp_in,        // Stack Pointer
    input wire [15:0] alt_pair_in,  // WZ temporary pair
    input wire [1:0] addr_mux_sel,
    output reg [15:0] addr_out
);
    always @(*) begin
        case(addr_mux_sel)
            2'b00: addr_out = pc_in;       
            2'b01: addr_out = hl_in;       
            2'b10: addr_out = sp_in;       
            2'b11: addr_out = alt_pair_in; 
            default: addr_out = pc_in;
        endcase
    end
endmodule
