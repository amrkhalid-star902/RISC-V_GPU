`timescale 1ns / 1ps

`include "RV_define.vh"
`include "RV_cache_define.vh"


module RV_execute#(

    parameter CORE_ID   = 0,
    parameter NUM_REQS  = `NUM_THREADS,
    parameter WORD_SIZE = 4,
    parameter TAG_WIDTH = `DCACHE_CORE_TAG_WIDTH

)(

    input  wire clk,
    input  wire reset,
    input  wire busy,
    
    //Cache rsponse input side
    input  wire [NUM_REQS-1 : 0]                         dcache_req_if_ready,
    input  wire                                          dcache_rsp_if_valid,
    input  wire [NUM_REQS-1 : 0]                         dcache_rsp_if_tmask,
    input  wire [`WORD_WIDTH*NUM_REQS-1 : 0]             dcache_rsp_if_data,
    input  wire [TAG_WIDTH-1 : 0]                        dcache_rsp_if_tag,
    
    //Fetch to CSR unit 
    input  wire                                          cmt_to_csr_if_valid,
    input  wire [$clog2(6*`NUM_THREADS+1)-1 : 0]         cmt_to_csr_if_commit_size,
    input  wire [(`NUM_WARPS*`NUM_THREADS)-1 : 0]        fetch_to_csr_if_thread_masks,
    
    //ALU input signals
    input  wire                                          alu_req_if_valid,
    input  wire [`UUID_BITS-1 : 0]                       alu_req_if_uuid,
    input  wire [`NW_BITS-1 : 0]                         alu_req_if_wid,
    input  wire [`NUM_THREADS-1 : 0]                     alu_req_if_tmask,
    input  wire [31 : 0]                                 alu_req_if_PC,
    input  wire [31 : 0]                                 alu_req_if_next_PC,
    input  wire [`INST_ALU_BITS-1 : 0]                   alu_req_if_op_type,
    input  wire [`INST_MOD_BITS-1 : 0]                   alu_req_if_op_mod,
    input  wire                                          alu_req_if_use_PC,
    input  wire                                          alu_req_if_use_imm,
    input  wire [31 : 0]                                 alu_req_if_imm,
    input  wire [`NT_BITS-1 : 0]                         alu_req_if_tid,
    input  wire [(`NUM_THREADS*32)-1 : 0]                alu_req_if_rs1_data,
    input  wire [(`NUM_THREADS*32)-1 : 0]                alu_req_if_rs2_data,
    input  wire [`NR_BITS-1 : 0]                         alu_req_if_rd,
    input  wire                                          alu_req_if_wb,
    input  wire                                          alu_commit_if_ready,

    //LSU input interface
    input  wire                                         lsu_req_if_valid,
    input  wire [`UUID_BITS-1 : 0]                      lsu_req_if_uuid,
    input  wire [`NW_BITS-1 : 0]                        lsu_req_if_wid,
    input  wire [NUM_REQS-1 : 0]                        lsu_req_if_tmask,
    input  wire [31 : 0]                                lsu_req_if_PC,
    input  wire [`INST_LSU_BITS-1 : 0]                  lsu_req_if_op_type,
    input  wire                                         lsu_req_if_is_fence,
    input  wire [(NUM_REQS*32)-1 : 0]                   lsu_req_if_store_data,
    input  wire [(NUM_REQS*32)-1 : 0]                   lsu_req_if_base_addr,
    input  wire [31 : 0]                                lsu_req_if_offset,
    input  wire [`NR_BITS-1 : 0]                        lsu_req_if_rd,
    input  wire                                         lsu_req_if_wb,
    input  wire                                         lsu_req_if_is_prefetch,
    input  wire                                         ld_commit_if_ready,
    input  wire                                         st_commit_if_ready,
    
    //CSR input interface
    input  wire                                         csr_req_if_valid,
    input  wire [`UUID_BITS-1 : 0]                      csr_req_if_uuid,
    input  wire [`NW_BITS-1 : 0]                        csr_req_if_wid,
    input  wire [`NUM_THREADS-1 : 0]                    csr_req_if_tmask,
    input  wire [31 : 0]                                csr_req_if_PC,
    input  wire [`INST_CSR_BITS-1 : 0]                  csr_req_if_op_type,
    input  wire [`CSR_ADDR_BITS-1 : 0]                  csr_req_if_addr,
    input  wire [31 : 0]                                csr_req_if_rs1_data,
    input  wire                                         csr_req_if_use_imm,
    input  wire [`NRI_BITS-1 : 0]                       csr_req_if_imm,
    input  wire [`NR_BITS-1 : 0]                        csr_req_if_rd,
    input  wire                                         csr_req_if_wb,  
    input  wire                                         csr_commit_if_ready,
    
    //FPU input interface
    input wire                                          fpu_req_if_valid,
    input wire [`UUID_BITS-1 : 0]                       fpu_req_if_uuid,
    input wire [`NW_BITS-1 : 0]                         fpu_req_if_wid,     
    input wire [`NUM_THREADS-1 : 0]                     fpu_req_if_tmask,   
    input wire [31 : 0]                                 fpu_req_if_PC,
    input wire [`INST_FPU_BITS-1 : 0]                   fpu_req_if_op_type,
    input wire [`INST_MOD_BITS-1 : 0]                   fpu_req_if_op_mod,
    input wire [(`NUM_THREADS*32)-1 : 0]                fpu_req_if_rs1_data,
    input wire [(`NUM_THREADS*32)-1 : 0]                fpu_req_if_rs2_data,
    input wire [(`NUM_THREADS*32)-1 : 0]                fpu_req_if_rs3_data,
    input wire [`NR_BITS-1 : 0]                         fpu_req_if_rd,
    input wire                                          fpu_req_if_wb,
    input wire                                          fpu_commit_if_ready,
    
    //GPU unit input signals
    input  wire                                         gpu_req_if_valid,
    input  wire [`UUID_BITS-1 : 0]                      gpu_req_if_uuid,
    input  wire [`NW_BITS-1 : 0]                        gpu_req_if_wid,
    input  wire [`NUM_THREADS-1 : 0]                    gpu_req_if_tmask,
    input  wire [31 : 0]                                gpu_req_if_PC,
    input  wire [31 : 0]                                gpu_req_if_next_PC,
    input  wire [`INST_GPU_BITS-1 : 0]                  gpu_req_if_op_type,
    input  wire [`INST_MOD_BITS-1 : 0]                  gpu_req_if_op_mod,
    input  wire [`NT_BITS-1 : 0]                        gpu_req_if_tid,
    input  wire [(`NUM_THREADS * 32) - 1 : 0]           gpu_req_if_rs1_data,
    input  wire [(`NUM_THREADS * 32) - 1 : 0]           gpu_req_if_rs2_data,
    input  wire [(`NUM_THREADS * 32) - 1 : 0]           gpu_req_if_rs3_data,
    input  wire [`NR_BITS-1 : 0]                        gpu_req_if_rd,
    input  wire                                         gpu_req_if_wb,
    input  wire                                         gpu_commit_if_ready,
    
    //ALU output side
    output wire                                         alu_req_if_ready,
    output wire                                         branch_ctl_if_valid,
    output wire [`NW_BITS-1 : 0]                        branch_ctl_if_wid,
    output wire                                         branch_ctl_if_taken,
    output wire [31 : 0]                                branch_ctl_if_dest,
    output wire                                         alu_commit_if_valid,
    output wire [`UUID_BITS-1 : 0]                      alu_commit_if_uuid,
    output wire [`NW_BITS-1 : 0]                        alu_commit_if_wid,
    output wire [`NUM_THREADS-1 : 0]                    alu_commit_if_tmask,
    output wire [31 : 0]                                alu_commit_if_PC,
    output wire [(`NUM_THREADS*32)-1 : 0]               alu_commit_if_data,
    output wire [`NR_BITS-1 : 0]                        alu_commit_if_rd,
    output wire                                         alu_commit_if_wb,
    output wire                                         alu_commit_if_eop,
    
    //LSU output side
    output wire                                         ld_commit_if_valid,
    output wire [`UUID_BITS-1 : 0]                      ld_commit_if_uuid,
    output wire [`NW_BITS-1 : 0]                        ld_commit_if_wid,
    output wire [NUM_REQS-1 : 0]                        ld_commit_if_tmask,
    output wire [31 : 0]                                ld_commit_if_PC,
    output wire [(NUM_REQS*32)-1 : 0]                   ld_commit_if_data,
    output wire [`NR_BITS-1 : 0]                        ld_commit_if_rd,
    output wire                                         ld_commit_if_wb,
    output wire                                         ld_commit_if_eop,
    output wire                                         lsu_req_if_ready,
    
    output wire                                         st_commit_if_valid,
    output wire [`UUID_BITS-1 : 0]                      st_commit_if_uuid,
    output wire [`NW_BITS-1 : 0]                        st_commit_if_wid,
    output wire [NUM_REQS-1 : 0]                        st_commit_if_tmask,
    output wire [31 : 0]                                st_commit_if_PC,
    output wire [(NUM_REQS*32)-1 : 0]                   st_commit_if_data,
    output wire [`NR_BITS-1 : 0]                        st_commit_if_rd,
    output wire                                         st_commit_if_wb,
    output wire                                         st_commit_if_eop,
    
    //CSR unit output side
    output wire                                         csr_req_if_ready,
    output wire                                         csr_commit_if_valid,
    output wire [`UUID_BITS-1 : 0]                      csr_commit_if_uuid,
    output wire [`NW_BITS-1 : 0]                        csr_commit_if_wid,
    output wire [`NUM_THREADS-1 : 0]                    csr_commit_if_tmask,    
    output wire [31 : 0]                                csr_commit_if_PC,
    output wire [(`NUM_THREADS*32)-1 : 0]               csr_commit_if_data,
    output wire [`NR_BITS-1 : 0]                        csr_commit_if_rd,
    output wire                                         csr_commit_if_wb,
    output wire                                         csr_commit_if_eop,
    
    //FPU output side
    output wire                                         fpu_req_if_ready,
    output wire                                         fpu_commit_if_valid,
    output wire [`UUID_BITS-1 : 0]                      fpu_commit_if_uuid,
    output wire [`NW_BITS-1 : 0]                        fpu_commit_if_wid,
    output wire [`NUM_THREADS-1 : 0]                    fpu_commit_if_tmask,
    output wire [31 : 0]                                fpu_commit_if_PC,
    output wire [(`NUM_THREADS*32)-1 : 0]               fpu_commit_if_data,
    output wire [`NR_BITS-1 : 0]                        fpu_commit_if_rd,
    output wire                                         fpu_commit_if_wb,
    output wire                                         fpu_commit_if_eop,
    
    //GPU output side
    output wire                                         gpu_req_if_ready,
    output wire                                         gpu_commit_if_valid,
    output wire [`UUID_BITS-1 : 0]                      gpu_commit_if_uuid,
    output wire [`NW_BITS-1 : 0]                        gpu_commit_if_wid,
    output wire [`NUM_THREADS-1 : 0]                    gpu_commit_if_tmask,
    output wire [31 : 0]                                gpu_commit_if_PC,
    output wire [(`NUM_THREADS * 32) - 1 : 0]           gpu_commit_if_data,
    output wire [`NR_BITS-1 : 0]                        gpu_commit_if_rd,
    output wire                                         gpu_commit_if_wb,
    output wire                                         gpu_commit_if_eop,
    
    output wire                                         warp_ctl_if_valid,
    output wire [`NW_BITS-1 : 0]                        warp_ctl_if_wid,
    output wire                                         warp_ctl_if_tmc_valid,
    output wire [`NUM_THREADS-1 : 0]                    warp_ctl_if_tmc_tmask,
    output wire                                         warp_ctl_if_wspawn_valid,
    output wire [`NUM_WARPS-1 : 0]                      warp_ctl_if_wspawn_wmask,
    output wire [31 : 0]                                warp_ctl_if_wspawn_pc,
    output wire                                         warp_ctl_if_barrier_valid,
    output wire [`NB_BITS-1 : 0]                        warp_ctl_if_barrier_id,
    output wire [`NW_BITS-1 : 0]                        warp_ctl_if_barrier_size_m1,
    output wire                                         warp_ctl_if_split_valid,
    output wire                                         warp_ctl_if_split_diverged,
    output wire [`NUM_THREADS-1 : 0]                    warp_ctl_if_split_then_tmask,
    output wire [`NUM_THREADS-1 : 0]                    warp_ctl_if_split_else_tmask,
    output wire [31 : 0]                                warp_ctl_if_split_pc,
    
    //Dcache request signals
    output wire                                         dcache_rsp_if_ready,
    output wire [NUM_REQS-1 : 0]                        dcache_req_if_valid,
    output wire [NUM_REQS-1 : 0]                        dcache_req_if_rw,
    output wire [NUM_REQS*WORD_SIZE-1 : 0]              dcache_req_if_byteen,
    output wire [`WORD_ADDR_WIDTH*NUM_REQS-1 : 0]       dcache_req_if_addr,
    output wire [`WORD_WIDTH*NUM_REQS-1 : 0]            dcache_req_if_data,
    output wire [TAG_WIDTH*NUM_REQS-1 : 0]              dcache_req_if_tag

);
    
    wire [`NUM_WARPS-1 : 0] csr_pending;
    wire [`NUM_WARPS-1 : 0] fpu_pending;
    
    wire                            fpu_to_csr_if_write_enable;
    wire                            fpu_to_csr_if_write_fflags_NV;
    wire                            fpu_to_csr_if_write_fflags_DZ;
    wire                            fpu_to_csr_if_write_fflags_OF;
    wire                            fpu_to_csr_if_write_fflags_UF; 
    wire                            fpu_to_csr_if_write_fflags_NX;
    wire [`NW_BITS-1 : 0]           fpu_to_csr_if_write_wid; 
    wire [`NW_BITS-1 : 0]           fpu_to_csr_if_read_wid;
    wire [`INST_FRM_BITS-1 : 0]     fpu_to_csr_if_read_frm;
    
    
    RV_alu_unit #(
    
        .CORE_ID(CORE_ID)
        
    ) alu_unit (
    
        .clk(clk),
        .reset(reset),

        .alu_req_if_valid(alu_req_if_valid),
        .alu_req_if_uuid(alu_req_if_uuid),
        .alu_req_if_wid(alu_req_if_wid),
        .alu_req_if_tmask(alu_req_if_tmask),
        .alu_req_if_PC(alu_req_if_PC),
        .alu_req_if_next_PC(alu_req_if_next_PC),
        .alu_req_if_op_type(alu_req_if_op_type),
        .alu_req_if_op_mod(alu_req_if_op_mod),
        .alu_req_if_use_PC(alu_req_if_use_PC),
        .alu_req_if_use_imm(alu_req_if_use_imm),
        .alu_req_if_imm(alu_req_if_imm),
        .alu_req_if_tid(alu_req_if_tid),
        .alu_req_if_rs1_data(alu_req_if_rs1_data),
        .alu_req_if_rs2_data(alu_req_if_rs2_data),
        .alu_req_if_rd(alu_req_if_rd),
        .alu_req_if_wb(alu_req_if_wb),
        .alu_req_if_ready(alu_req_if_ready),
        
        .branch_ctl_if_valid(branch_ctl_if_valid),
        .branch_ctl_if_wid(branch_ctl_if_wid),
        .branch_ctl_if_taken(branch_ctl_if_taken),
        .branch_ctl_if_dest(branch_ctl_if_dest),

        .alu_commit_if_valid(alu_commit_if_valid),
        .alu_commit_if_uuid(alu_commit_if_uuid),
        .alu_commit_if_wid(alu_commit_if_wid),
        .alu_commit_if_tmask(alu_commit_if_tmask),
        .alu_commit_if_PC(alu_commit_if_PC),
        .alu_commit_if_data(alu_commit_if_data),
        .alu_commit_if_rd(alu_commit_if_rd),
        .alu_commit_if_wb(alu_commit_if_wb),
        .alu_commit_if_eop(alu_commit_if_eop),
        .alu_commit_if_ready(alu_commit_if_ready)
        
    );
    
    

    RV_lsu_unit #(

        .NUM_REQS(NUM_REQS),
        .TAG_WIDTH(TAG_WIDTH),
        .WORD_SIZE(WORD_SIZE),
        .CORE_ID(CORE_ID)
        
    ) lsu_unit (

        .clk(clk),
        .reset(reset),

        .dc_req_valid(dcache_req_if_valid),
        .dc_req_rw(dcache_req_if_rw),
        .dc_req_byteen(dcache_req_if_byteen),
        .dc_req_addr(dcache_req_if_addr),
        .dc_req_data(dcache_req_if_data),
        .dc_req_tag(dcache_req_if_tag),
        .dc_req_ready(dcache_req_if_ready),

        .dc_res_valid(dcache_rsp_if_valid),
        .dc_res_tmask(dcache_rsp_if_tmask),
        .dc_res_data(dcache_rsp_if_data),
        .dc_res_tag(dcache_rsp_if_tag),
        .dc_res_ready(dcache_rsp_if_ready),     


        .lsu_req_valid(lsu_req_if_valid),
        .lsu_req_uuid(lsu_req_if_uuid),
        .lsu_req_wid(lsu_req_if_wid),
        .lsu_req_tmask(lsu_req_if_tmask),
        .lsu_req_PC(lsu_req_if_PC),
        .lsu_req_op_type(lsu_req_if_op_type),
        .lsu_req_is_fence(lsu_req_if_is_fence),
        .lsu_req_store_data(lsu_req_if_store_data),
        .lsu_req_base_addr(lsu_req_if_base_addr),
        .lsu_req_offset(lsu_req_if_offset),
        .lsu_req_rd(lsu_req_if_rd),
        .lsu_req_wb(lsu_req_if_wb),
        .lsu_req_is_prefetch(lsu_req_if_is_prefetch),
        .lsu_req_ready(lsu_req_if_ready),

        .ld_commit_valid(ld_commit_if_valid),
        .ld_commit_uuid (ld_commit_if_uuid),
        .ld_commit_wid(ld_commit_if_wid),
        .ld_commit_tmask(ld_commit_if_tmask),
        .ld_commit_PC(ld_commit_if_PC),
        .ld_commit_data(ld_commit_if_data),
        .ld_commit_rd(ld_commit_if_rd),
        .ld_commit_wb(ld_commit_if_wb),
        .ld_commit_eop(ld_commit_if_eop),
        .ld_commit_ready(ld_commit_if_ready),

        .str_commit_valid(st_commit_if_valid),
        .str_commit_uuid (st_commit_if_uuid),
        .str_commit_wid(st_commit_if_wid),
        .str_commit_tmask(st_commit_if_tmask),
        .str_commit_PC(st_commit_if_PC),
        .str_commit_data(st_commit_if_data),
        .str_commit_rd(st_commit_if_rd),
        .str_commit_wb(st_commit_if_wb),
        .str_commit_eop(st_commit_if_eop),
        .str_commit_ready(st_commit_if_ready)
        
    );

     
    RV_csr_unit #(
    
        .CORE_ID(CORE_ID)
        
    ) csr_unit (
    
        .clk            (clk),
        .reset          (reset),  


        .cmt_to_csr_if_valid(cmt_to_csr_if_valid),   
        .cmt_to_csr_if_commit_size(cmt_to_csr_if_commit_size),

        .fetch_to_csr_if_thread_masks(fetch_to_csr_if_thread_masks),

        .csr_req_if_valid(csr_req_if_valid),
        .csr_req_if_uuid(csr_req_if_uuid),
        .csr_req_if_wid(csr_req_if_wid),
        .csr_req_if_tmask(csr_req_if_tmask),
        .csr_req_if_PC(csr_req_if_PC),
        .csr_req_if_op_type(csr_req_if_op_type),
        .csr_req_if_addr(csr_req_if_addr),
        .csr_req_if_rs1_data(csr_req_if_rs1_data),
        .csr_req_if_use_imm(csr_req_if_use_imm),
        .csr_req_if_imm(csr_req_if_imm),
        .csr_req_if_rd(csr_req_if_rd),
        .csr_req_if_wb(csr_req_if_wb),    
        .csr_req_if_ready(csr_req_if_ready),

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
        
        .fpu_to_csr_if_write_enable(fpu_to_csr_if_write_enable),
        .fpu_to_csr_if_write_wid(fpu_to_csr_if_write_wid),
      
        .fpu_to_csr_if_write_fflags_NV(fpu_to_csr_if_write_fflags_NV), 
        .fpu_to_csr_if_write_fflags_DZ(fpu_to_csr_if_write_fflags_DZ), 
        .fpu_to_csr_if_write_fflags_OF(fpu_to_csr_if_write_fflags_OF), 
        .fpu_to_csr_if_write_fflags_UF(fpu_to_csr_if_write_fflags_UF), 
        .fpu_to_csr_if_write_fflags_NX(fpu_to_csr_if_write_fflags_NX), 

        .fpu_to_csr_if_read_wid(fpu_to_csr_if_read_wid),
        .fpu_to_csr_if_read_frm(fpu_to_csr_if_read_frm),


        .fpu_pending(fpu_pending),
        .pending(csr_pending),
        .busy(busy)
        
    );
    
    
    RV_fpu_unit #(
    
        .CORE_ID(CORE_ID)
        
    ) fpu_unit (
        .clk            (clk),
        .reset          (reset),

        .fpu_req_if_valid(fpu_req_if_valid),
        .fpu_req_if_uuid(fpu_req_if_uuid),
        .fpu_req_if_wid(fpu_req_if_wid),
        .fpu_req_if_tmask(fpu_req_if_tmask),
        .fpu_req_if_PC(fpu_req_if_PC),
        .fpu_req_if_op_type(fpu_req_if_op_type),
        .fpu_req_if_op_mod(fpu_req_if_op_mod),
        .fpu_req_if_rs1_data(fpu_req_if_rs1_data),
        .fpu_req_if_rs2_data(fpu_req_if_rs2_data),
        .fpu_req_if_rs3_data(fpu_req_if_rs3_data),
        .fpu_req_if_rd(fpu_req_if_rd),
        .fpu_req_if_wb(fpu_req_if_wb),
        .fpu_req_if_ready(fpu_req_if_ready),
        
        .fpu_to_csr_if_write_enable(fpu_to_csr_if_write_enable),
        .fpu_to_csr_if_write_wid(fpu_to_csr_if_write_wid),
        .fpu_to_csr_if_write_fflags_NV(fpu_to_csr_if_write_fflags_NV),
        .fpu_to_csr_if_write_fflags_DZ(fpu_to_csr_if_write_fflags_DZ),
        .fpu_to_csr_if_write_fflags_OF(fpu_to_csr_if_write_fflags_OF),
        .fpu_to_csr_if_write_fflags_UF(fpu_to_csr_if_write_fflags_UF),
        .fpu_to_csr_if_write_fflags_NX(fpu_to_csr_if_write_fflags_NX),
        .fpu_to_csr_if_read_wid(fpu_to_csr_if_read_wid),
        .fpu_to_csr_if_read_frm(fpu_to_csr_if_read_frm),

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

        .csr_pending    (csr_pending),
        .pending        (fpu_pending) 
        
    );
    
    
    RV_gpu_unit #(

        .CORE_ID(CORE_ID)
        
    ) gpu_unit (

        .clk            (clk),
        .reset          (reset),    

        .gpu_req_if_valid(gpu_req_if_valid),
        .gpu_req_if_uuid(gpu_req_if_uuid),
        .gpu_req_if_wid(gpu_req_if_wid),
        .gpu_req_if_tmask(gpu_req_if_tmask),
        .gpu_req_if_PC(gpu_req_if_PC),
        .gpu_req_if_next_PC(gpu_req_if_next_PC),
        .gpu_req_if_op_type(gpu_req_if_op_type),
        .gpu_req_if_op_mod(gpu_req_if_op_mod),
        .gpu_req_if_tid(gpu_req_if_tid),
        .gpu_req_if_rs1_data(gpu_req_if_rs1_data),    
        .gpu_req_if_rs2_data(gpu_req_if_rs2_data),    
        .gpu_req_if_rs3_data(gpu_req_if_rs3_data),    
        .gpu_req_if_rd(gpu_req_if_rd),
        .gpu_req_if_wb(gpu_req_if_wb),
        .gpu_req_if_ready(gpu_req_if_ready),


        .warp_ctl_if_valid(warp_ctl_if_valid),
        .warp_ctl_if_wid(warp_ctl_if_wid),

        .warp_ctl_if_tmc_valid(warp_ctl_if_tmc_valid),
        .warp_ctl_if_tmc_tmask(warp_ctl_if_tmc_tmask),
        .warp_ctl_if_wspawn_valid(warp_ctl_if_wspawn_valid),
        .warp_ctl_if_wspawn_wmask(warp_ctl_if_wspawn_wmask),
        .warp_ctl_if_wspawn_pc(warp_ctl_if_wspawn_pc),
        .warp_ctl_if_barrier_valid(warp_ctl_if_barrier_valid),
        .warp_ctl_if_barrier_id(warp_ctl_if_barrier_id),
        .warp_ctl_if_barrier_size_m1(warp_ctl_if_barrier_size_m1),
        .warp_ctl_if_split_valid(warp_ctl_if_split_valid),
        .warp_ctl_if_split_diverged(warp_ctl_if_split_diverged),
        .warp_ctl_if_split_then_tmask(warp_ctl_if_split_then_tmask),
        .warp_ctl_if_split_else_tmask(warp_ctl_if_split_else_tmask),
        .warp_ctl_if_split_pc(warp_ctl_if_split_pc),    

        .gpu_commit_if_valid(gpu_commit_if_valid),
        .gpu_commit_if_uuid(gpu_commit_if_uuid),
        .gpu_commit_if_wid(gpu_commit_if_wid),
        .gpu_commit_if_tmask(gpu_commit_if_tmask),    
        .gpu_commit_if_PC(gpu_commit_if_PC),
        .gpu_commit_if_data(gpu_commit_if_data), 
        .gpu_commit_if_rd(gpu_commit_if_rd),
        .gpu_commit_if_wb(gpu_commit_if_wb),
        .gpu_commit_if_eop(gpu_commit_if_eop),
        .gpu_commit_if_ready(gpu_commit_if_ready)
        
    );
    
    
    
endmodule
