`timescale 1ns / 1ps 
////////////////////////////////////////////////////////////////////////////////// 
// Engineer: Soumajit Mandal (Roll: 2023ETB016)
// 
// Create Date: 09/19/2026
// Design Name: 8085_Core_Testbenches
// Module Name: tb_core_stack_branch
// Project Name: 8085
// Description: Testbench 3 - Stacks, Subroutines, and Conditional Branching
// 
//////////////////////////////////////////////////////////////////////////////////

module tb_core_stack_branch();
    reg clk, rst, intr;
    wire [15:8] a_high;
    wire [7:0] ad_bus;
    wire ale, io_m, s1, s0, rd_n, wr_n, inta;
    
    // ----------------------------------------------------
    // Address Latch Emulator (74LS373 Transparent Latch)
    // ----------------------------------------------------
    reg [7:0] addr_low_latch = 8'h00; 
    wire [15:0] full_addr = {a_high, addr_low_latch};
    
    always @(ale or ad_bus) begin
        if (ale) addr_low_latch = ad_bus;
    end
    
    // Simulated Memory
    reg [7:0] ram [0:65535];
    assign ad_bus = (~rd_n) ? ram[full_addr] : 8'hZZ;
    always @(posedge clk) if (~wr_n) ram[full_addr] <= ad_bus;

    // Core Instantiation
    core_8085 uut (
        .clk(clk), .rst(rst), .intr(intr),
        .a_high(a_high), .ad_bus(ad_bus), .ale(ale),
        .io_m(io_m), .s1(s1), .s0(s0), .rd_n(rd_n), .wr_n(wr_n), .inta(inta)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("tb_core_stack_branch.vcd"); 
        $dumpvars(0, tb_core_stack_branch);
        
        // ----------------------------------------------------
        // Assembly Program Pre-load
        // ----------------------------------------------------
        // MAIN:
        // 0000: 31 FF FF   LXI SP, FFFFh
        // 0003: 3E 02      MVI A, 02h
        // 0005: 3D         DCR A          <- LOOP START (Target for JNZ)
        // 0006: C2 05 00   JNZ 0005h      (Loops back to 0005h while A != 0)
        // 0009: CD 20 00   CALL 0020h     (Executes subroutine once loop finishes)
        // 000C: 76         HLT
        //
        // SUBROUTINE (0020h):
        // 0020: C5         PUSH B
        // 0021: C1         POP B
        // 0022: C9         RET
        
        ram[16'h0000] = 8'h31; ram[16'h0001] = 8'hFF; ram[16'h0002] = 8'hFF;
        ram[16'h0003] = 8'h3E; ram[16'h0004] = 8'h02;
        ram[16'h0005] = 8'h3D; 
        ram[16'h0006] = 8'hC2; ram[16'h0007] = 8'h05; ram[16'h0008] = 8'h00; // Fixed jump target to 0005h
        ram[16'h0009] = 8'hCD; ram[16'h000A] = 8'h20; ram[16'h000B] = 8'h00;
        ram[16'h000C] = 8'h76;
        
        ram[16'h0020] = 8'hC5;
        ram[16'h0021] = 8'hC1;
        ram[16'h0022] = 8'hC9;

        clk = 0; rst = 1; intr = 0;
        #15 rst = 0;
        
        #1500 $finish;
    end
    
    // ----------------------------------------------------
    // Internal State Monitor (Console Logging)
    // ----------------------------------------------------
    initial begin
        $monitor("Time: %0t ns | M-Cycle: %d, T-State: %d | PC: %h | IR: %h | Reg A: %h | Reg B: %h  Reg SP: %h | ALU: %h | Flags (SZACP): %b", 
                 $time, 
                 uut.m_cycle,       
                 uut.t_state,       
                 uut.pc_reg,        
                 uut.ir_reg,        
                 uut.reg_A_out,     
                 uut.reg_inst.registers[0],
                 uut.sp_out,        
                 uut.alu_result,    
                 uut.latched_flags  
        );
    end
    
endmodule