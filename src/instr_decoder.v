`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////// 
// Engineer: Soumajit Mandal (Roll: 2023ETB016)
// 
// Create Date: 09/18/2026
// Design Name: 8085_Control
// Module Name: instr_decoder
// Project Name: 8085
// Description: Full ISA explicit decoder mapping ALL 246 valid 8085 instructions
// 
//////////////////////////////////////////////////////////////////////////////////

module instr_decoder(
    input wire [7:0] ir,
    
    output reg [4:0] alu_op,
    output reg alu_a_mux_sel, 
    output reg [2:0] reg_read_sel_1, reg_read_sel_2, reg_write_sel,
    output reg reg_write_en, flags_write_en,
    output reg reg_pair_write_en, 
    output reg [1:0] reg_pair_sel,
    output reg reg_pair_inc, reg_pair_dec, reg_pair_add,
    output reg is_nop, is_mem_read, is_mem_write, is_io_op,
    output reg [1:0] addr_mux_sel, 
    output reg is_2_byte, is_3_byte,
    output reg imm_read_req, operand_mux_sel,   
    output reg pc_write_en, is_call, is_ret, is_rst, cond_check_en,
    output reg [2:0] jump_cond,
    output reg sp_write_en, sp_inc, sp_dec, halt_req, interrupt_en_ctrl, sim_req, rim_req
);
    localparam ALU_ADD = 5'h00, ALU_ADC = 5'h01, ALU_SUB = 5'h02, ALU_SBB = 5'h03;
    localparam ALU_AND = 5'h04, ALU_XRA = 5'h05, ALU_OR  = 5'h06, ALU_CMP = 5'h07;
    localparam ALU_INC = 5'h08, ALU_DEC = 5'h09, ALU_CMA = 5'h0A, ALU_STC = 5'h0B;
    localparam ALU_CMC = 5'h0C, ALU_DAA = 5'h0D, ALU_RLC = 5'h0E, ALU_RRC = 5'h0F;
    localparam ALU_RAL = 5'h10, ALU_RAR = 5'h11;

    always @(*) begin
        // Default all control signals to 0 to prevent latch inference
        alu_op = 5'b00000; alu_a_mux_sel = 0;
        reg_read_sel_1 = 3'b000; reg_read_sel_2 = 3'b000; reg_write_sel = 3'b000;
        reg_write_en = 0; flags_write_en = 0;
        reg_pair_write_en = 0; reg_pair_sel = 2'b00; 
        reg_pair_inc = 0; reg_pair_dec = 0; reg_pair_add = 0;
        is_nop = 0; is_mem_read = 0; is_mem_write = 0; is_io_op = 0;
        addr_mux_sel = 2'b00; is_2_byte = 0; is_3_byte = 0;
        imm_read_req = 0; operand_mux_sel = 0;
        pc_write_en = 0; is_call = 0; is_ret = 0; is_rst = 0; 
        cond_check_en = 0; jump_cond = 3'b000;
        sp_write_en = 0; sp_inc = 0; sp_dec = 0; 
        halt_req = 0; interrupt_en_ctrl = 0; sim_req = 0; rim_req = 0;

        case(ir)
            // ==========================================
            // 1. SYSTEM & MACHINE CONTROL (6 Instructions)
            // ==========================================
            8'h00: is_nop = 1;
            8'h76: halt_req = 1;
            8'hF3: interrupt_en_ctrl = 0; // DI
            8'hFB: interrupt_en_ctrl = 1; // EI
            8'h20: rim_req = 1;           // RIM
            8'h30: sim_req = 1;           // SIM
            
            // ==========================================
            // 2. 8-BIT DATA TRANSFER (87 Instructions)
            // ==========================================
            // MOV r1, r2 (63 Instructions - Excludes 0x76 HLT)
            8'h40, 8'h41, 8'h42, 8'h43, 8'h44, 8'h45, 8'h46, 8'h47,
            8'h48, 8'h49, 8'h4A, 8'h4B, 8'h4C, 8'h4D, 8'h4E, 8'h4F,
            8'h50, 8'h51, 8'h52, 8'h53, 8'h54, 8'h55, 8'h56, 8'h57,
            8'h58, 8'h59, 8'h5A, 8'h5B, 8'h5C, 8'h5D, 8'h5E, 8'h5F,
            8'h60, 8'h61, 8'h62, 8'h63, 8'h64, 8'h65, 8'h66, 8'h67,
            8'h68, 8'h69, 8'h6A, 8'h6B, 8'h6C, 8'h6D, 8'h6E, 8'h6F,
            8'h70, 8'h71, 8'h72, 8'h73, 8'h74, 8'h75,        8'h77, 
            8'h78, 8'h79, 8'h7A, 8'h7B, 8'h7C, 8'h7D, 8'h7E, 8'h7F: begin
                reg_read_sel_1 = ir[2:0]; reg_write_sel = ir[5:3];
                if (ir[2:0] == 3'b110) begin is_mem_read = 1; addr_mux_sel = 2'b01; end // Read from M (HL)
                if (ir[5:3] == 3'b110) begin is_mem_write = 1; addr_mux_sel = 2'b01; end // Write to M (HL)
                else reg_write_en = 1;
            end

            // MVI r, data (8 Instructions)
            8'h06, 8'h0E, 8'h16, 8'h1E, 8'h26, 8'h2E, 8'h36, 8'h3E: begin
                reg_write_sel = ir[5:3]; is_2_byte = 1; operand_mux_sel = 1;
                if (ir[5:3] == 3'b110) begin is_mem_write = 1; addr_mux_sel = 2'b01; end // MVI M, data
                else reg_write_en = 1;
            end

            // LDA / STA / LDAX / STAX (6 Instructions)
            8'h3A: begin is_3_byte = 1; is_mem_read = 1; addr_mux_sel = 2'b11; reg_write_sel = 3'b111; reg_write_en = 1; end // LDA
            8'h32: begin is_3_byte = 1; is_mem_write = 1; addr_mux_sel = 2'b11; reg_read_sel_1 = 3'b111; end // STA
            8'h0A, 8'h1A: begin is_mem_read = 1; addr_mux_sel = 2'b11; reg_pair_sel = {1'b0, ir[4]}; reg_write_sel = 3'b111; reg_write_en = 1; end // LDAX
            8'h02, 8'h12: begin is_mem_write = 1; addr_mux_sel = 2'b11; reg_pair_sel = {1'b0, ir[4]}; reg_read_sel_1 = 3'b111; end // STAX

            // ==========================================
            // 3. 8-BIT ARITHMETIC & LOGICAL (96 Instructions)
            // ==========================================
            // ADD/ADC/SUB/SBB/ANA/XRA/ORA/CMP (64 Instructions)
            8'h80, 8'h81, 8'h82, 8'h83, 8'h84, 8'h85, 8'h86, 8'h87,
            8'h88, 8'h89, 8'h8A, 8'h8B, 8'h8C, 8'h8D, 8'h8E, 8'h8F,
            8'h90, 8'h91, 8'h92, 8'h93, 8'h94, 8'h95, 8'h96, 8'h97,
            8'h98, 8'h99, 8'h9A, 8'h9B, 8'h9C, 8'h9D, 8'h9E, 8'h9F,
            8'hA0, 8'hA1, 8'hA2, 8'hA3, 8'hA4, 8'hA5, 8'hA6, 8'hA7,
            8'hA8, 8'hA9, 8'hAA, 8'hAB, 8'hAC, 8'hAD, 8'hAE, 8'hAF,
            8'hB0, 8'hB1, 8'hB2, 8'hB3, 8'hB4, 8'hB5, 8'hB6, 8'hB7,
            8'hB8, 8'hB9, 8'hBA, 8'hBB, 8'hBC, 8'hBD, 8'hBE, 8'hBF: begin
                alu_op = {2'b00, ir[5:3]}; reg_read_sel_1 = 3'b111; reg_read_sel_2 = ir[2:0]; flags_write_en = 1;
                if (ir[2:0] == 3'b110) begin is_mem_read = 1; addr_mux_sel = 2'b01; operand_mux_sel = 1; end
                if (ir[5:3] != 3'b111) begin reg_write_sel = 3'b111; reg_write_en = 1; end 
            end
            
            // ADI/ACI/SUI/SBI/ANI/XRI/ORI/CPI (8 Instructions)
            8'hC6, 8'hCE, 8'hD6, 8'hDE, 8'hE6, 8'hEE, 8'hF6, 8'hFE: begin
                alu_op = {2'b00, ir[5:3]}; reg_read_sel_1 = 3'b111; is_2_byte = 1; operand_mux_sel = 1; flags_write_en = 1;
                if (ir[5:3] != 3'b111) begin reg_write_sel = 3'b111; reg_write_en = 1; end 
            end

            // INR (8 Instructions)
            8'h04, 8'h0C, 8'h14, 8'h1C, 8'h24, 8'h2C, 8'h34, 8'h3C: begin
                alu_op = ALU_INC; reg_read_sel_2 = ir[5:3]; reg_write_sel = ir[5:3]; flags_write_en = 1;
                if (ir[5:3] == 3'b110) begin is_mem_read = 1; is_mem_write = 1; addr_mux_sel = 2'b01; end 
                else reg_write_en = 1;
            end
            
            // DCR (8 Instructions)
            8'h05, 8'h0D, 8'h15, 8'h1D, 8'h25, 8'h2D, 8'h35, 8'h3D: begin
                alu_op = ALU_DEC; reg_read_sel_2 = ir[5:3]; reg_write_sel = ir[5:3]; flags_write_en = 1;
                if (ir[5:3] == 3'b110) begin is_mem_read = 1; is_mem_write = 1; addr_mux_sel = 2'b01; end 
                else reg_write_en = 1;
            end

            // Accumulator Specials & Rotates (8 Instructions)
            8'h2F: begin alu_op = ALU_CMA; reg_read_sel_1 = 3'b111; reg_write_sel = 3'b111; reg_write_en = 1; end
            8'h37: begin alu_op = ALU_STC; flags_write_en = 1; end
            8'h3F: begin alu_op = ALU_CMC; flags_write_en = 1; end
            8'h27: begin alu_op = ALU_DAA; reg_read_sel_1 = 3'b111; reg_write_sel = 3'b111; reg_write_en = 1; flags_write_en = 1; end
            8'h07: begin alu_op = ALU_RLC; reg_read_sel_1 = 3'b111; reg_write_sel = 3'b111; reg_write_en = 1; flags_write_en = 1; end
            8'h0F: begin alu_op = ALU_RRC; reg_read_sel_1 = 3'b111; reg_write_sel = 3'b111; reg_write_en = 1; flags_write_en = 1; end
            8'h17: begin alu_op = ALU_RAL; reg_read_sel_1 = 3'b111; reg_write_sel = 3'b111; reg_write_en = 1; flags_write_en = 1; end
            8'h1F: begin alu_op = ALU_RAR; reg_read_sel_1 = 3'b111; reg_write_sel = 3'b111; reg_write_en = 1; flags_write_en = 1; end

            // ==========================================
            // 4. 16-BIT REGISTER INSTRUCTIONS (17 Instructions)
            // ==========================================
            8'h01, 8'h11, 8'h21, 8'h31: begin is_3_byte = 1; reg_pair_sel = ir[5:4]; reg_pair_write_en = 1; end // LXI
            8'h09, 8'h19, 8'h29, 8'h39: begin reg_pair_sel = ir[5:4]; reg_pair_add = 1; alu_a_mux_sel = 1; flags_write_en = 1; end // DAD
            8'h03, 8'h13, 8'h23, 8'h33: begin reg_pair_sel = ir[5:4]; reg_pair_inc = 1; end // INX
            8'h0B, 8'h1B, 8'h2B, 8'h3B: begin reg_pair_sel = ir[5:4]; reg_pair_dec = 1; end // DCX
            
            8'h2A: begin is_3_byte = 1; is_mem_read = 1; addr_mux_sel = 2'b11; reg_pair_sel = 2'b10; reg_pair_write_en = 1; end // LHLD
            8'h22: begin is_3_byte = 1; is_mem_write = 1; addr_mux_sel = 2'b11; reg_pair_sel = 2'b10; end // SHLD
            8'hEB: begin /* XCHG - Implementation handled directly inside reg_file */ end 
            8'hE3: begin is_mem_read = 1; is_mem_write = 1; addr_mux_sel = 2'b10; end // XTHL
            8'hF9: begin sp_write_en = 1; end // SPHL

            // ==========================================
            // 5. BRANCHING & STACK (38 Instructions)
            // ==========================================
            // Jumps (9 Instructions)
            8'hC3: begin is_3_byte = 1; pc_write_en = 1; end // JMP
            8'hC2, 8'hCA, 8'hD2, 8'hDA, 8'hE2, 8'hEA, 8'hF2, 8'hFA: begin 
                is_3_byte = 1; pc_write_en = 1; cond_check_en = 1; jump_cond = ir[5:3]; // Conditional Jumps
            end
            
            // Calls (9 Instructions)
            8'hCD: begin is_3_byte = 1; is_call = 1; sp_dec = 1; end // CALL
            8'hC4, 8'hCC, 8'hD4, 8'hDC, 8'hE4, 8'hEC, 8'hF4, 8'hFC: begin 
                is_3_byte = 1; is_call = 1; sp_dec = 1; cond_check_en = 1; jump_cond = ir[5:3]; // Conditional Calls
            end

            // Returns (9 Instructions)
            8'hC9: begin is_ret = 1; sp_inc = 1; end // RET
            8'hC0, 8'hC8, 8'hD0, 8'hD8, 8'hE0, 8'hE8, 8'hF0, 8'hF8: begin 
                is_ret = 1; sp_inc = 1; cond_check_en = 1; jump_cond = ir[5:3]; // Conditional Returns
            end

            8'hE9: begin pc_write_en = 1; end // PCHL

            // PUSH / POP (8 Instructions)
            8'hC5, 8'hD5, 8'hE5, 8'hF5: begin is_mem_write = 1; sp_dec = 1; addr_mux_sel = 2'b10; reg_pair_sel = ir[5:4]; end // PUSH
            8'hC1, 8'hD1, 8'hE1, 8'hF1: begin is_mem_read = 1; sp_inc = 1; addr_mux_sel = 2'b10; reg_pair_sel = ir[5:4]; reg_pair_write_en = 1; end // POP

            // Restarts (8 Instructions)
            8'hC7, 8'hCF, 8'hD7, 8'hDF, 8'hE7, 8'hEF, 8'hF7, 8'hFF: begin 
                is_rst = 1; is_call = 1; sp_dec = 1; jump_cond = ir[5:3]; // RST 0-7
            end

            // ==========================================
            // 6. I/O INSTRUCTIONS (2 Instructions)
            // ==========================================
            8'hDB: begin is_2_byte = 1; is_io_op = 1; is_mem_read = 1; reg_write_sel = 3'b111; reg_write_en = 1; end // IN
            8'hD3: begin is_2_byte = 1; is_io_op = 1; is_mem_write = 1; reg_read_sel_1 = 3'b111; end // OUT

            // ==========================================
            // INVALID OPCODES (Fallback to NOP)
            // ==========================================
            default: is_nop = 1; 
        endcase
    end
endmodule
