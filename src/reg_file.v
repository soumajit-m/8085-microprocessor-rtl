`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////// 
// Engineer: Soumajit Mandal (Roll: 2023ETB016)
// 
// Create Date: 09/18/2026
// Design Name: 8085_Datapath
// Module Name: reg_file
// Project Name: 8085
// Description: Register File Module with 16-bit Pair Operations
// 
// Revision:
// Revision 1.00 - Added 16-bit WZ pair writing, INX, DCX, and DAD logic
//////////////////////////////////////////////////////////////////////////////////

module reg_file(
    // System control signals
    input wire clk,
    input wire rst,
    
    // Read port selection (0-7 mapped to B, C, D, E, H, L, Mem, A)
    input wire [2:0] read_sel_1,
    input wire [2:0] read_sel_2,
    
    // 8-bit Write port control and data input
    input wire [2:0] write_sel,
    input wire write_en,
    input wire [7:0] write_data,
    
    // --------------------------------------------------------
    // 16-bit Pair Control Ports (New additions)
    // --------------------------------------------------------
    input wire [1:0] reg_pair_sel,        // 00=BC, 01=DE, 10=HL
    input wire reg_pair_write_en,         // Triggered by LXI and POP
    input wire [15:0] reg_pair_write_data,// Incoming 16-bit data (wz_pair)
    input wire reg_pair_inc,              // Triggered by INX
    input wire reg_pair_dec,              // Triggered by DCX
    input wire reg_pair_add,              // Triggered by DAD
    // --------------------------------------------------------
    
    // Asynchronous data outputs for ALU operations
    output reg [7:0] read_data_1,
    output reg [7:0] read_data_2,
    
    // Dedicated hardwired outputs for Accumulator and 16-bit address pointer
    output wire [7:0] reg_A_out,
    output wire [15:0] reg_HL_out
);

    // Core 8x8-bit storage array
    reg [7:0] registers [0:7];

    // Hardwired bypass for frequently used registers
    assign reg_A_out = registers[7];                  // Accumulator is always index 7
    assign reg_HL_out = {registers[4], registers[5]}; // Concatenate H (4) and L (5)

    // --------------------------------------------------------
    // Asynchronous Read Logic
    // --------------------------------------------------------
    always @(*) begin
        // Outputs update instantly when select lines change
        read_data_1 = registers[read_sel_1];
        read_data_2 = registers[read_sel_2];
    end

    // --------------------------------------------------------
    // Synchronous Write & Reset Logic
    // --------------------------------------------------------
    integer i;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Asynchronous reset clears all registers to 0x00
            for (i = 0; i < 8; i = i + 1) begin
                registers[i] <= 8'h00;
            end
        end else begin
            
            // ------------------------------------------------
            // 8-Bit Operations
            // ------------------------------------------------
            if (write_en) begin
                registers[write_sel] <= write_data;
            end
            
            // ------------------------------------------------
            // 16-Bit Operations (Priority overwrites 8-bit)
            // ------------------------------------------------
            
            // LXI / POP / LHLD: Load full 16-bit pair
            if (reg_pair_write_en) begin
                case (reg_pair_sel)
                    2'b00: {registers[0], registers[1]} <= reg_pair_write_data; // B & C
                    2'b01: {registers[2], registers[3]} <= reg_pair_write_data; // D & E
                    2'b10: {registers[4], registers[5]} <= reg_pair_write_data; // H & L
                endcase
            end
            
            // INX: 16-bit Increment
            if (reg_pair_inc) begin
                case (reg_pair_sel)
                    2'b00: {registers[0], registers[1]} <= {registers[0], registers[1]} + 16'd1;
                    2'b01: {registers[2], registers[3]} <= {registers[2], registers[3]} + 16'd1;
                    2'b10: {registers[4], registers[5]} <= {registers[4], registers[5]} + 16'd1;
                endcase
            end
            
            // DCX: 16-bit Decrement
            if (reg_pair_dec) begin
                case (reg_pair_sel)
                    2'b00: {registers[0], registers[1]} <= {registers[0], registers[1]} - 16'd1;
                    2'b01: {registers[2], registers[3]} <= {registers[2], registers[3]} - 16'd1;
                    2'b10: {registers[4], registers[5]} <= {registers[4], registers[5]} - 16'd1;
                endcase
            end
            
            // DAD: 16-bit Double Addition (HL = HL + Pair)
            if (reg_pair_add) begin
                case (reg_pair_sel)
                    2'b00: {registers[4], registers[5]} <= {registers[4], registers[5]} + {registers[0], registers[1]};
                    2'b01: {registers[4], registers[5]} <= {registers[4], registers[5]} + {registers[2], registers[3]};
                    2'b10: {registers[4], registers[5]} <= {registers[4], registers[5]} + {registers[4], registers[5]};
                endcase
            end
            
        end
    end

endmodule