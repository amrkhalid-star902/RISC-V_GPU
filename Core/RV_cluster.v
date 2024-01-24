`timescale 1ns / 1ps

`include "RV_define.vh"


module RV_cluster#(

    parameter CLUSTER_ID = 0 

)(

    input  wire clk,
    input  wire reset,
    
    input  wire                              mem_req_ready,
    input  wire                              mem_rsp_valid,
    input  wire [`L2_MEM_DATA_WIDTH-1 : 0]   mem_rsp_data,
    input  wire [`L2_MEM_TAG_WIDTH-1 : 0]    mem_rsp_tag, 
    
    output wire                              mem_req_valid,
    output wire                              mem_req_rw, 
    output wire [`L2_MEM_BYTEEN_WIDTH-1 : 0] mem_req_byteen,
    output wire [`L2_MEM_ADDR_WIDTH-1 : 0]   mem_req_addr,
    output wire [`L2_MEM_DATA_WIDTH-1 : 0]   mem_req_data,
    output wire [`L2_MEM_TAG_WIDTH-1 : 0]    mem_req_tag,
    output wire                              mem_rsp_ready,
    output wire                              busy 

);


    wire [`NUM_CORES-1 : 0]                               per_core_mem_req_valid;     //  Validity of Request sent to Memory for each Core.
    wire [`NUM_CORES-1 : 0]                               per_core_mem_req_rw;        //  Is each Core's Request Read or Write?
    wire [(`NUM_CORES*`DCACHE_MEM_BYTEEN_WIDTH)-1 : 0]    per_core_mem_req_byteen;    //  Each Core's Request Byte Enable (Which Byte Lane has Valid Data).  
    wire [(`NUM_CORES*`DCACHE_MEM_ADDR_WIDTH)-1 : 0]      per_core_mem_req_addr;      //  Each Core's Address to Read/Write from.
    wire [(`NUM_CORES*`DCACHE_MEM_DATA_WIDTH)-1 : 0]      per_core_mem_req_data;      //  Each Core's Data to Write to Memory.
    wire [(`NUM_CORES*`L1_MEM_TAG_WIDTH)-1 : 0]           per_core_mem_req_tag;       //  Each Core's Requested Tag.
    wire [`NUM_CORES-1 : 0]                               per_core_mem_req_ready;     //  Memory is Ready to accept Request from each Core.

    wire [`NUM_CORES-1 : 0]                               per_core_mem_rsp_valid;     //  Is each Core's Memory Response Valid?                
    wire [(`NUM_CORES*`DCACHE_MEM_DATA_WIDTH)-1 : 0]      per_core_mem_rsp_data;      //  Each Core's Memory Response Data.    
    wire [(`NUM_CORES*`L1_MEM_TAG_WIDTH)-1 : 0]           per_core_mem_rsp_tag;       //  Each Core's Memory Response Tag.    
    wire [`NUM_CORES-1 : 0]                               per_core_mem_rsp_ready;     //  Cluster is Ready to accept Response from each Core.
    
    wire [`NUM_CORES-1 : 0]                               per_core_busy;  //  Busy Flag for each Core.   
    
    genvar i;
    generate
        
        for (i = 0; i < `NUM_CORES; i = i + 1) 
        begin
        
            RV_core #(
            
                .CORE_ID(i + (CLUSTER_ID*`NUM_CORES)) 
                
            ) core (
                
                .clk            (clk),
                .reset          (reset),
        
                .mem_req_valid  (per_core_mem_req_valid[i]),
                .mem_req_rw     (per_core_mem_req_rw[i]),                
                .mem_req_byteen (per_core_mem_req_byteen[((i+1)*`DCACHE_MEM_BYTEEN_WIDTH)-1 : i*`DCACHE_MEM_BYTEEN_WIDTH]),                
                .mem_req_addr   (per_core_mem_req_addr[((i+1)*`DCACHE_MEM_ADDR_WIDTH)-1 : i*`DCACHE_MEM_ADDR_WIDTH]),
                .mem_req_data   (per_core_mem_req_data[((i+1)*`DCACHE_MEM_DATA_WIDTH)-1 : i*`DCACHE_MEM_DATA_WIDTH]),
                .mem_req_tag    (per_core_mem_req_tag[((i+1)*`L1_MEM_TAG_WIDTH)-1 : i*`L1_MEM_TAG_WIDTH]),
                .mem_req_ready  (per_core_mem_req_ready[i]),
                         
                .mem_rsp_valid  (per_core_mem_rsp_valid[i]),                
                .mem_rsp_data   (per_core_mem_rsp_data[((i+1)*`DCACHE_MEM_DATA_WIDTH)-1 : i*`DCACHE_MEM_DATA_WIDTH]),
                .mem_rsp_tag    (per_core_mem_rsp_tag[((i+1)*`L1_MEM_TAG_WIDTH)-1 : i*`L1_MEM_TAG_WIDTH]),
                .mem_rsp_ready  (per_core_mem_rsp_ready[i]),
        
                .busy           (per_core_busy[i])
                
            );
        
        end
    
    endgenerate
    
    assign busy = (| per_core_busy);
    
    RV_mem_arb #(
        
        .NUM_REQS     (`NUM_CORES),
        .DATA_WIDTH   (`DCACHE_MEM_DATA_WIDTH),
        .ADDR_WIDTH   (`DCACHE_MEM_ADDR_WIDTH),           
        .TAG_IN_WIDTH (`L1_MEM_TAG_WIDTH),            
        .TYPE         ("R"),
        .TAG_SEL_IDX  (1), 
        .BUFFERED_REQ (1),
        .BUFFERED_RSP (1)
        
    ) mem_arb (
        .clk            (clk),
        .reset          (reset),

        //  Core Request.
        .req_valid_in   (per_core_mem_req_valid),
        .req_rw_in      (per_core_mem_req_rw),
        .req_byteen_in  (per_core_mem_req_byteen),
        .req_addr_in    (per_core_mem_req_addr),
        .req_data_in    (per_core_mem_req_data),  
        .req_tag_in     (per_core_mem_req_tag),  
        .req_ready_in   (per_core_mem_req_ready),

        //  Memory Request.
        .req_valid_out  (mem_req_valid),
        .req_rw_out     (mem_req_rw),        
        .req_byteen_out (mem_req_byteen),        
        .req_addr_out   (mem_req_addr),
        .req_data_out   (mem_req_data),
        .req_tag_out    (mem_req_tag),
        .req_ready_out  (mem_req_ready),

        //  Core Response.
        .rsp_valid_out  (per_core_mem_rsp_valid),
        .rsp_data_out   (per_core_mem_rsp_data),
        .rsp_tag_out    (per_core_mem_rsp_tag),
        .rsp_ready_out  (per_core_mem_rsp_ready),
        
        //  Memory Response.
        .rsp_valid_in   (mem_rsp_valid),
        .rsp_tag_in     (mem_rsp_tag),
        .rsp_data_in    (mem_rsp_data),
        .rsp_ready_in   (mem_rsp_ready)
        
    );
    
endmodule
