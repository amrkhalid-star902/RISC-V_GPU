`timescale 1ns / 1ps

`include "RV_define.vh"

module RV_writeback#(

    parameter CORE_ID = 0

)(
    
    input  wire clk,
    input  wire reset,
    input  wire writeback_if_ready,
    
    //ALU input side
    input  wire                              alu_commit_if_valid,
    input  wire [`UUID_BITS-1 : 0]           alu_commit_if_uuid,
    input  wire [`NW_BITS-1 : 0]             alu_commit_if_wid, 
    input  wire [`NUM_THREADS-1 : 0]         alu_commit_if_tmask,
    input  wire [31 : 0]                     alu_commit_if_PC,
    input  wire [(`NUM_THREADS*32)-1 : 0]    alu_commit_if_data,
    input  wire [`NR_BITS-1 : 0]             alu_commit_if_rd, 
    input  wire                              alu_commit_if_wb, 
    input  wire                              alu_commit_if_eop, 
    
    //LSU input side
    input  wire                              ld_commit_if_valid,
    input  wire [`UUID_BITS-1 : 0]           ld_commit_if_uuid,
    input  wire [`NW_BITS-1 : 0]             ld_commit_if_wid, 
    input  wire [`NUM_THREADS-1 : 0]         ld_commit_if_tmask,
    input  wire [31 : 0]                     ld_commit_if_PC,
    input  wire [(`NUM_THREADS*32)-1 : 0]    ld_commit_if_data,
    input  wire [`NR_BITS-1 : 0]             ld_commit_if_rd, 
    input  wire                              ld_commit_if_wb, 
    input  wire                              ld_commit_if_eop,
    
    //CSR input side
    input  wire                              csr_commit_if_valid,
    input  wire [`UUID_BITS-1 : 0]           csr_commit_if_uuid,
    input  wire [`NW_BITS-1 : 0]             csr_commit_if_wid, 
    input  wire [`NUM_THREADS-1 : 0]         csr_commit_if_tmask,
    input  wire [31 : 0]                     csr_commit_if_PC,
    input  wire [(`NUM_THREADS*32)-1 : 0]    csr_commit_if_data,
    input  wire [`NR_BITS-1 : 0]             csr_commit_if_rd, 
    input  wire                              csr_commit_if_wb, 
    input  wire                              csr_commit_if_eop, 
    
    //FPU input side
    input  wire                              fpu_commit_if_valid,
    input  wire [`UUID_BITS-1 : 0]           fpu_commit_if_uuid,
    input  wire [`NW_BITS-1 : 0]             fpu_commit_if_wid, 
    input  wire [`NUM_THREADS-1 : 0]         fpu_commit_if_tmask,
    input  wire [31 : 0]                     fpu_commit_if_PC,
    input  wire [(`NUM_THREADS*32)-1 : 0]    fpu_commit_if_data,
    input  wire [`NR_BITS-1 : 0]             fpu_commit_if_rd, 
    input  wire                              fpu_commit_if_wb, 
    input  wire                              fpu_commit_if_eop, 
    
    //GPU input side
    input  wire                              gpu_commit_if_valid,
    input  wire [`UUID_BITS-1 : 0]           gpu_commit_if_uuid,
    input  wire [`NW_BITS-1 : 0]             gpu_commit_if_wid, 
    input  wire [`NUM_THREADS-1 : 0]         gpu_commit_if_tmask,
    input  wire [31 : 0]                     gpu_commit_if_PC,
    input  wire [(`NUM_THREADS*32)-1 : 0]    gpu_commit_if_data,
    input  wire [`NR_BITS-1 : 0]             gpu_commit_if_rd, 
    input  wire                              gpu_commit_if_wb, 
    input  wire                              gpu_commit_if_eop, 
    
    //Ready signals of each unit
    output wire                              alu_commit_if_ready,
    output wire                              ld_commit_if_ready,
    output wire                              csr_commit_if_ready,
    output wire                              fpu_commit_if_ready,
    output wire                              gpu_commit_if_ready,
    
    // WriteBack Signals
    output wire                              writeback_if_valid,
    output wire [`UUID_BITS-1 : 0]           writeback_if_uuid,
    output wire [`NW_BITS-1 : 0]             writeback_if_wid, 
    output wire [`NUM_THREADS-1 : 0]         writeback_if_tmask,
    output wire [31 : 0]                     writeback_if_PC,
    output wire [(`NUM_THREADS*32)-1 : 0]    writeback_if_data,
    output wire [`NR_BITS-1 : 0]             writeback_if_rd, 
    output wire                              writeback_if_wb, 
    output wire                              writeback_if_eop

);


    localparam NUM_RSPS = 5;
    localparam DATAW    = `NW_BITS + 32 + `NUM_THREADS + `NR_BITS + (`NUM_THREADS * 32) + 1;
    
    wire                              wb_valid;
    wire [`NW_BITS-1 : 0]             wb_wid; 
    wire [31 : 0]                     wb_PC; 
    wire [`NUM_THREADS-1 : 0]         wb_tmask;  
    wire [`NR_BITS-1 : 0]             wb_rd; 
    wire [(`NUM_THREADS*32) - 1 : 0]  wb_data;  
    wire                              wb_eop;
    
    wire [NUM_RSPS-1 : 0]         rsp_valid;
    wire [(NUM_RSPS*DATAW)-1 : 0] rsp_data;  
    wire [NUM_RSPS-1 : 0]         rsp_ready;
    wire                          stall;
    
    assign rsp_valid = {            
    
        gpu_commit_if_valid && gpu_commit_if_wb,   
        csr_commit_if_valid && csr_commit_if_wb,       
        alu_commit_if_valid && alu_commit_if_wb,           
        fpu_commit_if_valid && fpu_commit_if_wb,    
        ld_commit_if_valid  && ld_commit_if_wb     
    
    };
    
    assign rsp_data = {
                                           
        {gpu_commit_if_wid, gpu_commit_if_PC, gpu_commit_if_tmask, gpu_commit_if_rd, gpu_commit_if_data, gpu_commit_if_eop},    
        {csr_commit_if_wid, csr_commit_if_PC, csr_commit_if_tmask, csr_commit_if_rd, csr_commit_if_data, csr_commit_if_eop},    
        {alu_commit_if_wid, alu_commit_if_PC, alu_commit_if_tmask, alu_commit_if_rd, alu_commit_if_data, alu_commit_if_eop},    
        {fpu_commit_if_wid, fpu_commit_if_PC, fpu_commit_if_tmask, fpu_commit_if_rd, fpu_commit_if_data, fpu_commit_if_eop},    
        {ld_commit_if_wid , ld_commit_if_PC , ld_commit_if_tmask , ld_commit_if_rd , ld_commit_if_data , ld_commit_if_eop}     
         
    };
    
    RV_stream_arbiter #(        
        
        .NUM_REQS (NUM_RSPS),   
        .DATAW    (DATAW),      
        .BUFFERED (1),          
        .TYPE     ("R")         
        
    ) rsp_arb (
    
        .clk       (clk),           
        .reset     (reset),         
        .valid_in  (rsp_valid),     
        .data_in   (rsp_data),      
        .ready_in  (rsp_ready),     
        .valid_out (wb_valid),      
        .data_out  ({wb_wid, wb_PC, wb_tmask, wb_rd, wb_data, wb_eop}),
        .ready_out (~stall)         
        
    );
    
    assign ld_commit_if_ready  = rsp_ready[0] || ~ld_commit_if_wb;  
    assign fpu_commit_if_ready = rsp_ready[1] || ~fpu_commit_if_wb;  
    assign alu_commit_if_ready = rsp_ready[2] || ~alu_commit_if_wb;
    assign csr_commit_if_ready = rsp_ready[3] || ~csr_commit_if_wb; 
    assign gpu_commit_if_ready = rsp_ready[4] || ~gpu_commit_if_wb; 

    assign stall = ~writeback_if_ready && writeback_if_valid;
    
    RV_pipe_register #(
    
        .DATAW  (1 + DATAW),    
        .RESETW (1)             
        
    ) pipe_reg (
    
        .clk      (clk),        
        .reset    (reset),      
        .enable   (~stall),     
        .data_in  ({wb_valid,           wb_wid,           wb_PC,           wb_tmask,           wb_rd,           wb_data,           wb_eop}),
        .data_out ({writeback_if_valid, writeback_if_wid, writeback_if_PC, writeback_if_tmask, writeback_if_rd, writeback_if_data, writeback_if_eop})
        
    );
    

endmodule
