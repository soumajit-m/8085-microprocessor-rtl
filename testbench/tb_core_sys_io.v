`timescale 1ns / 1ps 
////////////////////////////////////////////////////////////////////////////////// 
// Engineer: Soumajit Mandal (Roll: 2023ETB016)
// 
// Create Date: 09/19/2026
// Design Name: 8085_Core_Testbenches
// Module Name: tb_core_sys_io
// Project Name: 8085
// Description: Testbench 4 - Accumulator Specials, Flags, and I/O with Monitor
// 
//////////////////////////////////////////////////////////////////////////////////

module tb_core_sys_io();
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
    
    // Simulated Memory and I/O devices
    reg [7:0] ram [0:65535];
    
    // Simulate IO Device at Port 0x02 returning 0xBB
    wire is_io_read = (io_m == 1 && ~rd_n);
    assign ad_bus = is_io_read ? 8'hBB : (~rd_n && ~io_m) ? ram[full_addr] : 8'hZZ;
    
    always @(posedge clk) begin 
        if (~wr_n && ~io_m) ram[full_addr] <= ad_bus;
    end

    // Core Instantiation
    core_8085 uut (
        .clk(clk), .rst(rst), .intr(intr),
        .a_high(a_high), .ad_bus(ad_bus), .ale(ale),
        .io_m(io_m), .s1(s1), .s0(s0), .rd_n(rd_n), .wr_n(wr_n), .inta(inta)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("tb_core_sys_io.vcd"); 
        $dumpvars(0, tb_core_sys_io);
        
        // ----------------------------------------------------
        // Assembly Program Pre-load
        // ----------------------------------------------------
        // 0000: 37      STC        (Set Carry)
        // 0001: 3F      CMC        (Complement Carry)
        // 0002: 3E AA   MVI A, AAh 
        // 0004: 2F      CMA        (A = 55h)
        // 0005: 07      RLC        (Rotate Left -> A = AAh)
        // 0006: D3 01   OUT 01h    (Writes AAh to IO Port 1)
        // 0008: DB 02   IN 02h     (Reads BBh from IO Port 2 into A)
        // 000A: 76      HLT
        
        ram[16'h0000] = 8'h37;
        ram[16'h0001] = 8'h3F;
        ram[16'h0002] = 8'h3E; ram[16'h0003] = 8'hAA;
        ram[16'h0004] = 8'h2F;
        ram[16'h0005] = 8'h07;
        ram[16'h0006] = 8'hD3; ram[16'h0007] = 8'h01;
        ram[16'h0008] = 8'hDB; ram[16'h0009] = 8'h02;
        ram[16'h000A] = 8'h76;

        clk = 0; rst = 1; intr = 0;
        #15 rst = 0;
        
        #600 $finish;
    end

    // ----------------------------------------------------
    // Internal State Monitor (Console Logging)
    // ----------------------------------------------------
    initial begin
        $monitor("Time: %0t ns | M-Cycle: %d, T-State: %d | PC: %h | IR: %h | IO/M: %b | AD Bus: %h | Reg A: %h | Flags (SZACP): %b", 
                 $time, 
                 uut.m_cycle,       
                 uut.t_state,       
                 uut.pc_reg,        
                 uut.ir_reg,        
                 io_m,              // High during I/O operations, Low during Memory
                 ad_bus,            // Tracks data/address movement on shared bus
                 uut.reg_A_out,     // Accumulator value
                 uut.latched_flags  // Status flags {S, Z, AC, P, CY}
        );
    end

endmodule
