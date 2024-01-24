`timescale 1ns / 1ps

`include "RV_define.vh"

module RV_pipeline#(

    parameter CORE_ID = 0

)(
    
    input  wire clk,
    input  wire reset,
    
    //Dcache core response
    input  wire [`NUM_THREADS-1 : 0]                 dcache_req_ready,
    input  wire                                      dcache_rsp_valid,
    input  wire [`NUM_THREADS-1 : 0]                 dcache_rsp_tmask,
    input  wire [(`NUM_THREADS*32)-1 : 0]            dcache_rsp_data,
    input  wire [`DCACHE_CORE_TAG_WIDTH-1 : 0]       dcache_rsp_tag,
    
    //Icache core response  
    input  wire                                      icache_req_ready,
    input  wire                                      icache_rsp_valid,
    input  wire [31 : 0]                             icache_rsp_data,
    input  wire [`ICACHE_CORE_TAG_WIDTH-1 : 0]       icache_rsp_tag,
    
    //Dcache core request
    output wire [`NUM_THREADS-1 : 0]                 dcache_req_valid,
    output wire [`NUM_THREADS-1 : 0]                 dcache_req_rw,
    output wire [(`NUM_THREADS*4)-1 : 0]             dcache_req_byteen,
    output wire [(`NUM_THREADS*30)-1 : 0]            dcache_req_addr,
    output wire [(`NUM_THREADS*32)-1 : 0]            dcache_req_data,
    output wire [(`DCACHE_CORE_TAG_WIDTH*32)-1 : 0]  dcache_req_tag,
    output wire                                      dcache_rsp_ready,
    
    // Icache core request
    output wire                                      icache_req_valid,
    output wire [29 : 0]                             icache_req_addr,
    output wire [`ICACHE_CORE_TAG_WIDTH-1 : 0]       icache_req_tag,
    output wire                                      icache_rsp_ready,
    
    output wire                                      busy
    
);

    //
    // Dcache request
    //

    localparam DCACHE_NUM_REQS  = `NUM_THREADS;
    localparam DCACHE_WORD_SIZE = 4;
    localparam DCACHE_TAG_WIDTH = `DCACHE_CORE_TAG_WIDTH;
    
    wire [DCACHE_NUM_REQS-1 : 0]                                  dcache_req_if_valid;
    wire [DCACHE_NUM_REQS-1 : 0]                                  dcache_req_if_rw;
    wire [(DCACHE_NUM_REQS*DCACHE_WORD_SIZE)-1 : 0]               dcache_req_if_byteen;
    wire [(DCACHE_NUM_REQS*(32-$clog2(DCACHE_WORD_SIZE)))-1 : 0]  dcache_req_if_addr;
    wire [(DCACHE_NUM_REQS*(8*DCACHE_WORD_SIZE))-1 : 0]           dcache_req_if_data;
    wire [(DCACHE_NUM_REQS*DCACHE_TAG_WIDTH)-1 : 0]               dcache_req_if_tag;
    wire [DCACHE_NUM_REQS-1 : 0]                                  dcache_req_if_ready;
    
    assign dcache_req_valid    = dcache_req_if_valid;
    assign dcache_req_rw       = dcache_req_if_rw;
    assign dcache_req_byteen   = dcache_req_if_byteen;
    assign dcache_req_addr     = dcache_req_if_addr;
    assign dcache_req_data     = dcache_req_if_data;
    assign dcache_req_tag      = dcache_req_if_tag;
    assign dcache_req_if_ready = dcache_req_ready;
    
    
    //
    // Dcache response
    //
    
    wire                                                         dcache_rsp_if_valid;
    wire [DCACHE_NUM_REQS-1 : 0]                                 dcache_rsp_if_tmask;
    wire [(DCACHE_NUM_REQS*(8*DCACHE_WORD_SIZE))-1 : 0]          dcache_rsp_if_data;
    wire [DCACHE_TAG_WIDTH-1 : 0]                                dcache_rsp_if_tag;
    wire                                                         dcache_rsp_if_ready;
    
    assign dcache_rsp_if_valid = dcache_rsp_valid;
    assign dcache_rsp_if_tmask = dcache_rsp_tmask;
    assign dcache_rsp_if_data  = dcache_rsp_data;
    assign dcache_rsp_if_tag   = dcache_rsp_tag;
    assign dcache_rsp_ready    = dcache_rsp_if_ready;
    
    //
    // Icache request
    //

    localparam ICACHE_WORD_SIZE = 4;
    localparam ICACHE_TAG_WIDTH = `ICACHE_CORE_TAG_WIDTH;
    
    wire                                         icache_req_if_valid;
    wire [(32-$clog2(ICACHE_WORD_SIZE))-1 : 0]   icache_req_if_addr;
    wire [ICACHE_TAG_WIDTH-1 : 0]                icache_req_if_tag;    
    wire                                         icache_req_if_ready;   
    
    assign icache_req_valid    = icache_req_if_valid;
    assign icache_req_addr     = icache_req_if_addr;
    assign icache_req_tag      = icache_req_if_tag;
    assign icache_req_if_ready = icache_req_ready;
    
    //
    // Icache response
    //
    
    wire                               icache_rsp_if_valid;    
    wire [(8*ICACHE_WORD_SIZE)-1 : 0]  icache_rsp_if_data;
    wire [ICACHE_TAG_WIDTH-1 : 0]      icache_rsp_if_tag;    
    wire                               icache_rsp_if_ready;   
    
    assign icache_rsp_if_valid = icache_rsp_valid;
    assign icache_rsp_if_data  = icache_rsp_data;
    assign icache_rsp_if_tag   = icache_rsp_tag;
    assign icache_rsp_ready    = icache_rsp_if_ready;
    
    
    //Fetch to CSR
    wire                                    cmt_to_csr_if_valid;
    wire [(`NUM_WARPS*`NUM_THREADS)-1 : 0]  fetch_to_csr_if_thread_masks;
    wire [$clog2(6*`NUM_THREADS+1)-1 : 0]   cmt_to_csr_if_commit_size;
    
    //RV_decode signals
    wire                          decode_if_valid;    
    wire [`UUID_BITS-1 : 0]       decode_if_uuid;
    wire [`NW_BITS-1 : 0]         decode_if_wid;
    wire [`NUM_THREADS-1 : 0]     decode_if_tmask;
    wire [31 : 0]                 decode_if_PC;
    wire [`EX_BITS-1 : 0]         decode_if_ex_type;    
    wire [`INST_OP_BITS-1 : 0]    decode_if_op_type; 
    wire [`INST_MOD_BITS-1 : 0]   decode_if_op_mod;    
    wire                          decode_if_wb;
    wire                          decode_if_use_PC;
    wire                          decode_if_use_imm;
    wire [31 : 0]                 decode_if_imm;
    wire [`NR_BITS-1 : 0]         decode_if_rd;
    wire [`NR_BITS-1 : 0]         decode_if_rs1;
    wire [`NR_BITS-1 : 0]         decode_if_rs2;
    wire [`NR_BITS-1 : 0]         decode_if_rs3;
    wire                          decode_if_ready;
    
    //Branch Control Signals
    wire                      branch_ctl_if_valid;    
    wire [`NW_BITS-1 : 0]     branch_ctl_if_wid;
    wire                      branch_ctl_if_taken;
    wire [31 : 0]             branch_ctl_if_dest;
    
    //Warp Control Signals
    wire                      warp_ctl_if_valid;
    wire [`NW_BITS-1 : 0]     warp_ctl_if_wid;

    wire                      warp_ctl_if_tmc_valid;              
    wire [`NUM_THREADS-1 : 0] warp_ctl_if_tmc_tmask;              
                  
    wire                      warp_ctl_if_wspawn_valid;           
    wire [`NUM_WARPS-1 : 0]   warp_ctl_if_wspawn_wmask;          
    wire [31 : 0]             warp_ctl_if_wspawn_pc;           

    wire                      warp_ctl_if_barrier_valid;        
    wire [`NB_BITS-1 : 0]     warp_ctl_if_barrier_id;        
    wire [`NW_BITS-1 : 0]     warp_ctl_if_barrier_size_m1;        
      
    wire                      warp_ctl_if_split_valid;
    wire                      warp_ctl_if_split_diverged;
    wire [`NUM_THREADS-1 : 0] warp_ctl_if_split_then_tmask; 
    wire [`NUM_THREADS-1 : 0] warp_ctl_if_split_else_tmask;  
    wire [31 : 0]             warp_ctl_if_split_pc;
    
    //Instruction Fetch Signals
    wire                      ifetch_rsp_if_valid;
    wire [`UUID_BITS-1 : 0]   ifetch_rsp_if_uuid;
    wire [`NUM_THREADS-1 : 0] ifetch_rsp_if_tmask;    
    wire [`NW_BITS-1 : 0]     ifetch_rsp_if_wid;
    wire [31 : 0]             ifetch_rsp_if_PC;
    wire [31 : 0]             ifetch_rsp_if_data;
    wire                      ifetch_rsp_if_ready;
    
    //ALU Signals
    wire                              alu_req_if_valid;
    wire [`UUID_BITS-1 : 0]           alu_req_if_uuid;
    wire [`NW_BITS-1 : 0]             alu_req_if_wid;
    wire [`NUM_THREADS-1 : 0]         alu_req_if_tmask;
    wire [31 : 0]                     alu_req_if_PC;
    wire [31 : 0]                     alu_req_if_next_PC;
    wire [`INST_ALU_BITS-1 : 0]       alu_req_if_op_type;
    wire [`INST_MOD_BITS-1 : 0]       alu_req_if_op_mod;
    wire                              alu_req_if_use_PC;
    wire                              alu_req_if_use_imm;
    wire [31 : 0]                     alu_req_if_imm;
    wire [`NT_BITS-1 : 0]             alu_req_if_tid;
    wire [(`NUM_THREADS*32)-1 : 0]    alu_req_if_rs1_data;
    wire [(`NUM_THREADS*32)-1 : 0]    alu_req_if_rs2_data;
    wire [`NR_BITS-1 : 0]             alu_req_if_rd;
    wire                              alu_req_if_wb;
    wire                              alu_req_if_ready;
    
    //LSU Signals
    wire                              lsu_req_if_valid;
    wire [`UUID_BITS-1 : 0]           lsu_req_if_uuid;
    wire [`NW_BITS-1 : 0]             lsu_req_if_wid;
    wire [`NUM_THREADS-1 : 0]         lsu_req_if_tmask;
    wire [31 : 0]                     lsu_req_if_PC;
    wire [`INST_LSU_BITS-1 : 0]       lsu_req_if_op_type;
    wire                              lsu_req_if_is_fence;
    wire [(`NUM_THREADS*32)-1 : 0]    lsu_req_if_store_data;
    wire [(`NUM_THREADS*32)-1 : 0]    lsu_req_if_base_addr;
    wire [31 : 0]                     lsu_req_if_offset;
    wire [`NR_BITS-1 : 0]             lsu_req_if_rd;
    wire                              lsu_req_if_wb;
    wire                              lsu_req_if_ready;
    wire                              lsu_req_if_is_prefetch;
    
    //CSR signals
    wire                          csr_req_if_valid;
    wire [`UUID_BITS-1 : 0]       csr_req_if_uuid;
    wire [`NW_BITS-1 : 0]         csr_req_if_wid;
    wire [`NUM_THREADS-1 : 0]     csr_req_if_tmask;
    wire [31 : 0]                 csr_req_if_PC;
    wire [`INST_CSR_BITS-1 : 0]   csr_req_if_op_type;
    wire [`CSR_ADDR_BITS-1 : 0]   csr_req_if_addr;
    wire [31 : 0]                 csr_req_if_rs1_data;
    wire                          csr_req_if_use_imm;
    wire [`NRI_BITS-1 : 0]        csr_req_if_imm;
    wire [`NR_BITS-1 : 0]         csr_req_if_rd;
    wire                          csr_req_if_wb;
    wire                          csr_req_if_ready;
    
    //FPU Signals
    wire                              fpu_req_if_valid;
    wire [`UUID_BITS-1 : 0]           fpu_req_if_uuid;
    wire [`NW_BITS-1 : 0]             fpu_req_if_wid;
    wire [`NUM_THREADS-1 : 0]         fpu_req_if_tmask;
    wire [31 : 0]                     fpu_req_if_PC;
    wire [`INST_FPU_BITS-1 : 0]       fpu_req_if_op_type;
    wire [`INST_MOD_BITS-1 : 0]       fpu_req_if_op_mod;
    wire [(`NUM_THREADS*32)-1 : 0]    fpu_req_if_rs1_data;
    wire [(`NUM_THREADS*32)-1 : 0]    fpu_req_if_rs2_data;
    wire [(`NUM_THREADS*32)-1 : 0]    fpu_req_if_rs3_data;
    wire [`NR_BITS-1 : 0]             fpu_req_if_rd;
    wire                              fpu_req_if_wb;
    wire                              fpu_req_if_ready;
    
    //GPU Signals
    wire                              gpu_req_if_valid;
    wire [`UUID_BITS-1 : 0]           gpu_req_if_uuid;
    wire [`NW_BITS-1 : 0]             gpu_req_if_wid;
    wire [`NUM_THREADS-1 : 0]         gpu_req_if_tmask;
    wire [31 : 0]                     gpu_req_if_PC;
    wire [31 : 0]                     gpu_req_if_next_PC;
    wire [`INST_GPU_BITS-1 : 0]       gpu_req_if_op_type;
    wire [`INST_MOD_BITS-1 : 0]       gpu_req_if_op_mod;
    wire [`NT_BITS-1 : 0]             gpu_req_if_tid;
    wire [(`NUM_THREADS*32)-1 : 0]    gpu_req_if_rs1_data;
    wire [(`NUM_THREADS*32)-1 : 0]    gpu_req_if_rs2_data;
    wire [(`NUM_THREADS*32)-1 : 0]    gpu_req_if_rs3_data;
    wire [`NR_BITS-1 : 0]             gpu_req_if_rd;
    wire                              gpu_req_if_wb;
    wire                              gpu_req_if_ready;
    
    //Writeback Signals
    wire                              writeback_if_valid;
    wire [`UUID_BITS-1 : 0]           writeback_if_uuid;
    wire [`NUM_THREADS-1 : 0]         writeback_if_tmask;
    wire [`NW_BITS-1 : 0]             writeback_if_wid;
    wire [31 : 0]                     writeback_if_PC;
    wire [`NR_BITS-1 : 0]             writeback_if_rd;
    wire [(`NUM_THREADS*32)-1 : 0]    writeback_if_data;
    wire                              writeback_if_eop;
    wire                              writeback_if_ready;
    
    //Warp Stall Signals
    wire                  wstall_if_valid;    
    wire [`NW_BITS-1 : 0] wstall_if_wid;
    wire                  wstall_if_stalled;
    
    //Join Instruction Fetch Signals
    wire                  join_if_valid;
    wire [`NW_BITS-1 : 0] join_if_wid;
    
    //ALU Commit Signals
    wire                              alu_commit_if_valid;
    wire [`UUID_BITS-1 : 0]           alu_commit_if_uuid;
    wire [`NW_BITS-1 : 0]             alu_commit_if_wid;
    wire [`NUM_THREADS-1 : 0]         alu_commit_if_tmask;    
    wire [31 : 0]                     alu_commit_if_PC;
    wire [(`NUM_THREADS*32)-1 : 0]    alu_commit_if_data;
    wire [`NR_BITS-1 : 0]             alu_commit_if_rd;
    wire                              alu_commit_if_wb;
    wire                              alu_commit_if_eop;
    wire                              alu_commit_if_ready;
    
    //Load Commit Signals
    wire                              ld_commit_if_valid;
    wire [`UUID_BITS-1 : 0]           ld_commit_if_uuid;
    wire [`NW_BITS-1 : 0]             ld_commit_if_wid;
    wire [`NUM_THREADS-1 : 0]         ld_commit_if_tmask;    
    wire [31 : 0]                     ld_commit_if_PC;
    wire [(`NUM_THREADS*32)-1 : 0]    ld_commit_if_data;
    wire [`NR_BITS-1 : 0]             ld_commit_if_rd;
    wire                              ld_commit_if_wb;
    wire                              ld_commit_if_eop;
    wire                              ld_commit_if_ready;
    
    //Store Commit Signals
    wire                              st_commit_if_valid;
    wire [`UUID_BITS-1 : 0]           st_commit_if_uuid;
    wire [`NW_BITS-1 : 0]             st_commit_if_wid;
    wire [`NUM_THREADS-1 : 0]         st_commit_if_tmask;    
    wire [31 : 0]                     st_commit_if_PC;
    wire [(`NUM_THREADS*32)-1 : 0]    st_commit_if_data;
    wire [`NR_BITS-1 : 0]             st_commit_if_rd;
    wire                              st_commit_if_wb;
    wire                              st_commit_if_eop;
    wire                              st_commit_if_ready;
    
    //CSR Commit Signals
    wire                              csr_commit_if_valid;
    wire [`UUID_BITS-1 : 0]           csr_commit_if_uuid;
    wire [`NW_BITS-1 : 0]             csr_commit_if_wid;
    wire [`NUM_THREADS-1 : 0]         csr_commit_if_tmask;    
    wire [31 : 0]                     csr_commit_if_PC;
    wire [(`NUM_THREADS*32)-1 : 0]    csr_commit_if_data;
    wire [`NR_BITS-1 : 0]             csr_commit_if_rd;
    wire                              csr_commit_if_wb;
    wire                              csr_commit_if_eop;
    wire                              csr_commit_if_ready;
    
    //FPU Commit Signals
    wire                              fpu_commit_if_valid;
    wire [`UUID_BITS-1 : 0]           fpu_commit_if_uuid;
    wire [`NW_BITS-1 : 0]             fpu_commit_if_wid;
    wire [`NUM_THREADS-1 : 0]         fpu_commit_if_tmask;    
    wire [31 : 0]                     fpu_commit_if_PC;
    wire [(`NUM_THREADS*32)-1 : 0]    fpu_commit_if_data;
    wire [`NR_BITS-1 : 0]             fpu_commit_if_rd;
    wire                              fpu_commit_if_wb;
    wire                              fpu_commit_if_eop;
    wire                              fpu_commit_if_ready;
    
    //GPU Commit Signals
    wire                              gpu_commit_if_valid;
    wire [`UUID_BITS-1 : 0]           gpu_commit_if_uuid;
    wire [`NW_BITS-1 : 0]             gpu_commit_if_wid;
    wire [`NUM_THREADS-1 : 0]         gpu_commit_if_tmask;    
    wire [31 : 0]                     gpu_commit_if_PC;
    wire [(`NUM_THREADS*32)-1 : 0]    gpu_commit_if_data;
    wire [`NR_BITS-1:0]               gpu_commit_if_rd;
    wire                              gpu_commit_if_wb;
    wire                              gpu_commit_if_eop;
    wire                              gpu_commit_if_ready;   
    
    
    RV_fetch #(
    
        .CORE_ID(CORE_ID),
        .WORD_SIZE (4), 
        .TAG_WIDTH (`ICACHE_CORE_TAG_WIDTH)
        
    ) fetch (

        .clk(clk),
        .reset(reset),


        .icache_req_if_valid(icache_req_if_valid),
        .icache_req_if_addr(icache_req_if_addr),
        .icache_req_if_tag(icache_req_if_tag),
        .icache_req_if_ready(icache_req_if_ready),


        .icache_rsp_if_valid(icache_rsp_if_valid),
        .icache_rsp_if_data(icache_rsp_if_data),
        .icache_rsp_if_tag(icache_rsp_if_tag),
        .icache_rsp_if_ready(icache_rsp_if_ready),


        .wstall_if_valid(wstall_if_valid),
        .wstall_if_wid(wstall_if_wid),
        .wstall_if_stalled(wstall_if_stalled),


        .join_if_valid(join_if_valid),
        .join_if_wid(join_if_wid),


        .branch_ctl_if_valid(branch_ctl_if_valid),
        .branch_ctl_if_wid(branch_ctl_if_wid),
        .branch_ctl_if_taken(branch_ctl_if_taken),
        .branch_ctl_if_dest(branch_ctl_if_dest),


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


        .ifetch_rsp_if_valid(ifetch_rsp_if_valid),
        .ifetch_rsp_if_uuid(ifetch_rsp_if_uuid),
        .ifetch_rsp_if_tmask(ifetch_rsp_if_tmask),
        .ifetch_rsp_if_wid(ifetch_rsp_if_wid),
        .ifetch_rsp_if_PC(ifetch_rsp_if_PC),
        .ifetch_rsp_if_data(ifetch_rsp_if_data),
        .ifetch_rsp_if_ready(ifetch_rsp_if_ready),


        .fetch_to_csr_if_thread_masks(fetch_to_csr_if_thread_masks),
        .busy(busy)
        
    );
    
    RV_decode #(
    
        .CORE_ID(CORE_ID)
        
    ) decode (
    
        .clk(clk),
        .reset(reset),        
       
        // inputs
        .ifetch_rsp_if_valid_i(ifetch_rsp_if_valid),
        .ifetch_rsp_if_uuid_i(ifetch_rsp_if_uuid),
        .ifetch_rsp_if_tmask_i(ifetch_rsp_if_tmask),    
        .ifetch_rsp_if_wid_i(ifetch_rsp_if_wid),
        .ifetch_rsp_if_PC_i(ifetch_rsp_if_PC),
        .ifetch_rsp_if_data_i(ifetch_rsp_if_data),
        .ifetch_rsp_if_ready_o(ifetch_rsp_if_ready),
    
    
        // outputs      
        .decode_if_valid_o(decode_if_valid),    
        .decode_if_uuid_o(decode_if_uuid),
        .decode_if_wid_o(decode_if_wid),
        .decode_if_tmask_o(decode_if_tmask),
        .decode_if_PC_o(decode_if_PC),
        .decode_if_ex_type_o(decode_if_ex_type),    
        .decode_if_op_type_o(decode_if_op_type), 
        .decode_if_op_mod_o(decode_if_op_mod),    
        .decode_if_wb_o(decode_if_wb),
        .decode_if_use_PC_o(decode_if_use_PC),
        .decode_if_use_imm_o(decode_if_use_imm),
        .decode_if_imm_o(decode_if_imm),
        .decode_if_rd_o(decode_if_rd),
        .decode_if_rs1_o(decode_if_rs1),
        .decode_if_rs2_o(decode_if_rs2),
        .decode_if_rs3_o(decode_if_rs3),
        .decode_if_ready_i(decode_if_ready),
    
        .wstall_if_valid_o(wstall_if_valid),    
        .wstall_if_wid_o(wstall_if_wid),
        .wstall_if_stalled_o(wstall_if_stalled),
    
        .join_if_valid_o(join_if_valid),
        .join_if_wid_o(join_if_wid)
        
    );
    
    RV_issue #(
    
        .CORE_ID(CORE_ID)
    
    ) issue (

        .clk(clk),
        .reset(reset),

        .decode_if_valid(decode_if_valid),
        .decode_if_uuid(decode_if_uuid),
        .decode_if_wid(decode_if_wid),
        .decode_if_tmask(decode_if_tmask),
        .decode_if_PC(decode_if_PC),
        .decode_if_ex_type(decode_if_ex_type),
        .decode_if_op_type(decode_if_op_type),
        .decode_if_op_mod(decode_if_op_mod),
        .decode_if_wb(decode_if_wb),
        .decode_if_use_PC(decode_if_use_PC),
        .decode_if_use_imm(decode_if_use_imm),
        .decode_if_imm(decode_if_imm),
        .decode_if_rd(decode_if_rd),
        .decode_if_rs1(decode_if_rs1),
        .decode_if_rs2(decode_if_rs2),
        .decode_if_rs3(decode_if_rs3),
        .decode_if_ready(decode_if_ready),

        .writeback_if_valid(writeback_if_valid),
        .writeback_if_uuid(writeback_if_uuid),
        .writeback_if_tmask(writeback_if_tmask),
        .writeback_if_wid(writeback_if_wid),
        .writeback_if_PC(writeback_if_PC),
        .writeback_if_rd(writeback_if_rd),
        .writeback_if_data(writeback_if_data),
        .writeback_if_eop(writeback_if_eop),
        .writeback_if_ready(writeback_if_ready),

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

        .lsu_req_if_valid(lsu_req_if_valid),
        .lsu_req_if_uuid(lsu_req_if_uuid),
        .lsu_req_if_wid(lsu_req_if_wid),
        .lsu_req_if_tmask(lsu_req_if_tmask),
        .lsu_req_if_PC(lsu_req_if_PC),
        .lsu_req_if_op_type(lsu_req_if_op_type),
        .lsu_req_if_is_fence(lsu_req_if_is_fence),
        .lsu_req_if_store_data(lsu_req_if_store_data),
        .lsu_req_if_base_addr(lsu_req_if_base_addr),
        .lsu_req_if_offset(lsu_req_if_offset),
        .lsu_req_if_rd(lsu_req_if_rd),
        .lsu_req_if_wb(lsu_req_if_wb),
        .lsu_req_if_is_prefetch(lsu_req_if_is_prefetch),
        .lsu_req_if_ready(lsu_req_if_ready),

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
        .gpu_req_if_ready(gpu_req_if_ready)
        
    );
    
    
    RV_execute #(
    
        .CORE_ID(CORE_ID),
        .NUM_REQS(DCACHE_NUM_REQS),
        .WORD_SIZE(DCACHE_WORD_SIZE),
        .TAG_WIDTH(DCACHE_TAG_WIDTH)
        
    ) execute (
            
        .clk(clk),
        .reset(reset),

        .dcache_req_if_valid(dcache_req_if_valid),
        .dcache_req_if_rw(dcache_req_if_rw),
        .dcache_req_if_byteen(dcache_req_if_byteen),
        .dcache_req_if_addr(dcache_req_if_addr),
        .dcache_req_if_data(dcache_req_if_data),
        .dcache_req_if_tag(dcache_req_if_tag),
        .dcache_req_if_ready(dcache_req_if_ready),

        .dcache_rsp_if_valid(dcache_rsp_if_valid),
        .dcache_rsp_if_tmask(dcache_rsp_if_tmask),
        .dcache_rsp_if_data(dcache_rsp_if_data),
        .dcache_rsp_if_tag(dcache_rsp_if_tag),
        .dcache_rsp_if_ready(dcache_rsp_if_ready),

        .cmt_to_csr_if_valid(cmt_to_csr_if_valid),
        .cmt_to_csr_if_commit_size(cmt_to_csr_if_commit_size),

        .fetch_to_csr_if_thread_masks(fetch_to_csr_if_thread_masks),
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

        .lsu_req_if_valid(lsu_req_if_valid),
        .lsu_req_if_uuid(lsu_req_if_uuid),
        .lsu_req_if_wid(lsu_req_if_wid),
        .lsu_req_if_tmask(lsu_req_if_tmask),
        .lsu_req_if_PC(lsu_req_if_PC),
        .lsu_req_if_op_type(lsu_req_if_op_type),
        .lsu_req_if_is_fence(lsu_req_if_is_fence),
        .lsu_req_if_store_data(lsu_req_if_store_data),
        .lsu_req_if_base_addr(lsu_req_if_base_addr),
        .lsu_req_if_offset(lsu_req_if_offset),
        .lsu_req_if_rd(lsu_req_if_rd),
        .lsu_req_if_wb(lsu_req_if_wb),
        .lsu_req_if_ready(lsu_req_if_ready),
        .lsu_req_if_is_prefetch(lsu_req_if_is_prefetch),

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

        .branch_ctl_if_valid(branch_ctl_if_valid),
        .branch_ctl_if_wid(branch_ctl_if_wid),
        .branch_ctl_if_taken(branch_ctl_if_taken),
        .branch_ctl_if_dest(branch_ctl_if_dest),

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

        .st_commit_if_valid(st_commit_if_valid),
        .st_commit_if_uuid(st_commit_if_uuid),
        .st_commit_if_wid(st_commit_if_wid),
        .st_commit_if_tmask(st_commit_if_tmask),
        .st_commit_if_PC(st_commit_if_PC),
        .st_commit_if_data(st_commit_if_data),
        .st_commit_if_rd(st_commit_if_rd),
        .st_commit_if_wb(st_commit_if_wb),
        .st_commit_if_eop(st_commit_if_eop),
        .st_commit_if_ready(st_commit_if_ready),

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

        .busy(busy)
        
    );  
    
    
    RV_commit #(
    
        .CORE_ID(CORE_ID)
        
    ) commit (
    
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

        .st_commit_if_valid(st_commit_if_valid),
        .st_commit_if_uuid(st_commit_if_uuid),
        .st_commit_if_wid(st_commit_if_wid),
        .st_commit_if_tmask(st_commit_if_tmask),
        .st_commit_if_PC(st_commit_if_PC),
        .st_commit_if_data(st_commit_if_data),
        .st_commit_if_rd(st_commit_if_rd),
        .st_commit_if_wb(st_commit_if_wb),
        .st_commit_if_eop(st_commit_if_eop),
        .st_commit_if_ready(st_commit_if_ready),
        
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
        .writeback_if_ready(writeback_if_ready),

        .cmt_to_csr_if_valid(cmt_to_csr_if_valid),
        .cmt_to_csr_if_commit_size(cmt_to_csr_if_commit_size)
        
    );
    
    
endmodule
