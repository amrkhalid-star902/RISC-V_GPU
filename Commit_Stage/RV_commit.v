`timescale 1ns / 1ps

`include "RV_define.vh"

module RV_commit#(

    parameter CORE_ID = 0

)(

    input  wire clk,
    input  wire reset,
    input  wire writeback_if_ready,
    
    //ALU input side
    input  wire                                  alu_commit_if_valid,
    input  wire [`UUID_BITS-1 : 0]               alu_commit_if_uuid,
    input  wire [`NW_BITS-1 : 0]                 alu_commit_if_wid, 
    input  wire [`NUM_THREADS-1 : 0]             alu_commit_if_tmask,
    input  wire [31 : 0]                         alu_commit_if_PC,
    input  wire [(`NUM_THREADS*32)-1 : 0]        alu_commit_if_data,
    input  wire [`NR_BITS-1 : 0]                 alu_commit_if_rd, 
    input  wire                                  alu_commit_if_wb, 
    input  wire                                  alu_commit_if_eop, 
    
    //LSU input side
    input  wire                                  ld_commit_if_valid,
    input  wire [`UUID_BITS-1 : 0]               ld_commit_if_uuid,
    input  wire [`NW_BITS-1 : 0]                 ld_commit_if_wid, 
    input  wire [`NUM_THREADS-1 : 0]             ld_commit_if_tmask,
    input  wire [31 : 0]                         ld_commit_if_PC,
    input  wire [(`NUM_THREADS*32)-1 : 0]        ld_commit_if_data,
    input  wire [`NR_BITS-1 : 0]                 ld_commit_if_rd, 
    input  wire                                  ld_commit_if_wb, 
    input  wire                                  ld_commit_if_eop,
    
    //CSR input side
    input  wire                                  csr_commit_if_valid,
    input  wire [`UUID_BITS-1 : 0]               csr_commit_if_uuid,
    input  wire [`NW_BITS-1 : 0]                 csr_commit_if_wid, 
    input  wire [`NUM_THREADS-1 : 0]             csr_commit_if_tmask,
    input  wire [31 : 0]                         csr_commit_if_PC,
    input  wire [(`NUM_THREADS*32)-1 : 0]        csr_commit_if_data,
    input  wire [`NR_BITS-1 : 0]                 csr_commit_if_rd, 
    input  wire                                  csr_commit_if_wb, 
    input  wire                                  csr_commit_if_eop, 
    
    //FPU input side
    input  wire                                  fpu_commit_if_valid,
    input  wire [`UUID_BITS-1 : 0]               fpu_commit_if_uuid,
    input  wire [`NW_BITS-1 : 0]                 fpu_commit_if_wid, 
    input  wire [`NUM_THREADS-1 : 0]             fpu_commit_if_tmask,
    input  wire [31 : 0]                         fpu_commit_if_PC,
    input  wire [(`NUM_THREADS*32)-1 : 0]        fpu_commit_if_data,
    input  wire [`NR_BITS-1 : 0]                 fpu_commit_if_rd, 
    input  wire                                  fpu_commit_if_wb, 
    input  wire                                  fpu_commit_if_eop, 
    
    //GPU input side
    input  wire                                  gpu_commit_if_valid,
    input  wire [`UUID_BITS-1 : 0]               gpu_commit_if_uuid,
    input  wire [`NW_BITS-1 : 0]                 gpu_commit_if_wid, 
    input  wire [`NUM_THREADS-1 : 0]             gpu_commit_if_tmask,
    input  wire [31 : 0]                         gpu_commit_if_PC,
    input  wire [(`NUM_THREADS*32)-1 : 0]        gpu_commit_if_data,
    input  wire [`NR_BITS-1 : 0]                 gpu_commit_if_rd, 
    input  wire                                  gpu_commit_if_wb, 
    input  wire                                  gpu_commit_if_eop,
    
    //Store input signals
    input  wire                                  st_commit_if_valid,
    input  wire [`UUID_BITS-1 : 0]               st_commit_if_uuid,
    input  wire [`NW_BITS-1 : 0]                 st_commit_if_wid,
    input  wire [`NUM_THREADS-1 : 0]             st_commit_if_tmask,
    input  wire [31 : 0]                         st_commit_if_PC,
    input  wire [(`NUM_THREADS*32)-1 : 0]        st_commit_if_data,
    input  wire [`NR_BITS-1 : 0]                 st_commit_if_rd,
    input  wire                                  st_commit_if_wb,
    input  wire                                  st_commit_if_eop,
        
    //Ready signals of each unit
    output wire                                  alu_commit_if_ready,
    output wire                                  ld_commit_if_ready,
    output wire                                  csr_commit_if_ready,
    output wire                                  fpu_commit_if_ready,
    output wire                                  gpu_commit_if_ready,
    output wire                                  st_commit_if_ready,
    
    // WriteBack Signals
    output wire                                  writeback_if_valid,
    output wire [`UUID_BITS-1 : 0]               writeback_if_uuid,
    output wire [`NW_BITS-1 : 0]                 writeback_if_wid, 
    output wire [`NUM_THREADS-1 : 0]             writeback_if_tmask,
    output wire [31 : 0]                         writeback_if_PC,
    output wire [(`NUM_THREADS*32)-1 : 0]        writeback_if_data,
    output wire [`NR_BITS-1 : 0]                 writeback_if_rd, 
    output wire                                  writeback_if_wb, 
    output wire                                  writeback_if_eop,
    
    //Data fetch to CSR
    output wire                                  cmt_to_csr_if_valid,
    output wire [$clog2(6*`NUM_THREADS+1)-1 : 0] cmt_to_csr_if_commit_size

);
    
    localparam commit_bits = 6*`NUM_THREADS;
    
    wire alu_commit_fire = alu_commit_if_valid && alu_commit_if_ready;
    wire ld_commit_fire  = ld_commit_if_valid  && ld_commit_if_ready;
    wire st_commit_fire  = st_commit_if_valid  && st_commit_if_ready;
    wire csr_commit_fire = csr_commit_if_valid && csr_commit_if_ready;
    wire fpu_commit_fire = fpu_commit_if_valid && fpu_commit_if_ready;
    wire gpu_commit_fire = gpu_commit_if_valid && gpu_commit_if_ready;
    
    wire commit_fire = alu_commit_fire
                    || ld_commit_fire
                    || st_commit_fire
                    || csr_commit_fire
                    || fpu_commit_fire
                    || gpu_commit_fire;
                    
    wire [commit_bits-1 : 0] commit_tmask;
    
    wire [$clog2(commit_bits+1)-1 : 0] commit_size;
    assign commit_tmask = {
    
        {`NUM_THREADS{alu_commit_fire}} & alu_commit_if_tmask,
        {`NUM_THREADS{st_commit_fire}}  & st_commit_if_tmask,
        {`NUM_THREADS{ld_commit_fire}}  & ld_commit_if_tmask, 
        {`NUM_THREADS{csr_commit_fire}} & csr_commit_if_tmask,
        {`NUM_THREADS{fpu_commit_fire}} & fpu_commit_if_tmask,
        {`NUM_THREADS{gpu_commit_fire}} & gpu_commit_if_tmask
        
    };
    
    RV_popcount #(
    
        .N(commit_bits)
    
    )commit_count(
    
        .in_i(commit_tmask),
        .cnt_o(commit_size)
        
    );
    
    RV_pipe_register #(
    
        .DATAW  (1 + commit_bits),
        .RESETW (1)
        
    ) pipe_reg (
    
        .clk      (clk),
        .reset    (reset),
        .enable   (1'b1),
        .data_in  ({commit_fire,         commit_size}),
        .data_out ({cmt_to_csr_if_valid, cmt_to_csr_if_commit_size})
    
    );
    
    
    RV_writeback #(
    
        .CORE_ID(CORE_ID)
        
    ) writeback (
    
        .clk            (clk),
        .reset          (reset),

        .alu_commit_if_valid(alu_commit_if_valid),
        .alu_commit_if_uuid(alu_commit_if_uuid),
        .alu_commit_if_wid(alu_commit_if_wid),
        .alu_commit_if_tmask(alu_commit_if_tmask),    
        .alu_commit_if_PC(alu_commit_if_PC),
        .alu_commit_if_data(alu_commit_if_data),
        .alu_commit_if_rd(alu_commit_if_rd),
        .alu_commit_if_wb(alu_commit_if_wb),
        .alu_commit_if_eop(alu_commit_if_eop),
        .alu_commit_if_ready(alu_commit_if_ready),

        .ld_commit_if_valid(ld_commit_if_valid),
        .ld_commit_if_uuid(ld_commit_if_uuid),
        .ld_commit_if_wid(ld_commit_if_wid),
        .ld_commit_if_tmask(ld_commit_if_tmask),    
        .ld_commit_if_PC(ld_commit_if_PC),
        .ld_commit_if_data(ld_commit_if_data),
        .ld_commit_if_rd(ld_commit_if_rd),
        .ld_commit_if_wb(ld_commit_if_wb),
        .ld_commit_if_eop(ld_commit_if_eop),
        .ld_commit_if_ready(ld_commit_if_ready),

        .csr_commit_if_valid(csr_commit_if_valid),
        .csr_commit_if_uuid(csr_commit_if_uuid),
        .csr_commit_if_wid(csr_commit_if_wid),
        .csr_commit_if_tmask(csr_commit_if_tmask),    
        .csr_commit_if_PC(csr_commit_if_PC),
        .csr_commit_if_data(csr_commit_if_data),
        .csr_commit_if_rd(csr_commit_if_rd),
        .csr_commit_if_wb(csr_commit_if_wb),
        .csr_commit_if_eop(csr_commit_if_eop),
        .csr_commit_if_ready(csr_commit_if_ready),


        .fpu_commit_if_valid(fpu_commit_if_valid),
        .fpu_commit_if_uuid(fpu_commit_if_uuid),
        .fpu_commit_if_wid(fpu_commit_if_wid),
        .fpu_commit_if_tmask(fpu_commit_if_tmask),    
        .fpu_commit_if_PC(fpu_commit_if_PC),
        .fpu_commit_if_data(fpu_commit_if_data),
        .fpu_commit_if_rd(fpu_commit_if_rd),
        .fpu_commit_if_wb(fpu_commit_if_wb),
        .fpu_commit_if_eop(fpu_commit_if_eop),
        .fpu_commit_if_ready(fpu_commit_if_ready),


        .gpu_commit_if_valid(gpu_commit_if_valid),
        .gpu_commit_if_uuid(gpu_commit_if_uuid),
        .gpu_commit_if_wid(gpu_commit_if_wid),
        .gpu_commit_if_tmask(gpu_commit_if_tmask),    
        .gpu_commit_if_PC(gpu_commit_if_PC),
        .gpu_commit_if_data(gpu_commit_if_data),
        .gpu_commit_if_rd(gpu_commit_if_rd),
        .gpu_commit_if_wb(gpu_commit_if_wb),
        .gpu_commit_if_eop(gpu_commit_if_eop),
        .gpu_commit_if_ready(gpu_commit_if_ready),


        .writeback_if_valid(writeback_if_valid),
        .writeback_if_uuid(writeback_if_uuid),
        .writeback_if_tmask(writeback_if_tmask),
        .writeback_if_wid(writeback_if_wid),
        .writeback_if_PC(writeback_if_PC),
        .writeback_if_rd(writeback_if_rd),
        .writeback_if_data(writeback_if_data),
        .writeback_if_eop(writeback_if_eop),  
        .writeback_if_ready(writeback_if_ready)
        
    );
    
    
    assign st_commit_if_ready  = 1'b1;
    
endmodule
