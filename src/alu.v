`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////// 
// Engineer: Soumajit Mandal (Roll: 2023ETB016)
// 
// Create Date: 09/18/2026 03:17:34 PM
// Design Name: 8085_Datapath
// Module Name: alu
// Project Name: 8085
// Description: Combinational ALU with 5-bit opcode and extended carry logic
// 
// Revision:
// Revision 1.00 - Added ADC/SBB, Expanded alu_op to 5-bit, Added Rotates
//////////////////////////////////////////////////////////////////////////////////

module alu(
    input wire [7:0] a,
    input wire [7:0] b,
    input wire [4:0] alu_op,
    input wire cin,
    output wire [7:0] result,
    output wire [4:0] flags_out 
);
    // ALU Operation Codes
    localparam ADD = 5'h00, ADC = 5'h01, SUB = 5'h02, SBB = 5'h03;
    localparam AND = 5'h04, XRA = 5'h05, OR  = 5'h06, CMP = 5'h07;
    localparam INC = 5'h08, DEC = 5'h09, CMA = 5'h0A, STC = 5'h0B;
    localparam CMC = 5'h0C, DAA = 5'h0D, RLC = 5'h0E, RRC = 5'h0F;
    localparam RAL = 5'h10, RAR = 5'h11;

    reg [8:0] temp_result;
    reg [4:0] temp_ac;
    reg flag_cy_internal;
    
    always @(*) begin
        temp_result = 9'b0; 
        temp_ac = 5'b0;
        flag_cy_internal = temp_result[8]; 
        
        case(alu_op)
            // Standard Math
            ADD: begin temp_result = a + b; temp_ac = {1'b0, a[3:0]} + {1'b0, b[3:0]}; end
            SUB, CMP: begin temp_result = a - b; temp_ac = {1'b0, a[3:0]} - {1'b0, b[3:0]}; end
            
            // Math with Carry/Borrow
            ADC: begin 
                temp_result = a + b + cin; 
                temp_ac = {1'b0, a[3:0]} + {1'b0, b[3:0]} + cin; 
            end
            SBB: begin 
                temp_result = a - b - cin; 
                temp_ac = {1'b0, a[3:0]} - {1'b0, b[3:0]} - cin; 
            end
            
            // Logical
            AND: temp_result = {1'b0, a & b};
            XRA: temp_result = {1'b0, a ^ b};
            OR:  temp_result = {1'b0, a | b};
            
            // Increments / Decrements
            INC: begin temp_result = b + 1; temp_ac = {1'b0, b[3:0]} + 5'b00001; end
            DEC: begin temp_result = b - 1; temp_ac = {1'b0, b[3:0]} - 5'b00001; end
            
            // Accumulator Specials
            CMA: temp_result = {1'b0, ~a};
            STC, CMC: temp_result = {1'b0, a};
            
            // Rotates
            RLC: temp_result = {1'b0, a[6:0], a[7]};
            RRC: temp_result = {1'b0, a[0], a[7:1]};
            RAL: temp_result = {1'b0, a[6:0], cin};
            RAR: temp_result = {1'b0, cin, a[7:1]};
            
            default: temp_result = {1'b0, a};
        endcase
        
        // Custom Carry Logic for operations that don't use standard math overflow
        if (alu_op == STC) flag_cy_internal = 1'b1;
        else if (alu_op == CMC) flag_cy_internal = ~cin;
        else if (alu_op == RLC || alu_op == RAL) flag_cy_internal = a[7];
        else if (alu_op == RRC || alu_op == RAR) flag_cy_internal = a[0];
        else if (alu_op == INC || alu_op == DEC || alu_op == CMA) flag_cy_internal = cin;
        else if (alu_op == AND || alu_op == OR || alu_op == XRA) flag_cy_internal = 1'b0;
        else flag_cy_internal = temp_result[8];
    end

    assign result = temp_result[7:0];

    // Flag Generation
    wire flag_s  = result[7];          
    wire flag_z  = (result == 8'h00);  
    wire flag_ac = temp_ac[4];         
    wire flag_p  = ~^result;           

    assign flags_out = {flag_s, flag_z, flag_ac, flag_p, flag_cy_internal};
endmodule
