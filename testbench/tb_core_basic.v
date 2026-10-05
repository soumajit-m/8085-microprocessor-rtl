`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////// 
// Engineer: Soumajit Mandal (Roll: 2023ETB016)
// 
// Create Date: 09/19/2026
// Design Name: 8085_Core_Testbenches
// Module Name: tb_core_basic
// Project Name: 8085
// Description: Testbench 1 - 8-bit Math, Logic, and Data Movement
// 
// Additional Comments: Tests MVI, MOV, ADD, SUB, INR, DCR, ANA, and HLT
//////////////////////////////////////////////////////////////////////////////////

module tb_core_basic();
    reg clk, rst, intr;
    wire [15:8] a_high;
    wire [7:0] ad_bus;
    wire ale, io_m, s1, s0, rd_n, wr_n, inta;
    
    // ----------------------------------------------------
    // Address Latch Emulator (74LS373 Transparent Latch)
    // ----------------------------------------------------
    reg [7:0] addr_low_latch = 8'h00; // Initialize to 00 to clear simulator X states
    wire [15:0] full_addr = {a_high, addr_low_latch};
    
    always @(ale or ad_bus) begin
        if (ale) addr_low_latch = ad_bus;
    end
    
    
    // ----------------------------------------------------
    // Simulated 64KB Memory Array
    // ----------------------------------------------------
    reg [7:0] ram [0:65535];
    
    // Drive AD bus when processor is reading
    assign ad_bus = (~rd_n) ? ram[full_addr] : 8'hZZ;
    
    // Write to memory when processor is writing
    always @(posedge clk) begin
        if (~wr_n) ram[full_addr] <= ad_bus;
    end

    // ----------------------------------------------------
    // Core Instantiation
    // ----------------------------------------------------
    core_8085 uut (
        .clk(clk), .rst(rst), .intr(intr),
        .a_high(a_high), .ad_bus(ad_bus), .ale(ale),
        .io_m(io_m), .s1(s1), .s0(s0), .rd_n(rd_n), .wr_n(wr_n), .inta(inta)
    );

    // Clock Generation
    always #5 clk = ~clk;

    initial begin
        $dumpfile("tb_core_basic.vcd"); 
        $dumpvars(0, tb_core_basic);
        
        // ----------------------------------------------------
        // Assembly Program Pre-load
        // ----------------------------------------------------
        // 0000: 3E 05   MVI A, 05h
        // 0002: 06 03   MVI B, 03h
        // 0004: 80      ADD B      (A = 08h)
        // 0005: 90      SUB B      (A = 05h)
        // 0006: 3C      INR A      (A = 06h)
        // 0007: 05      DCR B      (B = 02h)
        // 0008: A0      ANA B      (A = 06h & 02h = 02h)
        // 0009: 76      HLT
        ram[16'h0000] = 8'h3E;
        ram[16'h0000] = 8'h3E; ram[16'h0001] = 8'h05;
        ram[16'h0002] = 8'h06; ram[16'h0003] = 8'h08;
        ram[16'h0004] = 8'h80;
        ram[16'h0005] = 8'h90;
        ram[16'h0006] = 8'h3C;
        ram[16'h0007] = 8'h05;
        ram[16'h0008] = 8'hA0;
        ram[16'h0009] = 8'h76;

        // Initialize and Reset
        clk = 0; rst = 1; intr = 0;
        #20 rst = 0;
        
        #600 $finish;
    end
    
    // ----------------------------------------------------
    // Internal State Monitor (Console Logging)
    // ----------------------------------------------------
    initial begin
        $monitor("Time: %0t ns | M-Cycle: %d, T-State: %d | PC: %h | IR: %h | Reg A: %h | Reg B: %h | ALU: %h | Flags (SZACP): %b", 
                 $time, 
                 uut.m_cycle,       // Tracks if it is Fetch (3), Mem Read (2), etc.
                 uut.t_state,       // Tracks the clock tick (1 through 5)
                 uut.pc_reg,        // Program Counter (Where are we in memory?)
                 uut.ir_reg,        // Instruction Register (What is the current opcode?)
                 uut.reg_A_out,     // Accumulator Value
                 uut.reg_inst.registers[0],// Drills directly into the reg_file module
                 uut.alu_result,    // Output of the ALU math
                 uut.latched_flags  // The 5 status flags: {S, Z, AC, P, CY}
        );
    end
endmodule
