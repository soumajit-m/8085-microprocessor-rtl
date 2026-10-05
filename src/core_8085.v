`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////// 
// Engineer: Soumajit Mandal (Roll: 2023ETB016)
// 
// Create Date: 09/18/2026
// Design Name: 8085_Core
// Module Name: core_8085
// Project Name: 8085
// Description: Top-level integration with native AD bus multiplexing
// 
// Revision:
// Revision 3.01 - Cleaned up little-endian W/Z operand loading via FSM strobes
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
    wire sp_write_en, sp_inc, sp_dec, z_write_en, w_write_en;
    wire [1:0] addr_mux_sel;
    wire [2:0] m_cycle, t_state;
    
    // Multi-Cycle Datapath Flags
    wire inc_wz_addr, high_byte_sel, fetch_addr_override;
    
    // 16-bit Control Wires
    wire reg_pair_write_en, reg_pair_inc, reg_pair_dec, reg_pair_add;
    wire [1:0] reg_pair_sel;
    
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
    
    // Internal Mux Routing
    wire [7:0] alu_operand_a = (alu_a_mux_sel) ? reg_read_data_1 : reg_A_out;
    wire [7:0] alu_operand_b = (operand_mux_sel) ? internal_data_in : reg_read_data_2;
    wire [7:0] reg_write_data = (is_mem_read || is_2_byte) ? internal_data_in : alu_result;
    
    // --------------------------------------------------------
    // Multi-Cycle Execution Override Logic
    // --------------------------------------------------------
    // Increment the target address if the FSM is in cycle 2 of an execution phase
    wire [15:0] exec_target_addr = (inc_wz_addr) ? raw_mux_addr + 1 : raw_mux_addr;
    
    // Force the address bus to use the PC during Fetch/Operand reads, else use the execution target
    assign internal_addr = (fetch_addr_override) ? pc_reg : exec_target_addr;
    
    // SHLD Data Splitting: Output H on cycle 2, Output L on cycle 1
    wire [7:0] shld_write_data = (high_byte_sel) ? reg_HL_out[15:8] : reg_HL_out[7:0];
    
    // Override the default data-out port if the instruction is SHLD (Opcode 22h)
    assign internal_data_out = (ir_reg == 8'h22) ? shld_write_data : reg_read_data_1;

    // --------------------------------------------------------
    // Bus Multiplexing Logic (Authentic 8085 hardware behavior)
    // --------------------------------------------------------
    // A8-A15 permanently drive the upper half of the address
    assign a_high = internal_addr[15:8];
    
    // ALE is HIGH only during T1 of any machine cycle
    assign ale = (t_state == 3'd1) ? 1'b1 : 1'b0;
    
    // AD Bus Tri-State Controller
    assign ad_bus = (ale)   ? internal_addr[7:0] :
                    (~wr_n) ? internal_data_out : 
                              8'hZZ;
                              
    // Internal modules always read directly from the AD bus
    assign internal_data_in = ad_bus;
    
    // Read/Write Strobes (Active low during T2 and T3 of respective cycles)
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
            
            // Increment PC for 2-byte and 3-byte instruction operands
            if (m_cycle == 3'b010 && t_state == 3 && (is_2_byte || is_3_byte)) 
                pc_reg <= pc_reg + 1;
                
            // W and Z operand latching
            if (z_write_en) z_reg <= internal_data_in; // Low byte -> Z
            if (w_write_en) w_reg <= internal_data_in; // High byte -> W
            
            // GATED BRANCH EXECUTION: Only update PC to WZ target when the 
            // entire 3-byte instruction read cycle has completely finished at T3.
            if (pc_write_en && take_branch && (m_cycle == 3'b010) && (t_state == 3) && (w_write_en)) begin
                pc_reg <= {internal_data_in, z_reg}; // Combines high byte from bus with Z
            end
        end
    end
    
    // --------------------------------------------------------
    // Instance Wiring
    // --------------------------------------------------------
    cond_checker cond_inst (
        .cond_check_en(cond_check_en), .jump_cond(jump_cond), 
        .flags(latched_flags), .take_branch(take_branch)
    );

    stack_pointer sp_inst (
        .clk(clk), .rst(rst),
        .sp_write_en(sp_write_en), .sp_inc(sp_inc), .sp_dec(sp_dec),
        .sp_data_in(reg_HL_out), .sp_out(sp_out)
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
        .operand_mux_sel(operand_mux_sel), .pc_write_en(pc_write_en), 
        .cond_check_en(cond_check_en), .jump_cond(jump_cond), 
        .halt_req(halt_req), .sp_write_en(sp_write_en), 
        .sp_inc(sp_inc), .sp_dec(sp_dec)
    );

    control_fsm fsm_inst (
        .clk(clk), .rst(rst), .is_nop(is_nop), 
        .is_mem_read(is_mem_read), .is_mem_write(is_mem_write), 
        .is_io_op(is_io_op), .is_2_byte(is_2_byte), .is_3_byte(is_3_byte), 
        .cond_check_en(cond_check_en), .halt_req(halt_req), .intr(intr), 
        .take_branch(take_branch), .io_m(io_m), .s1(s1), .s0(s0), 
        .inta(inta), .m_cycle(m_cycle), .t_state(t_state), 
        .z_write_en(z_write_en), .w_write_en(w_write_en),
        .inc_wz_addr(inc_wz_addr), 
        .high_byte_sel(high_byte_sel), 
        .fetch_addr_override(fetch_addr_override)
    );

    addr_mux amux_inst (
        .pc_in(pc_reg), .hl_in(reg_HL_out), .sp_in(sp_out), 
        .alt_pair_in(wz_pair), .addr_mux_sel(addr_mux_sel), 
        .addr_out(raw_mux_addr) 
    );
    
    // --------------------------------------------------------
    // Execution Strobe (Prevents Continuous Write Corruption)
    // --------------------------------------------------------
// Update exec_strobe to include I/O Read cycles (3'b110)
    wire exec_strobe = (m_cycle == 3'b011 && t_state == 3'd4 && !is_2_byte && !is_3_byte && !is_mem_read && !is_mem_write) || 
                       ((m_cycle == 3'b010 || m_cycle == 3'b110) && t_state == 3'd3); // <--- Added M_IO_RD check
                       
    wire safe_reg_write_en = reg_write_en & exec_strobe;
    wire safe_flags_write_en = flags_write_en & exec_strobe;
    
    // INX, DCX, and DAD execute entirely within the M_FETCH cycle. Strobe at T4.
    wire safe_reg_pair_inc = reg_pair_inc & (m_cycle == 3'b011 && t_state == 3'd4);
    wire safe_reg_pair_dec = reg_pair_dec & (m_cycle == 3'b011 && t_state == 3'd4);
    wire safe_reg_pair_add = reg_pair_add & (m_cycle == 3'b011 && t_state == 3'd4);

    // LXI (and POP) finish loading the W and Z registers at the end of their memory read cycles.
    wire safe_reg_pair_write_en = reg_pair_write_en & (m_cycle == 3'b011 && t_state == 3'd1);

    reg_file reg_inst (
        .clk(clk), .rst(rst), 
        .read_sel_1(reg_read_sel_1), .read_sel_2(reg_read_sel_2), 
        .write_sel(reg_write_sel), 
        .write_en(safe_reg_write_en), 
        .write_data(reg_write_data), 
        
        .reg_pair_sel(reg_pair_sel),
        .reg_pair_write_en(safe_reg_pair_write_en),
        .reg_pair_write_data(wz_pair), 
        .reg_pair_inc(safe_reg_pair_inc),
        .reg_pair_dec(safe_reg_pair_dec),
        .reg_pair_add(safe_reg_pair_add),
        
        .read_data_1(reg_read_data_1), 
        .read_data_2(reg_read_data_2), 
        .reg_A_out(reg_A_out), 
        .reg_HL_out(reg_HL_out)
    );

    flag_reg flag_inst (
        .clk(clk), .rst(rst), 
        .flags_write_en(safe_flags_write_en), 
        .alu_flags_in(alu_flags_raw), .carry_out(flag_carry_out), 
        .flags_out(latched_flags)
    );

    alu alu_inst (
        .a(alu_operand_a), .b(alu_operand_b), .alu_op(alu_op), 
        .cin(flag_carry_out), .result(alu_result), 
        .flags_out(alu_flags_raw)
    );

endmodule