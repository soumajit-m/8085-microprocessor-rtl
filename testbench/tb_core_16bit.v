`timescale 1ns / 1ps 
////////////////////////////////////////////////////////////////////////////////// 
// Engineer: Soumajit Mandal (Roll: 2023ETB016)
// 
// Create Date: 09/19/2026
// Design Name: 8085_Core_Testbenches
// Module Name: tb_core_16bit
// Project Name: 8085
// Description: Testbench 2 - 16-bit Math, Pointers, and Memory Operations
// 
// Additional Comments: Tests LXI, DAD, INX, and SHLD
//////////////////////////////////////////////////////////////////////////////////

module tb_core_16bit();
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
        $dumpfile("tb_core_16bit.vcd"); 
        $dumpvars(0, tb_core_16bit);
        
        // ----------------------------------------------------
        // Assembly Program Pre-load (Little Endian format)
        // ----------------------------------------------------
        // 0000: 01 34 12   LXI B, 1234h 
        // 0003: 21 00 20   LXI H, 2000h
        // 0006: 09         DAD B        (HL = 3234h)
        // 0007: 23         INX H        (HL = 3235h)
        // 0008: 22 00 40   SHLD 4000h   (Stores 35h at 4000h, 32h at 4001h)
        // 000B: 76         HLT
        
        ram[16'h0000] = 8'h01; ram[16'h0001] = 8'h34; ram[16'h0002] = 8'h12;
        ram[16'h0003] = 8'h21; ram[16'h0004] = 8'h00; ram[16'h0005] = 8'h20;
        ram[16'h0006] = 8'h09;
        ram[16'h0007] = 8'h23;
        ram[16'h0008] = 8'h22; ram[16'h0009] = 8'h00; ram[16'h000A] = 8'h40;
        ram[16'h000B] = 8'h76;

        clk = 0; rst = 1; intr = 0;
        #15 rst = 0;
        
        #700;
        
        $display("\n==================================================");
        $display("PROGRAM COMPLETE - MEMORY DUMP");
        $display("Address 4000h (Expected L = 35h): %h", ram[16'h4000]);
        $display("Address 4001h (Expected H = 32h): %h", ram[16'h4001]);
        $display("==================================================\n");
        $finish;
    end
    
    // ----------------------------------------------------
    // Internal State Monitor (Console Logging)
    // ----------------------------------------------------
    initial begin
        $monitor("Time: %0t ns | M-Cycle: %d, T-State: %d | PC: %h | IR: %h | Reg B: %h | Reg C: %h  Reg H: %h  Reg L: %h | ALU: %h | Flags (SZACP): %b", 
                 $time, 
                 uut.m_cycle,       // Tracks if it is Fetch (3), Mem Read (2), etc.
                 uut.t_state,       // Tracks the clock tick (1 through 5)
                 uut.pc_reg,        // Program Counter (Where are we in memory?)
                 uut.ir_reg,        // Instruction Register (What is the current opcode?)
                 uut.reg_inst.registers[0],// B register
                 uut.reg_inst.registers[1],// C register
                 uut.reg_inst.registers[4],// H register
                 uut.reg_inst.registers[5],// L register
                 uut.alu_result,    // Output of the ALU math
                 uut.latched_flags  // The 5 status flags: {S, Z, AC, P, CY}
        );
    end
    
endmodule
