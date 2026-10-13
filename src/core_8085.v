`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////// 
// Engineer: Soumajit Mandal (Roll: 2023ETB016)
// 
// Create Date: 08/14/2026
// Design Name: 8085_Core
// Module Name: core_8085
// Project Name: 8085
// Description: Top-level integration with native AD bus multiplexing
// 
// Revision:
// Revision 1.00 - 08/27/2026 - Cleaned up little-endian W/Z operand loading via FSM strobes
// Revision 2.00 - 10/02/2026 - Fixed conditional branch skip, CALL/RET, PUSH/POP, SP, DAD Carry, DAA, XCHG
////////////////////////////////////////////////////////////////////////////////// 

module core_8085(
    input wire clk, 
    input wire rst, 
    input wire intr,
    
    // Authentic Hardware Pins (Multiplexed)
    output wire [15:8] a_high,     // Upper Address Bus (A8 - A15)
    inout wire [7:0] ad_bus,       // Multiplexed Address/Data Bus (AD0 - AD7)
    output wire ale,               // Address Latch Enable
    
    output wire io_m, 
    output wire s1, 
    output wire s0, 
    output wire rd_n, 
    output wire wr_n, 
    output wire inta               
);

    // --------------------------------------------------------
    // Internal Registers 
    // --------------------------------------------------------
    reg [7:0] ir_reg, w_reg, z_reg;
    reg [15:0] pc_reg;
    wire [15:0] wz_pair = {w_reg, z_reg};

    // --------------------------------------------------------
    // Control and Status Wires
    // --------------------------------------------------------
    wire [4:0] alu_op;
    wire alu_a_mux_sel, is_2_byte, is_3_byte, cond_check_en, take_branch;
    wire [2:0] reg_read_sel_1, reg_read_sel_2, reg_write_sel, jump_cond;
    wire reg_write_en, flags_write_en, is_nop, is_mem_read, is_mem_write;
    wire is_io_op, imm_read_req, operand_mux_sel, pc_write_en, halt_req;
    wire is_call, is_ret, is_rst, is_push, is_pop, is_xchg, is_pchl, is_sphl;
    wire z_write_en, w_write_en;
    wire [1:0] addr_mux_sel;
    wire [2:0] m_cycle, t_state;
    wire [1:0] fetch_stage, exec_stage;
    wire sp_push_strobe, sp_pop_strobe;
    
    // Multi-Cycle Datapath Flags
    wire inc_wz_addr, high_byte_sel, fetch_addr_override;
    
    // 16-bit Control Wires
    wire reg_pair_write_en, reg_pair_inc, reg_pair_dec, reg_pair_add;
    wire [1:0] reg_pair_sel;
    wire dad_carry;
    
    // --------------------------------------------------------
    // Datapath Buses
    // --------------------------------------------------------
    wire [15:0] raw_mux_addr;    // Address coming directly out of the addr_mux
    wire [15:0] internal_addr;   // Final 16-bit address after multi-cycle overrides
    wire [7:0] internal_data_in; // Data read from the AD bus
    wire [7:0] internal_data_out;// Data ready to be written to AD bus
    
    wire [7:0] reg_read_data_1, reg_read_data_2, alu_result, reg_A_out;
    wire [15:0] reg_HL_out, sp_out;
    wire [4:0] alu_flags_raw, latched_flags;
    wire flag_carry_out;
    wire [7:0] psw_out;
    
    // Internal Mux Routing
    wire [7:0] alu_operand_a = (alu_a_mux_sel) ? reg_read_data_1 : reg_A_out;
    wire [7:0] alu_operand_b = (operand_mux_sel) ? internal_data_in : reg_read_data_2;
    
    // --------------------------------------------------------
    // Multi-Cycle Execution Override Logic
    // --------------------------------------------------------
    wire [15:0] exec_target_addr = (inc_wz_addr) ? raw_mux_addr + 1 : raw_mux_addr;
    wire is_stack_op = (is_push || is_pop || (is_call && take_branch) || (is_ret && take_branch)) && (exec_stage != 0);
    wire is_io_active = is_io_op && (m_cycle == 3'b101 || m_cycle == 3'b110);
    wire [15:0] stack_addr = (is_push || is_call) ? sp_out - 16'd1 : sp_out;
    
    assign internal_addr = (fetch_addr_override) ? pc_reg : 
                           (is_stack_op)         ? stack_addr :
                           (is_io_active)        ? {z_reg, z_reg} : 
                                                   exec_target_addr;
    
    // --------------------------------------------------------
    // Data Out Multiplexing (for Memory / Stack / IO Writes)
    // --------------------------------------------------------
    wire [7:0] shld_write_data = (high_byte_sel) ? reg_HL_out[15:8] : reg_HL_out[7:0];
    wire [7:0] call_write_data = (exec_stage == 1) ? pc_reg[15:8] : pc_reg[7:0];
    
    // PUSH register pair high/low byte selection
    reg [7:0] push_write_data;
    always @(*) begin
        if (exec_stage == 1) begin
            case (reg_pair_sel)
                2'b00: push_write_data = reg_inst.registers[0]; // B
                2'b01: push_write_data = reg_inst.registers[2]; // D
                2'b10: push_write_data = reg_inst.registers[4]; // H
                2'b11: push_write_data = reg_A_out;            // A (PSW)
            endcase
        end else begin
            case (reg_pair_sel)
                2'b00: push_write_data = reg_inst.registers[1]; // C
                2'b01: push_write_data = reg_inst.registers[3]; // E
                2'b10: push_write_data = reg_inst.registers[5]; // L
                2'b11: push_write_data = psw_out;               // Flags (PSW)
            endcase
        end
    end
    
    assign internal_data_out = (is_call)        ? call_write_data :
                               (is_push)        ? push_write_data :
                               (ir_reg == 8'h22)? shld_write_data : 
                                                  reg_read_data_1;

    // --------------------------------------------------------
    // Bus Multiplexing Logic (Authentic 8085 hardware behavior)
    // --------------------------------------------------------
    assign a_high = internal_addr[15:8];
    assign ale = (t_state == 3'd1) ? 1'b1 : 1'b0;
    
    assign ad_bus = (ale)   ? internal_addr[7:0] :
                    (~wr_n) ? internal_data_out : 
                              8'hZZ;
                              
    assign internal_data_in = ad_bus;
    
    assign rd_n = ~((m_cycle == 3'b010 || m_cycle == 3'b011 || m_cycle == 3'b110) && (t_state == 2 || t_state == 3));
    assign wr_n = ~((m_cycle == 3'b001 || m_cycle == 3'b101) && (t_state == 2 || t_state == 3));

    // --------------------------------------------------------
    // Internal FSM Sequencing & Gated Branch Execution
    // --------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc_reg <= 0; ir_reg <= 0; w_reg <= 0; z_reg <= 0;
        end else begin
            // Instruction register latching during fetch
            if (m_cycle == 3'b011 && t_state == 3) begin
                ir_reg <= internal_data_in; 
                pc_reg <= pc_reg + 1;
            end
            
            // Increment PC for 2-byte and 3-byte instruction operands (fetch_stage 1 and 2)
            if (m_cycle == 3'b010 && t_state == 3 && (fetch_stage != 0)) 
                pc_reg <= pc_reg + 1;
                
            // W and Z operand latching
            if (z_write_en) z_reg <= internal_data_in; // Low byte -> Z
            if (w_write_en) w_reg <= internal_data_in; // High byte -> W
            
            // GATED JUMP EXECUTION: Only update PC to WZ target when the 
            // 3-byte instruction read cycle has completely finished at T3.
            if (pc_write_en && !is_pchl && take_branch && (m_cycle == 3'b010) && (t_state == 3) && (w_write_en)) begin
                pc_reg <= {internal_data_in, z_reg};
            end
            
            // PCHL: Jump directly to HL
            if (is_pchl && m_cycle == 3'b011 && t_state == 4) begin
                pc_reg <= reg_HL_out;
            end

            // RET / CALL Program Counter Updates:
            if (is_ret && exec_stage == 1 && m_cycle == 3'b010 && t_state == 3) begin
                z_reg <= internal_data_in; // Low byte of return address
            end
            if (is_ret && exec_stage == 2 && m_cycle == 3'b010 && t_state == 3) begin
                pc_reg <= {internal_data_in, z_reg}; // High byte & return jump
            end
            if (is_call && take_branch && exec_stage == 2 && m_cycle == 3'b001 && t_state == 3) begin
                pc_reg <= wz_pair; // Subroutine jump
            end
        end
    end
    
    // --------------------------------------------------------
    // POP / LHLD / Normal Register Write Routing
    // --------------------------------------------------------
    wire pop_write_en = (is_pop && m_cycle == 3'b010 && t_state == 3'd3 && (exec_stage == 1 || exec_stage == 2));
    wire pop_psw_en = (is_pop && reg_pair_sel == 2'b11 && exec_stage == 1 && m_cycle == 3'b010 && t_state == 3'd3);
    
    reg [2:0] pop_reg_sel;
    always @(*) begin
        if (exec_stage == 1) begin
            case (reg_pair_sel)
                2'b00: pop_reg_sel = 3'd1; // C
                2'b01: pop_reg_sel = 3'd3; // E
                2'b10: pop_reg_sel = 3'd5; // L
                default: pop_reg_sel = 3'd7;
            endcase
        end else begin
            case (reg_pair_sel)
                2'b00: pop_reg_sel = 3'd0; // B
                2'b01: pop_reg_sel = 3'd2; // D
                2'b10: pop_reg_sel = 3'd4; // H
                2'b11: pop_reg_sel = 3'd7; // A
            endcase
        end
    end

    wire lhld_write_en = (ir_reg == 8'h2A && m_cycle == 3'b010 && t_state == 3'd3 && (exec_stage == 1 || exec_stage == 2));
    wire [2:0] lhld_reg_sel = (exec_stage == 1) ? 3'd5 : 3'd4; // 1: L, 2: H

    wire exec_strobe = (m_cycle == 3'b011 && t_state == 3'd4 && !is_2_byte && !is_3_byte && !is_mem_read && !is_mem_write) || 
                       (is_io_op && is_mem_read && m_cycle == 3'b110 && t_state == 3'd3) ||
                       (!is_io_op && is_2_byte && m_cycle == 3'b010 && t_state == 3'd3 && fetch_stage == 1) ||
                       (!is_io_op && is_mem_read && !is_2_byte && !is_3_byte && m_cycle == 3'b010 && t_state == 3'd3) ||
                       (ir_reg == 8'h3A && m_cycle == 3'b010 && t_state == 3'd3 && exec_stage == 1); // LDA
                       
    wire normal_reg_write_en = reg_write_en & exec_strobe;
    wire safe_flags_write_en = flags_write_en & (m_cycle == 3'b011 && t_state == 3'd4 || (is_2_byte && m_cycle == 3'b010 && t_state == 3'd3));
    
    wire effective_reg_write_en = normal_reg_write_en | lhld_write_en | (pop_write_en && !pop_psw_en);
    wire [2:0] effective_reg_write_sel = (lhld_write_en) ? lhld_reg_sel :
                                         (pop_write_en)  ? pop_reg_sel : 
                                                           reg_write_sel;
    wire is_mvi = (ir_reg[7:6] == 2'b00 && ir_reg[2:0] == 3'b110);
    wire write_from_bus = (is_mem_read || is_mvi || lhld_write_en || pop_write_en || is_io_op);
    wire [7:0] effective_reg_write_data = (write_from_bus) ? internal_data_in : alu_result;

    // 16-bit register pair write / modify strobes:
    wire safe_reg_pair_write_en = (reg_pair_write_en && reg_pair_sel != 2'b11 && m_cycle == 3'b011 && t_state == 3'd1);
    wire safe_reg_pair_inc = (reg_pair_inc && reg_pair_sel != 2'b11 && m_cycle == 3'b011 && t_state == 3'd4);
    wire safe_reg_pair_dec = (reg_pair_dec && reg_pair_sel != 2'b11 && m_cycle == 3'b011 && t_state == 3'd4);
    wire safe_reg_pair_add = (reg_pair_add && m_cycle == 3'b011 && t_state == 3'd4);
    wire safe_xchg_en      = (is_xchg && m_cycle == 3'b011 && t_state == 3'd4);

    // Stack pointer dedicated controls:
    wire [15:0] sp_target_data = (is_sphl) ? reg_HL_out : wz_pair;
    wire sp_write_strobe = (is_sphl && m_cycle == 3'b011 && t_state == 3'd4) || 
                           (ir_reg == 8'h31 && m_cycle == 3'b011 && t_state == 3'd1);
    wire sp_inc_total = sp_pop_strobe || (reg_pair_inc && reg_pair_sel == 2'b11 && m_cycle == 3'b011 && t_state == 3'd4);
    wire sp_dec_total = sp_push_strobe || (reg_pair_dec && reg_pair_sel == 2'b11 && m_cycle == 3'b011 && t_state == 3'd4);

    // --------------------------------------------------------
    // Instance Wiring
    // --------------------------------------------------------
    cond_checker cond_inst (
        .cond_check_en(cond_check_en), .jump_cond(jump_cond), 
        .flags(latched_flags), .take_branch(take_branch)
    );

    stack_pointer sp_inst (
        .clk(clk), .rst(rst),
        .sp_write_en(sp_write_strobe), .sp_inc(sp_inc_total), .sp_dec(sp_dec_total),
        .sp_data_in(sp_target_data), .sp_out(sp_out)
    );

    instr_decoder decoder_inst (
        .ir(ir_reg), 
        .alu_op(alu_op), .alu_a_mux_sel(alu_a_mux_sel), 
        .reg_read_sel_1(reg_read_sel_1), .reg_read_sel_2(reg_read_sel_2), 
        .reg_write_sel(reg_write_sel), .reg_write_en(reg_write_en), 
        .flags_write_en(flags_write_en), 
        
        .reg_pair_write_en(reg_pair_write_en),
        .reg_pair_sel(reg_pair_sel),
        .reg_pair_inc(reg_pair_inc),
        .reg_pair_dec(reg_pair_dec),
        .reg_pair_add(reg_pair_add),

        .is_nop(is_nop), .is_mem_read(is_mem_read), .is_mem_write(is_mem_write), 
        .is_io_op(is_io_op), .addr_mux_sel(addr_mux_sel), 
        .is_2_byte(is_2_byte), .is_3_byte(is_3_byte), 
        .imm_read_req(imm_read_req), .operand_mux_sel(operand_mux_sel), 
        .pc_write_en(pc_write_en), 
        .is_call(is_call), .is_ret(is_ret), .is_rst(is_rst),
        .is_push(is_push), .is_pop(is_pop), .is_xchg(is_xchg), 
        .is_pchl(is_pchl), .is_sphl(is_sphl),
        .cond_check_en(cond_check_en), .jump_cond(jump_cond), 
        .sp_write_en(sp_write_en), .sp_inc(sp_inc), .sp_dec(sp_dec),
        .halt_req(halt_req), .interrupt_en_ctrl(interrupt_en_ctrl),
        .sim_req(sim_req), .rim_req(rim_req)
    );

    control_fsm fsm_inst (
        .clk(clk), .rst(rst), .is_nop(is_nop), 
        .is_mem_read(is_mem_read), .is_mem_write(is_mem_write), 
        .is_io_op(is_io_op), .is_2_byte(is_2_byte), .is_3_byte(is_3_byte), 
        .cond_check_en(cond_check_en), .halt_req(halt_req), .intr(intr), 
        .is_call(is_call), .is_ret(is_ret), .is_push(is_push), .is_pop(is_pop),
        .take_branch(take_branch), .io_m(io_m), .s1(s1), .s0(s0), 
        .inta(inta), .m_cycle(m_cycle), .t_state(t_state), 
        .z_write_en(z_write_en), .w_write_en(w_write_en),
        .inc_wz_addr(inc_wz_addr), 
        .high_byte_sel(high_byte_sel), 
        .fetch_addr_override(fetch_addr_override),
        .fetch_stage_out(fetch_stage),
        .exec_stage_out(exec_stage),
        .sp_push_strobe(sp_push_strobe),
        .sp_pop_strobe(sp_pop_strobe)
    );

    addr_mux amux_inst (
        .pc_in(pc_reg), .hl_in(reg_HL_out), .sp_in(sp_out), 
        .alt_pair_in(wz_pair), .addr_mux_sel(addr_mux_sel), 
        .addr_out(raw_mux_addr) 
    );

    reg_file reg_inst (
        .clk(clk), .rst(rst), 
        .read_sel_1(reg_read_sel_1), .read_sel_2(reg_read_sel_2), 
        .write_sel(effective_reg_write_sel), 
        .write_en(effective_reg_write_en), 
        .write_data(effective_reg_write_data), 
        
        .reg_pair_sel(reg_pair_sel),
        .reg_pair_write_en(safe_reg_pair_write_en),
        .reg_pair_write_data(wz_pair), 
        .reg_pair_inc(safe_reg_pair_inc),
        .reg_pair_dec(safe_reg_pair_dec),
        .reg_pair_add(safe_reg_pair_add),
        .sp_in(sp_out),
        .xchg_en(safe_xchg_en),
        .dad_carry_out(dad_carry),
        
        .read_data_1(reg_read_data_1), 
        .read_data_2(reg_read_data_2), 
        .reg_A_out(reg_A_out), 
        .reg_HL_out(reg_HL_out)
    );

    flag_reg flag_inst (
        .clk(clk), .rst(rst), 
        .flags_write_en(safe_flags_write_en), 
        .dad_en(safe_reg_pair_add),
        .dad_carry_in(dad_carry),
        .pop_psw_en(pop_psw_en),
        .pop_psw_data(internal_data_in),
        .alu_flags_in(alu_flags_raw), 
        .psw_out(psw_out),
        .carry_out(flag_carry_out), 
        .flags_out(latched_flags)
    );

    alu alu_inst (
        .a(alu_operand_a), .b(alu_operand_b), .alu_op(alu_op), 
        .cin(flag_carry_out), .ac_in(latched_flags[2]),
        .result(alu_result), 
        .flags_out(alu_flags_raw)
    );

endmodule