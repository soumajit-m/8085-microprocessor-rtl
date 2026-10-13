`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////// 
// Engineer: Soumajit Mandal (Roll: 2023ETB016)
// 
// Create Date: 08/14/2026 03:17:34 PM
// Design Name: 8085_Datapath
// Module Name: alu
// Project Name: 8085
// Description: Combinational ALU with 5-bit opcode and extended carry logic
// 
// Revision:
// Revision 1.00 - 08/27/2026 - Added ADC/SBB, Expanded alu_op to 5-bit, Added Rotates
// Revision 2.00 - 10/02/2026 - Added ac_in, DAA BCD correction logic, and 8085 ANA flag compliance
//////////////////////////////////////////////////////////////////////////////////

module alu(
    input wire [7:0] a,
    input wire [7:0] b,
    input wire [4:0] alu_op,
    input wire cin,
    input wire ac_in,
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
    
    reg [8:0] daa_val;
    reg daa_cy_flag;
    reg daa_ac_flag;

    always @(*) begin
        temp_result = 9'b0; 
        temp_ac = 5'b0;
        flag_cy_internal = temp_result[8]; 
        daa_val = 9'b0;
        daa_cy_flag = cin;
        daa_ac_flag = 1'b0;
        
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
            
            // Logical (8085 specification: AND sets AC to 1, OR/XRA reset AC to 0)
            AND: begin temp_result = {1'b0, a & b}; temp_ac = 5'b10000; end
            XRA: temp_result = {1'b0, a ^ b};
            OR:  temp_result = {1'b0, a | b};
            
            // Increments / Decrements
            INC: begin temp_result = b + 1; temp_ac = {1'b0, b[3:0]} + 5'b00001; end
            DEC: begin temp_result = b - 1; temp_ac = {1'b0, b[3:0]} - 5'b00001; end
            
            // Accumulator Specials
            CMA: temp_result = {1'b0, ~a};
            STC, CMC: temp_result = {1'b0, a};
            
            // Decimal Adjust Accumulator (DAA)
            DAA: begin
                daa_val = {1'b0, a};
                daa_cy_flag = cin;
                daa_ac_flag = 1'b0;
                if ((a[3:0] > 4'd9) || ac_in) begin
                    daa_val = daa_val + 9'd6;
                    daa_ac_flag = 1'b1;
                end
                if ((daa_val[7:4] > 4'd9) || cin || daa_val[8]) begin
                    daa_val = daa_val + 9'd96; // 0x60
                    daa_cy_flag = 1'b1;
                end
                temp_result = daa_val;
                temp_ac = {daa_ac_flag, 4'b0};
            end

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
        else if (alu_op == DAA) flag_cy_internal = daa_cy_flag;
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
