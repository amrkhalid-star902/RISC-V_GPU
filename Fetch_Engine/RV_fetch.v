`timescale 1ns / 1ps

`include "RV_define.vh"
`include "RV_cache_define.vh"

module RV_fetch#(

    parameter CORE_ID   = 0,
    parameter WORD_SIZE = 1,
    parameter TAG_WIDTH = 2

)(

    input wire clk,
    input wire reset,
    
    input  wire                            icache_req_if_ready,
    input  wire                            icache_rsp_if_valid,    
    input  wire [`WORD_WIDTH-1 : 0]        icache_rsp_if_data,
    input  wire [TAG_WIDTH-1 : 0]          icache_rsp_if_tag,  
    input  wire                            wstall_if_valid,
    input  wire [`NW_BITS-1 : 0]	       wstall_if_wid,
    input  wire                            wstall_if_stalled,
    input  wire                            join_if_valid,
    input  wire [`NW_BITS-1 : 0]           join_if_wid,
    input  wire                            branch_ctl_if_valid,
    input  wire [`NW_BITS-1 : 0]           branch_ctl_if_wid,
    input  wire                            branch_ctl_if_taken,
    input  wire [31 : 0]                   branch_ctl_if_dest,
    input  wire                            warp_ctl_if_valid,
    input  wire [`NW_BITS-1 : 0]           warp_ctl_if_wid,
    input  wire                            warp_ctl_if_tmc_valid,
    input  wire [`NUM_THREADS-1 : 0]       warp_ctl_if_tmc_tmask,
    input  wire                            warp_ctl_if_wspawn_valid,
    input  wire [`NUM_WARPS-1 : 0]         warp_ctl_if_wspawn_wmask,
    input  wire [31 : 0]                   warp_ctl_if_wspawn_pc,
    input  wire                            warp_ctl_if_barrier_valid,
    input  wire [`NB_BITS-1 : 0]           warp_ctl_if_barrier_id,
    input  wire [`NW_BITS-1 : 0]           warp_ctl_if_barrier_size_m1,
    input  wire                            warp_ctl_if_split_valid,
    input  wire                            warp_ctl_if_split_diverged,
    input  wire [`NUM_THREADS-1 : 0]       warp_ctl_if_split_then_tmask,
    input  wire [`NUM_THREADS-1 : 0]       warp_ctl_if_split_else_tmask,
    input  wire [31 : 0]                   warp_ctl_if_split_pc,
    input  wire                            ifetch_rsp_if_ready,
    
    output wire                            icache_req_if_valid,
    output wire [`WORD_ADDR_WIDTH-1 : 0]   icache_req_if_addr,
    output wire [TAG_WIDTH-1 : 0]          icache_req_if_tag,
    output wire                            icache_rsp_if_ready,
    output wire                            ifetch_rsp_if_valid,
    output wire [`UUID_BITS-1 : 0]         ifetch_rsp_if_uuid,
    output wire [`NUM_THREADS-1 : 0]       ifetch_rsp_if_tmask,    
    output wire [`NW_BITS-1 : 0]           ifetch_rsp_if_wid,
    output wire [31 : 0]                   ifetch_rsp_if_PC,
    output wire [31 : 0]                   ifetch_rsp_if_data,
    output wire                            busy,
    output wire [(`NUM_WARPS*`NUM_THREADS)-1:0]	fetch_to_csr_if_thread_masks

);
    
    wire                    ifetch_req_if_valid;
    wire [`UUID_BITS-1:0]   ifetch_req_if_uuid;
    wire [`NUM_THREADS-1:0] ifetch_req_if_tmask;    
    wire [`NW_BITS-1:0]     ifetch_req_if_wid;
    wire [31:0]             ifetch_req_if_PC;
    wire                    ifetch_req_if_ready;
    
    RV_warp_sched #(
    
        .CORE_ID(CORE_ID)
        
    ) warp_sched (

        .clk(clk),
        .reset(reset),

        
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
        
        
        .wstall_if_valid(wstall_if_valid),
        .wstall_if_wid(wstall_if_wid),
        .wstall_if_stalled(wstall_if_stalled),
        
        
        .join_if_valid(join_if_valid),   
        .join_if_wid(join_if_wid),
        
        
        .branch_ctl_if_valid(branch_ctl_if_valid),
        .branch_ctl_if_wid(branch_ctl_if_wid),
        .branch_ctl_if_taken(branch_ctl_if_taken),
        .branch_ctl_if_dest(branch_ctl_if_dest),
        
        
        .ifetch_req_if_valid(ifetch_req_if_valid), 
        .ifetch_req_if_uuid(ifetch_req_if_uuid),   
        .ifetch_req_if_tmask(ifetch_req_if_tmask),
        .ifetch_req_if_wid(ifetch_req_if_wid),
        .ifetch_req_if_PC(ifetch_req_if_PC),
        .ifetch_req_if_ready(ifetch_req_if_ready),
        
        
        .fetch_to_csr_if_thread_masks(fetch_to_csr_if_thread_masks),

        .busy(busy)
        
    );
    

    RV_icache_stage #(
    
        .CORE_ID(CORE_ID),
		.WORD_SIZE(WORD_SIZE),
		.TAG_WIDTH(TAG_WIDTH)
		
    ) icache_stage (
        
		.clk(clk),
		.reset(reset),
		
		// Icache interface
		.icache_req_if_valid(icache_req_if_valid),
		.icache_req_if_addr(icache_req_if_addr),
		.icache_req_if_tag(icache_req_if_tag),   
		.icache_req_if_ready(icache_req_if_ready),

		.icache_rsp_if_valid(icache_rsp_if_valid),    
		.icache_rsp_if_data(icache_rsp_if_data),
		.icache_rsp_if_tag(icache_rsp_if_tag),
		.icache_rsp_if_ready(icache_rsp_if_ready),  
		
		// request
		.ifetch_req_if_valid(ifetch_req_if_valid),
		.ifetch_req_if_uuid(ifetch_req_if_uuid),
		.ifetch_req_if_tmask(ifetch_req_if_tmask),    
		.ifetch_req_if_wid(ifetch_req_if_wid),
		.ifetch_req_if_PC(ifetch_req_if_PC),
		.ifetch_req_if_ready(ifetch_req_if_ready),

		// reponse
		.ifetch_rsp_if_valid(ifetch_rsp_if_valid),
		.ifetch_rsp_if_uuid(ifetch_rsp_if_uuid),
		.ifetch_rsp_if_tmask(ifetch_rsp_if_tmask),    
		.ifetch_rsp_if_wid(ifetch_rsp_if_wid),
		.ifetch_rsp_if_PC(ifetch_rsp_if_PC),
		.ifetch_rsp_if_data(ifetch_rsp_if_data),
		.ifetch_rsp_if_ready(ifetch_rsp_if_ready)

	);


endmodule
