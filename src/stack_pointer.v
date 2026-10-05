`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////// 
// Engineer: Soumajit Mandal (Roll: 2023ETB016)
// 
// Create Date: 09/18/2026
// Design Name: 8085_Datapath
// Module Name: stack_pointer
// Project Name: 8085
// Description: Dedicated 16-bit UP/DOWN counter for SP tracking
// 
//////////////////////////////////////////////////////////////////////////////////

module stack_pointer(
    input wire clk,
    input wire rst,
    input wire sp_write_en,
    input wire sp_inc,
    input wire sp_dec,
    input wire [15:0] sp_data_in,
    output reg [15:0] sp_out
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sp_out <= 16'hFFFF; // SP initializes to top of memory
        end else begin
            if (sp_write_en) begin
                sp_out <= sp_data_in;
            end else if (sp_inc) begin
                sp_out <= sp_out + 16'd1;
            end else if (sp_dec) begin
                sp_out <= sp_out - 16'd1;
            end
        end
    end
endmodule