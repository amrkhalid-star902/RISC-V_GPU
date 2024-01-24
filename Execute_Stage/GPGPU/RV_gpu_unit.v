`timescale 1ns / 1ps

`include "RV_define.vh"

module RV_gpu_unit#(

    parameter CORE_ID = 0

)(

    input wire clk,
    input wire reset,
    
    input  wire                                gpu_req_if_valid,
    input  wire [`UUID_BITS-1 : 0]             gpu_req_if_uuid,
    input  wire [`NW_BITS-1 : 0]               gpu_req_if_wid,
    input  wire [`NUM_THREADS-1 : 0]           gpu_req_if_tmask,
    input  wire [31 : 0]                       gpu_req_if_PC,
    input  wire [31 : 0]                       gpu_req_if_next_PC,
    input  wire [`INST_GPU_BITS-1 : 0]         gpu_req_if_op_type,
    input  wire [`INST_MOD_BITS-1 : 0]         gpu_req_if_op_mod,
    input  wire [`NT_BITS-1 : 0]               gpu_req_if_tid,
    input  wire [(`NUM_THREADS * 32) - 1 : 0]  gpu_req_if_rs1_data,
    input  wire [(`NUM_THREADS * 32) - 1 : 0]  gpu_req_if_rs2_data,
    input  wire [(`NUM_THREADS * 32) - 1 : 0]  gpu_req_if_rs3_data,
    input  wire [`NR_BITS-1 : 0]               gpu_req_if_rd,
    input  wire                                gpu_req_if_wb,
    input  wire                                gpu_commit_if_ready,
    
    output wire                                gpu_req_if_ready,
    output wire                                warp_ctl_if_valid,
    output wire [`NW_BITS-1 : 0]               warp_ctl_if_wid,
    output wire                                warp_ctl_if_tmc_valid,
    output wire [`NUM_THREADS-1 : 0]           warp_ctl_if_tmc_tmask,
    output wire                                warp_ctl_if_wspawn_valid,
    output wire [`NUM_WARPS-1 : 0]             warp_ctl_if_wspawn_wmask,
    output wire [31 : 0]                       warp_ctl_if_wspawn_pc,
    output wire                                warp_ctl_if_barrier_valid,
    output wire [`NB_BITS-1 : 0]               warp_ctl_if_barrier_id,
    output wire [`NW_BITS-1 : 0]               warp_ctl_if_barrier_size_m1,
    output wire                                warp_ctl_if_split_valid,
    output wire                                warp_ctl_if_split_diverged,
    output wire [`NUM_THREADS-1 : 0]           warp_ctl_if_split_then_tmask,
    output wire [`NUM_THREADS-1 : 0]           warp_ctl_if_split_else_tmask,
    output wire [31 : 0]                       warp_ctl_if_split_pc,
    output wire                                gpu_commit_if_valid,
    output wire [`UUID_BITS-1 : 0]             gpu_commit_if_uuid,
    output wire [`NW_BITS-1 : 0]               gpu_commit_if_wid,
    output wire [`NUM_THREADS-1 : 0]           gpu_commit_if_tmask,
    output wire [31 : 0]                       gpu_commit_if_PC,
    output wire [(`NUM_THREADS * 32) - 1 : 0]  gpu_commit_if_data,
    output wire [`NR_BITS-1 : 0]               gpu_commit_if_rd,
    output wire                                gpu_commit_if_wb,
    output wire                                gpu_commit_if_eop
    
);


    // TMC bits width consist of :
    // 1. valid (1 bit)
    // 2. tmask (NUM_Threads)
    localparam GPU_TMC_BITS      = 1 + `NUM_THREADS;
    
    // WSPAWN bits width consist of :
    // 1. valid (1 bit)
    // 2. wmask(NUM_WARPS)
    // 3. PC (32 bits)
    localparam GPU_WSPAWN_BITS   = 1 + `NUM_WARPS + 32;
    
    // Barrier bits width consist of :
    // 1. valid (1 bit)
    // 2. id (NB_BITS)
    // 3. size_m1 (NW_BITS)
    localparam GPU_BARRIER_BITS  = 1 + `NB_BITS + `NW_BITS;
    
    // Split bits width consist of :
    // 1. valid (1 bit)
    // 2. diverged (1 bit)
    // 3. then_mask (NUM_Threads)
    // 4. else mask (NUM_Threads)
    // 5. PC (32 bits)
    localparam GPU_SPLIT_BITS    = 1 + 1 + `NUM_THREADS + `NUM_THREADS + 32;
    
    //Warp control data width
    localparam WCTL_DATAW        = GPU_TMC_BITS + GPU_WSPAWN_BITS + GPU_SPLIT_BITS + GPU_BARRIER_BITS;
    
    //Response data width
    localparam RSP_DATAW         = (`NUM_THREADS*32) > WCTL_DATAW ? (`NUM_THREADS*32) : WCTL_DATAW;
    
    //2D version of input data
    wire [31 : 0] gpu_req_if_rs1_data_2d [`NUM_THREADS-1 : 0];
    wire [31 : 0] gpu_req_if_rs2_data_2d [`NUM_THREADS-1 : 0];
    wire [31 : 0] gpu_req_if_rs3_data_2d [`NUM_THREADS-1 : 0];
    wire [31 : 0] gpu_commit_if_data_2d  [`NUM_THREADS-1 : 0];
    
    genvar m;
    generate
    
        for(m = 0 ; m < `NUM_THREADS ; m = m + 1)
        begin
        
            assign gpu_req_if_rs1_data_2d[m] = gpu_req_if_rs1_data[((m+1)*32)-1 : m*32];
            assign gpu_req_if_rs2_data_2d[m] = gpu_req_if_rs2_data[((m+1)*32)-1 : m*32];
            assign gpu_req_if_rs3_data_2d[m] = gpu_req_if_rs3_data[((m+1)*32)-1 : m*32];
            
            assign gpu_commit_if_data[((m+1)*32)-1 : m*32] = gpu_commit_if_data_2d[m];
        
        end
    
    endgenerate
    
    // TMC output
    wire [GPU_TMC_BITS-1 : 0] warp_ctl_if_tmc;
    assign {warp_ctl_if_tmc_valid , warp_ctl_if_tmc_tmask} = warp_ctl_if_tmc;
    
    // Wspawn output
    wire [GPU_WSPAWN_BITS-1 : 0] warp_ctl_if_wspawn;
    assign {warp_ctl_if_wspawn_valid , warp_ctl_if_wspawn_wmask , warp_ctl_if_wspawn_pc} = warp_ctl_if_wspawn;
    
    //Barrier output
    wire [GPU_BARRIER_BITS-1 : 0] warp_ctl_if_barrier;
    assign {warp_ctl_if_barrier_valid , warp_ctl_if_barrier_id , warp_ctl_if_barrier_size_m1} = warp_ctl_if_barrier;
    
    //Split struct
    wire [GPU_SPLIT_BITS-1 : 0] warp_ctl_if_split;
    assign {warp_ctl_if_split_valid , warp_ctl_if_split_diverged , warp_ctl_if_split_then_tmask, warp_ctl_if_split_else_tmask, warp_ctl_if_split_pc} = warp_ctl_if_split;
    
    
    wire                      rsp_valid;
    wire [`UUID_BITS-1 : 0]   rsp_uuid;
    wire [`NW_BITS-1 : 0]     rsp_wid;
    wire [`NUM_THREADS-1 : 0] rsp_tmask;
    wire [31 : 0]             rsp_PC;
    wire [`NR_BITS-1 : 0]     rsp_rd;   
    wire                      rsp_wb;
    wire [RSP_DATAW-1:0]      rsp_data , rsp_data_r;
    
    //TMC
    wire                      tmc_valid;
    wire [`NUM_THREADS-1 : 0] tmc_tmask;
    
    wire [GPU_TMC_BITS-1 : 0] tmc = {tmc_valid , tmc_tmask};
    
    //Wspawn
    wire                     wspawn_valid; 
    wire [`NUM_WARPS-1 : 0]  wspawn_wmask;
    wire [31 : 0]            wspawn_pc;
    
    wire [GPU_WSPAWN_BITS-1 : 0] wspawn = {wspawn_valid, wspawn_wmask, wspawn_pc};
    
    //Barrier
    wire                     barrier_valid; 
    wire [`NB_BITS-1 : 0]    barrier_id;
    wire [`NW_BITS-1 : 0]    barrier_size_m1;
    
    wire [GPU_BARRIER_BITS-1 : 0] barrier = {barrier_valid , barrier_id , barrier_size_m1};
    
    //Split
    wire                      split_valid;
    wire                      split_diverged;
    wire [`NUM_THREADS-1 : 0] split_then_tmask;
    wire [`NUM_THREADS-1 : 0] split_else_tmask; 
    wire [31 : 0]             split_pc; 
    
    wire [GPU_SPLIT_BITS-1 : 0] split = {split_valid, split_diverged , split_then_tmask , split_else_tmask , split_pc};
    
    //Warp Control
    wire [WCTL_DATAW-1 : 0] warp_ctl_data;
    wire is_warp_ctl;
    
    wire stall_in , stall_out;
    
    wire is_wspawn = (gpu_req_if_op_type == `INST_GPU_WSPAWN);
    wire is_tmc    = (gpu_req_if_op_type == `INST_GPU_TMC);
    wire is_split  = (gpu_req_if_op_type == `INST_GPU_SPLIT);
    wire is_bar    = (gpu_req_if_op_type == `INST_GPU_BAR);
    wire is_pred   = (gpu_req_if_op_type == `INST_GPU_PRED);
    
    wire [31 : 0] rs1_data = gpu_req_if_rs1_data_2d[gpu_req_if_tid];
    wire [31 : 0] rs2_data = gpu_req_if_rs2_data_2d[gpu_req_if_tid];
    
    wire [`NUM_THREADS-1 : 0] taken_tmask;
    wire [`NUM_THREADS-1 : 0] not_taken_tmask;
    
    // Thread Mask generation
    // According to RISCV ISA the if the pervious branch taken,
    // then rs1 = 1 , else rs1 = 0
    genvar i;
    generate
    
        for(i = 0 ; i < `NUM_THREADS ; i = i + 1)
        begin
        
            wire   taken = (gpu_req_if_rs1_data_2d[i] != 0);
            assign taken_tmask[i]     = gpu_req_if_tmask[i] & taken;
            assign not_taken_tmask[i] = gpu_req_if_tmask[i] & ~taken; 
            
        end
    
    endgenerate
    
    wire [`NUM_THREADS-1 : 0] pred_mask = (taken_tmask != 0) ? taken_tmask : gpu_req_if_tmask;
    
    assign tmc_valid  = is_tmc || is_pred;
    assign tmc_tmask  = is_pred ? pred_mask : rs1_data[`NUM_THREADS-1 : 0];
    
    // Rs1 is number of warps to spawn
    // Rs2 is the PC to spawn the warps at
    wire [31 : 0] wspawn_pc_temp = rs2_data;
    wire [`NUM_WARPS-1 : 0] wspawn_wmask_temp; 
    
    genvar j;
    generate
    
        for(j = 0 ; j < `NUM_WARPS ; j = j + 1)
        begin
        
            assign wspawn_wmask_temp[j] = j < rs1_data;
        
        end
    
    endgenerate
    
    assign wspawn_valid = is_wspawn;  
    assign wspawn_wmask = wspawn_wmask_temp;
    assign wspawn_pc    = wspawn_pc_temp;
    
    //Split control 
    assign split_valid      = is_split;
    assign split_diverged   = (| taken_tmask) && (| not_taken_tmask);
    assign split_then_tmask = taken_tmask; 
    assign split_else_tmask = not_taken_tmask;
    assign split_pc         = gpu_req_if_next_PC;
    
    // Syncronization Barroers
    // Rs1 : ID of the barrier
    // Rs2 : Number of threads that need to reach the barrier and synchronized(Barrier size)
    assign barrier_valid   = is_bar; 
    assign barrier_id      = rs1_data[`NB_BITS-1:0];
    assign barrier_size_m1 = rs2_data[`NW_BITS-1:0] - 1'b1;
    
    //Warp control data
    assign warp_ctl_data = {tmc, wspawn, split, barrier};
    
    assign stall_in    = stall_out;
    assign is_warp_ctl = 1;
    assign rsp_valid   = gpu_req_if_valid;
    assign rsp_uuid    = gpu_req_if_uuid;
    assign rsp_wid     = gpu_req_if_wid;
    assign rsp_tmask   = gpu_req_if_tmask;
    assign rsp_PC      = gpu_req_if_PC;
    assign rsp_rd      = 0;
    assign rsp_wb      = 0;
    assign rsp_data    = warp_ctl_data; 
    
    wire is_warp_ctl_r;  
    assign stall_out = ~gpu_commit_if_ready && gpu_commit_if_valid;
    
    RV_pipe_register #(
    
        .DATAW  (1 + `UUID_BITS + `NW_BITS + `NUM_THREADS + 32 + `NR_BITS + 1 + RSP_DATAW + 1), 
        .RESETW (1)
        
    ) pipe_reg (
        .clk      (clk),        
        .reset    (reset),      
        .enable   (!stall_out), 
        .data_in  ({rsp_valid , rsp_uuid , rsp_wid , rsp_tmask , rsp_PC , rsp_rd , rsp_wb , rsp_data , is_warp_ctl}),
        .data_out ({gpu_commit_if_valid , gpu_commit_if_uuid , gpu_commit_if_wid , gpu_commit_if_tmask , gpu_commit_if_PC , gpu_commit_if_rd , gpu_commit_if_wb , rsp_data_r , is_warp_ctl_r})
    ); 
    
    generate
    
        for (i = 0; i < `NUM_THREADS; i = i + 1) 
        begin
        
            assign gpu_commit_if_data_2d[i] = rsp_data_r[((i+1)*32)-1 : i*32];
            
        end
        
    endgenerate
    
    assign gpu_commit_if_eop  = 1'b1; 
    
    assign {warp_ctl_if_tmc , warp_ctl_if_wspawn , warp_ctl_if_split , warp_ctl_if_barrier} = rsp_data_r[WCTL_DATAW-1 : 0];
    
    assign warp_ctl_if_valid = gpu_commit_if_valid && gpu_commit_if_ready && is_warp_ctl_r;
    assign warp_ctl_if_wid   = gpu_commit_if_wid;   
    assign gpu_req_if_ready  = ~stall_in;
    
            
endmodule
