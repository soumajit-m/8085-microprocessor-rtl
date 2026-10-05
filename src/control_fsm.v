`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////// 
// Engineer: Soumajit Mandal (Roll: 2023ETB016)
// 
// Create Date: 09/18/2026
// Design Name: 8085_Control
// Module Name: control_fsm
// Project Name: 8085
// Description: Timing and Control FSM with multi-cycle execution routing
//////////////////////////////////////////////////////////////////////////////////

module control_fsm(
    // Clock and Reset
    input wire clk,
    input wire rst,
    
    // Instruction Decoder Inputs
    input wire is_nop,         
    input wire is_mem_read,    
    input wire is_mem_write,   
    input wire is_io_op,       
    input wire is_2_byte,       
    input wire is_3_byte,       
    input wire cond_check_en,   
    input wire take_branch,     
    input wire halt_req,       
    
    // Interrupt Signals
    input wire intr,           
    output reg inta,           
    
    // System Status Outputs 
    output wire io_m,          
    output wire s1,            
    output wire s0,            
    
    // Internal State Outputs
    output reg [2:0] m_cycle,
    output reg [2:0] t_state,
    
    // Datapath Control Flags
    output wire z_write_en,
    output wire w_write_en,
    output wire inc_wz_addr,        // Tells datapath to use WZ + 1
    output wire high_byte_sel,      // Tells datapath to output H instead of L
    output wire fetch_addr_override // Forces datapath to use PC for address
);

    localparam M_HALT   = 3'b000; 
    localparam M_MEM_WR = 3'b001; 
    localparam M_MEM_RD = 3'b010; 
    localparam M_FETCH  = 3'b011; 
    localparam M_IO_WR  = 3'b101; 
    localparam M_IO_RD  = 3'b110; 
    localparam M_INTA   = 3'b111; 

    localparam T1=1, T2=2, T3=3, T4=4, T5=5;
    
    // Internal stage trackers (hidden from top module)
    reg [1:0] fetch_stage; 
    reg [1:0] exec_stage;
    
    assign io_m = m_cycle[2];
    assign s1   = m_cycle[1];
    assign s0   = m_cycle[0];
    
    // Combinational Datapath Flags
    assign z_write_en = (m_cycle == M_MEM_RD && t_state == T3 && fetch_stage == 1);
    assign w_write_en = (m_cycle == M_MEM_RD && t_state == T3 && fetch_stage == 2);
    
    assign inc_wz_addr = (exec_stage == 2);
    assign high_byte_sel = (exec_stage == 2);
    assign fetch_addr_override = (m_cycle == M_FETCH) || (m_cycle == M_MEM_RD && fetch_stage != 0);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            m_cycle <= M_FETCH;
            t_state <= T1;
            inta <= 0;
            fetch_stage <= 0;
            exec_stage <= 0;
        end else begin
            case (m_cycle)
                M_FETCH: begin
                    if (is_nop) begin
                        if (t_state == T5) begin 
                            t_state <= T1; 
                            m_cycle <= intr ? M_INTA : M_FETCH; 
                        end else begin
                            t_state <= t_state + 1;
                        end
                    end else begin
                        if (t_state == T4) begin
                            t_state <= T1; 
                            
                            if (cond_check_en && !take_branch) begin
                                m_cycle <= M_FETCH; 
                            end else if (is_2_byte || is_3_byte) begin
                                fetch_stage <= 1;   
                                m_cycle <= M_MEM_RD;
                            end else begin
                                if (intr) m_cycle <= M_INTA;
                                else if (halt_req) m_cycle <= M_HALT;
                                else if (is_io_op && is_mem_read) m_cycle <= M_IO_RD;
                                else if (is_io_op && is_mem_write) m_cycle <= M_IO_WR;
                                else if (is_mem_read) m_cycle <= M_MEM_RD;
                                else if (is_mem_write) m_cycle <= M_MEM_WR;
                                else m_cycle <= M_FETCH;
                            end
                        end else begin
                            t_state <= t_state + 1;
                        end
                    end
                end
                
                M_MEM_RD: begin
                    if (t_state == T3) begin
                        t_state <= T1; 
                        
                        if (fetch_stage == 1) begin
                            if (is_3_byte) begin
                                fetch_stage <= 2;
                                m_cycle <= M_MEM_RD; 
                            end else begin
                                fetch_stage <= 0;
                                // --- FIX: Route 2-byte I/O instructions to I/O space ---
                                if (is_io_op && is_mem_read) m_cycle <= M_IO_RD;
                                else if (is_io_op && is_mem_write) m_cycle <= M_IO_WR;
                                else m_cycle <= intr ? M_INTA : M_FETCH;
                            end
                        end else if (fetch_stage == 2) begin
                            fetch_stage <= 0;
                            // Route to execution phase
                            if (is_mem_write) begin
                                m_cycle <= M_MEM_WR;
                                exec_stage <= 1; 
                            end else if (is_mem_read) begin
                                m_cycle <= M_MEM_RD;
                                exec_stage <= 1; 
                            end else begin
                                m_cycle <= intr ? M_INTA : M_FETCH; 
                            end
                        end else begin
                            exec_stage <= 0;
                            m_cycle <= intr ? M_INTA : M_FETCH; 
                        end
                    end else begin
                        t_state <= t_state + 1;
                    end
                end
                
                M_MEM_WR: begin
                    if (t_state == T3) begin
                        t_state <= T1; 
                        
                        // Chain a second write cycle for 16-bit stores (SHLD)
                        if (is_3_byte && exec_stage == 1) begin
                            m_cycle <= M_MEM_WR; 
                            exec_stage <= 2;
                        end else begin
                            exec_stage <= 0;
                            // --- FIX: Route 2-byte I/O instructions to I/O space ---
                                if (is_io_op && is_mem_read) m_cycle <= M_IO_RD;
                                else if (is_io_op && is_mem_write) m_cycle <= M_IO_WR;
                                else m_cycle <= intr ? M_INTA : M_FETCH; 
                        end
                    end else begin
                        t_state <= t_state + 1;
                    end
                end

                M_IO_RD, M_IO_WR: begin
                    if (t_state == T3) begin
                        t_state <= T1; 
                        m_cycle <= intr ? M_INTA : M_FETCH; 
                    end else begin
                        t_state <= t_state + 1;
                    end
                end
                
                M_HALT: begin
                    if (intr) begin
                        m_cycle <= M_INTA; 
                        t_state <= T1;
                    end
                end
                
                M_INTA: begin
                    inta <= 1; 
                    if (t_state == T3) begin 
                        inta <= 0; 
                        t_state <= T1;
                        m_cycle <= M_FETCH; 
                    end else begin
                        t_state <= t_state + 1;
                    end
                end
                
                default: m_cycle <= M_FETCH; 
            endcase
        end
    end
endmodule