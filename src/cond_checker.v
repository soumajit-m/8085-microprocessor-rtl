`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////// 
// Engineer: Soumajit Mandal (Roll: 2023ETB016)
// 
// Create Date: 09/18/2026
// Design Name: 8085_Control
// Module Name: cond_checker
// Project Name: 8085
// Description: Evaluates latched flags to trigger conditional branches
// 
//////////////////////////////////////////////////////////////////////////////////

module cond_checker(
    input wire cond_check_en,     // 1 if conditional instruction, 0 if unconditional
    input wire [2:0] jump_cond,   // 3-bit condition code from IR[5:3]
    input wire [4:0] flags,       // Latched flags: {S, Z, AC, P, CY}
    output reg take_branch        // 1: Execute branch, 0: Abort and fetch next
);
    wire s_flag  = flags[4];
    wire z_flag  = flags[3];
    wire p_flag  = flags[1];
    wire cy_flag = flags[0];

    always @(*) begin
        if (!cond_check_en) begin
            take_branch = 1'b1; // Always branch for JMP, CALL, RET
        end else begin
            case (jump_cond)
                3'b000: take_branch = ~z_flag;  // JNZ / CNZ / RNZ
                3'b001: take_branch = z_flag;   // JZ  / CZ  / RZ
                3'b010: take_branch = ~cy_flag; // JNC / CNC / RNC
                3'b011: take_branch = cy_flag;  // JC  / CC  / RC
                3'b100: take_branch = ~p_flag;  // JPO / CPO / RPO
                3'b101: take_branch = p_flag;   // JPE / CPE / RPE
                3'b110: take_branch = ~s_flag;  // JP  / CP  / RP
                3'b111: take_branch = s_flag;   // JM  / CM  / RM
                default: take_branch = 1'b0;
            endcase
        end
    end
endmodule
