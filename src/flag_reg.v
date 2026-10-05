`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////// 
// Engineer: Soumajit Mandal (Roll: 2023ETB016)
// 
// Create Date: 09/18/2026
// Design Name: 8085_Datapath
// Module Name: flag_reg
// Project Name: 8085
// Description: Stores and formats the Program Status Word
// 
//////////////////////////////////////////////////////////////////////////////////

module flag_reg(
    input wire clk,
    input wire rst,
    input wire flags_write_en,
    input wire [4:0] alu_flags_in, 
    output wire [7:0] psw_out,
    output wire carry_out,
    output wire [4:0] flags_out
);
    reg s_flag, z_flag, ac_flag, p_flag, cy_flag;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            s_flag <= 0; z_flag <= 0; ac_flag <= 0; p_flag <= 0; cy_flag <= 0;
        end else if (flags_write_en) begin
            s_flag  <= alu_flags_in[4];
            z_flag  <= alu_flags_in[3];
            ac_flag <= alu_flags_in[2];
            p_flag  <= alu_flags_in[1];
            cy_flag <= alu_flags_in[0];
        end
    end

    // 8085 PSW Specification: S | Z | 0 | AC | 0 | P | 1 | CY
    assign psw_out = {s_flag, z_flag, 1'b0, ac_flag, 1'b0, p_flag, 1'b1, cy_flag};
    assign carry_out = cy_flag;
    assign flags_out = {s_flag, z_flag, ac_flag, p_flag, cy_flag};
endmodule
