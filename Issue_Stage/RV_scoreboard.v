`timescale 1ns / 1ps

`include "RV_define.vh"

module RV_scoreboard#(

    parameter CORE_ID = 0

)(

    input  wire clk,
    input  wire reset,
    
    //Ibuffer input
    input  wire                              ibuffer_if_valid,
    input  wire [`UUID_BITS-1 : 0]           ibuffer_if_uuid,
    input  wire [`NW_BITS-1 : 0]             ibuffer_if_wid,
    input  wire [`NUM_THREADS-1 : 0]         ibuffer_if_tmask,
    input  wire [31 : 0]                     ibuffer_if_PC,
    input  wire [`EX_BITS-1 : 0]             ibuffer_if_ex_type,
    input  wire [`INST_OP_BITS-1 : 0]        ibuffer_if_op_type,
    input  wire [`INST_MOD_BITS-1 : 0]       ibuffer_if_op_mod,
    input  wire                              ibuffer_if_wb,
    input  wire                              ibuffer_if_use_PC,
    input  wire                              ibuffer_if_use_imm,
    input  wire [31 : 0]                     ibuffer_if_imm,
    input  wire [`NR_BITS-1 : 0]             ibuffer_if_rd,
    input  wire [`NR_BITS-1 : 0]             ibuffer_if_rs1,
    input  wire [`NR_BITS-1 : 0]             ibuffer_if_rs2,
    input  wire [`NR_BITS-1 : 0]             ibuffer_if_rs3,
    input  wire [`NR_BITS-1 : 0]             ibuffer_if_rd_n,
    input  wire [`NR_BITS-1 : 0]             ibuffer_if_rs1_n,
    input  wire [`NR_BITS-1 : 0]             ibuffer_if_rs2_n,
    input  wire [`NR_BITS-1 : 0]             ibuffer_if_rs3_n,
    input  wire [`NW_BITS-1 : 0]             ibuffer_if_wid_n,
    input  wire                              writeback_if_valid,
    input  wire [`UUID_BITS-1 : 0]           writeback_if_uuid,
    input  wire [`NUM_THREADS-1 : 0]         writeback_if_tmask,
    input  wire [`NW_BITS-1 : 0]             writeback_if_wid,
    input  wire [31 : 0]                     writeback_if_PC,
    input  wire [`NR_BITS-1 : 0]             writeback_if_rd,
    input  wire [(`NUM_THREADS*32)-1 : 0]    writeback_if_data,
    input  wire                              writeback_if_eop,
    output wire                              ibuffer_if_ready,
    output wire                              writeback_if_ready
    
);

    reg [`NUM_REGS-1 : 0]  inuse_regs   [`NUM_WARPS-1 : 0];
    reg [`NUM_REGS-1 : 0]  inuse_regs_n [`NUM_WARPS-1 : 0];
    
    wire reserve_reg = ibuffer_if_valid   && ibuffer_if_ready   && ibuffer_if_wb;
    wire release_reg = writeback_if_valid && writeback_if_ready && writeback_if_eop;
    
    integer i;
    always@(*)
    begin
    
        for(i = 0 ; i < `NUM_WARPS ; i = i + 1)
        begin
        
            inuse_regs_n[i]=inuse_regs[i];
        
        end
        
        if(reserve_reg)
        begin
            
            inuse_regs_n[ibuffer_if_wid][ibuffer_if_rd] = 1;
        
        end
        
        if(release_reg)
        begin
        
            inuse_regs_n[writeback_if_wid][writeback_if_rd] = 0;
        
        end
    
    end
    
    always@(posedge clk)
    begin
    
        if(reset)
        begin
        
            for(i = 0 ; i < `NUM_WARPS ; i = i + 1)
            begin
            
                inuse_regs[i]=0;
            
            end    
        
        end
        else begin
        
            for(i = 0 ; i < `NUM_WARPS ; i = i + 1)
            begin
            
                inuse_regs[i]=inuse_regs_n[i];
            
            end
        
        
        end
    
    end
    
    reg deq_inuse_rd , deq_inuse_rs1 , deq_inuse_rs2 , deq_inuse_rs3;
    
    always@(posedge clk)
    begin
    
        deq_inuse_rd  <= inuse_regs_n[ibuffer_if_wid_n][ibuffer_if_rd_n];
        deq_inuse_rs1 <= inuse_regs_n[ibuffer_if_wid_n][ibuffer_if_rs1_n];
        deq_inuse_rs2 <= inuse_regs_n[ibuffer_if_wid_n][ibuffer_if_rs2_n];
        deq_inuse_rs3 <= inuse_regs_n[ibuffer_if_wid_n][ibuffer_if_rs3_n];
    
    end
    
    assign writeback_if_ready = 1'b1;
    assign ibuffer_if_ready = ~(deq_inuse_rd 
                             | deq_inuse_rs1 
                             | deq_inuse_rs2 
                             | deq_inuse_rs3);
    
endmodule
