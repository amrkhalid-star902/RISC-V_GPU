`timescale 1ns / 1ps

`include "RV_define.vh"
`include "RV_cache_define.vh"

module RV_icache_stage#(

    parameter CORE_ID   = 0,
    parameter WORD_SIZE = 1,
    parameter TAG_WIDTH = 2

)(

    input wire clk,
    input wire reset,
    
    //input icache_rsp_if_slave
    input  wire                          icache_req_if_ready,
    input  wire                          icache_rsp_if_valid,
    input  wire [`WORD_WIDTH-1:0]        icache_rsp_if_data,
    input  wire [TAG_WIDTH - 1:0]        icache_rsp_if_tag,
    input  wire                          ifetch_req_if_valid,
    input  wire [`UUID_BITS-1:0]         ifetch_req_if_uuid,
    input  wire [`NUM_THREADS-1:0]       ifetch_req_if_tmask,
    input  wire [`NW_BITS-1:0]           ifetch_req_if_wid,
    input  wire [31:0]                   ifetch_req_if_PC,
    input  wire                          ifetch_rsp_if_ready,
    
    output wire                          icache_req_if_valid,
    output wire [`WORD_ADDR_WIDTH-1:0]   icache_req_if_addr,
    output wire [TAG_WIDTH - 1:0]        icache_req_if_tag,
    output wire                          icache_rsp_if_ready,
    output wire                          ifetch_req_if_ready,
    output wire                          ifetch_rsp_if_valid,
    output wire [`UUID_BITS-1:0]         ifetch_rsp_if_uuid,
    output wire [`NUM_THREADS-1:0]       ifetch_rsp_if_tmask,
    output wire [`NW_BITS-1:0]           ifetch_rsp_if_wid,
    output wire [31:0]                   ifetch_rsp_if_PC,
    output wire [31:0]                   ifetch_rsp_if_data
    
);


    wire [`NW_BITS-1:0] req_tag;
    wire [`NW_BITS-1:0] rsp_tag;
    wire icache_req_fire = icache_req_if_valid && icache_req_if_ready;
    
    assign req_tag = ifetch_req_if_wid;
    assign rsp_tag = icache_rsp_if_tag[`NW_BITS-1:0];
    
    wire [`UUID_BITS-1:0]     rsp_uuid;
    wire [31 : 0]             rsp_PC;
    wire [`NUM_THREADS-1:0]   rsp_tmask;
    
    RV_dp_ram #(
    
        .DATAW  (32 + `NUM_THREADS + `UUID_BITS),
        .SIZE   (`NUM_WARPS)
            
    ) req_metadata(
    
        .clk(clk),
        .wren(icache_req_fire),
        .waddr(req_tag),
        .wdata({ifetch_req_if_PC, ifetch_req_if_tmask, ifetch_req_if_uuid}),
        .raddr(rsp_tag),
        .rdata({rsp_PC, rsp_tmask, rsp_uuid})
            
    );
    
    assign icache_req_if_valid  = ifetch_req_if_valid;
    assign icache_req_if_addr   = ifetch_req_if_PC[31:2];
    assign icache_req_if_tag    = {ifetch_req_if_uuid, req_tag};
    assign ifetch_req_if_ready  = icache_req_if_ready;
    wire [`NW_BITS-1:0] rsp_wid = rsp_tag;
    
    wire stall_out = ~ifetch_rsp_if_ready && ifetch_rsp_if_valid;
    
    RV_pipe_register #(
    
        .DATAW(1 + `NW_BITS + `NUM_THREADS + 32 + 32 + `UUID_BITS),
        .RESETW(1),
        .DEPTH(0)
        
    ) pipe_reg(
    
        .clk(clk),
        .reset(reset),
        .enable(!stall_out),
        .data_in({icache_rsp_if_valid, rsp_wid, rsp_tmask, rsp_PC, icache_rsp_if_data, rsp_uuid}),
        .data_out({ifetch_rsp_if_valid, ifetch_rsp_if_wid, ifetch_rsp_if_tmask, ifetch_rsp_if_PC, ifetch_rsp_if_data, ifetch_rsp_if_uuid})
            
    );
    
    assign icache_rsp_if_ready = ~stall_out;

endmodule
