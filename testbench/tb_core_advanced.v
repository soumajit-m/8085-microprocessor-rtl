`timescale 1ns / 1ps 
////////////////////////////////////////////////////////////////////////////////// 
// Engineer: Soumajit Mandal (Roll: 2023ETB016)
// Create Date: 08/16/2026
// Design Name: 8085_Core_Testbenches
// Module Name: tb_core_advanced
// Project Name: 8085
// Description: Testbench 5 - Validates SP pair ops, DAD SP, XCHG, PCHL, DAA, and PUSH/POP PSW
// 
// Revision:
// Revision 1.00 - 08/28/2026 - Drafted advanced instruction test plans
// Revision 2.00 - 10/03/2026 - Comprehensive verification for SP ops, DAD SP, XCHG, PCHL, DAA, PUSH/POP PSW
////////////////////////////////////////////////////////////////////////////////// 

module tb_core_advanced();
    reg clk, rst, intr;
    wire [15:8] a_high;
    wire [7:0] ad_bus;
    wire ale, io_m, s1, s0, rd_n, wr_n, inta;
    
    // Address Latch Emulator
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
        $dumpfile("tb_core_advanced.vcd"); 
        $dumpvars(0, tb_core_advanced);
        
        // ----------------------------------------------------
        // Assembly Program Pre-load
        // ----------------------------------------------------
        // 0000: 31 00 20   LXI SP, 2000h (Tests LXI SP)
        // 0003: 33         INX SP        (SP = 2001h)
        // 0004: 3B         DCX SP        (SP = 2000h)
        // 0005: 21 00 10   LXI H, 1000h
        // 0008: 39         DAD SP        (HL = 1000h + 2000h = 3000h)
        // 0009: 11 34 12   LXI D, 1234h  (DE = 1234h, HL = 3000h)
        // 000C: EB         XCHG          (DE = 3000h, HL = 1234h)
        // 000D: 3E 09      MVI A, 09h
        // 000F: C6 08      ADI 08h       (A = 11h, hex 9+8=17 -> 11h)
        // 0011: 27         DAA           (A = 17h BCD adjust)
        // 0012: F5         PUSH PSW      (Push A=17h, Flags to stack)
        // 0013: 3E 00      MVI A, 00h    (Clear A)
        // 0015: F1         POP PSW       (Restore A=17h and Flags from stack)
        // 0016: 21 30 00   LXI H, 0030h
        // 0019: E9         PCHL          (Jump to 0030h)
        // ...
        // 0030: 76         HLT           (Halt at target of PCHL)

        ram[16'h0000] = 8'h31; ram[16'h0001] = 8'h00; ram[16'h0002] = 8'h20;
        ram[16'h0003] = 8'h33;
        ram[16'h0004] = 8'h3B;
        ram[16'h0005] = 8'h21; ram[16'h0006] = 8'h00; ram[16'h0007] = 8'h10;
        ram[16'h0008] = 8'h39;
        ram[16'h0009] = 8'h11; ram[16'h000A] = 8'h34; ram[16'h000B] = 8'h12;
        ram[16'h000C] = 8'hEB;
        ram[16'h000D] = 8'h3E; ram[16'h000E] = 8'h09;
        ram[16'h000F] = 8'hC6; ram[16'h0010] = 8'h08;
        ram[16'h0011] = 8'h27;
        ram[16'h0012] = 8'hF5;
        ram[16'h0013] = 8'h3E; ram[16'h0014] = 8'h00;
        ram[16'h0015] = 8'hF1;
        ram[16'h0016] = 8'h21; ram[16'h0017] = 8'h30; ram[16'h0018] = 8'h00;
        ram[16'h0019] = 8'hE9;

        ram[16'h0030] = 8'h76;

        clk = 0; rst = 1; intr = 0;
        #15 rst = 0;
        
        #1200;
        $display("\n==================================================");
        $display("FINAL CPU STATE:");
        $display("  SP: %h (Expected 2000h)", uut.sp_out);
        $display("  DE: %h (Expected 3000h)", {uut.reg_inst.registers[2], uut.reg_inst.registers[3]});
        $display("  HL: %h (Expected 0030h)", uut.reg_HL_out);
        $display("  Accumulator (A): %h (Expected 17h from DAA/POP PSW)", uut.reg_A_out);
        $display("  IR: %h (Expected 76h at PC 0031h)", uut.ir_reg);
        
        if (uut.sp_out === 16'h2000 && 
            {uut.reg_inst.registers[2], uut.reg_inst.registers[3]} === 16'h3000 && 
            uut.reg_A_out === 8'h17 &&
            uut.ir_reg === 8'h76) begin
            $display("[TEST PASSED] tb_core_advanced: LXI/INX/DCX/DAD SP, XCHG, DAA, PUSH/POP PSW, PCHL verified!");
        end else begin
            $display("[TEST FAILED] tb_core_advanced: State mismatch!");
            $fatal;
        end
        $display("==================================================\n");
        $finish;
    end

endmodule
