`timescale 1ns / 1ps

`include "RV_define.vh"

module RV_mem_unit#(

    parameter CORE_ID = 0, 
    parameter DREQ_NUM_REQS     = `DCACHE_NUM_REQS,
    parameter DREQ_WORD_SIZE    = `DCACHE_WORD_SIZE,  
    parameter DREQ_TAG_WIDTH    = `DCACHE_CORE_TAG_WIDTH,
    parameter DRSP_NUM_REQS     = `DCACHE_NUM_REQS, 
    parameter DRSP_WORD_SIZE    = `DCACHE_WORD_SIZE,
    parameter DRSP_TAG_WIDTH    = `DCACHE_CORE_TAG_WIDTH, 
    parameter IREQ_TAG_WIDTH    = `ICACHE_CORE_TAG_WIDTH,
    parameter IREQ_WORD_SIZE    = `ICACHE_WORD_SIZE, 
    parameter IRSP_TAG_WIDTH    = `ICACHE_CORE_TAG_WIDTH, 
    parameter IRSP_WORD_SIZE    = `ICACHE_WORD_SIZE, 
    parameter MEMREQ_DATA_WIDTH = `DCACHE_MEM_DATA_WIDTH,
    parameter MEMREQ_ADDR_WIDTH = `DCACHE_MEM_ADDR_WIDTH,
    parameter MEMREQ_TAG_WIDTH  = `L1_MEM_TAG_WIDTH,
    parameter MEMREQ_DATA_SIZE  = MEMREQ_DATA_WIDTH / 8,
    parameter MEMRSP_DATA_WIDTH = `DCACHE_MEM_DATA_WIDTH,
    parameter MEMRSP_TAG_WIDTH  = `L1_MEM_TAG_WIDTH

)(

    input  wire clk,
    input  wire reset,
    
    //DCache Request signals
    input  wire [DREQ_NUM_REQS-1 : 0]                                 dcache_req_if_valid,
    input  wire [DREQ_NUM_REQS-1 : 0]                                 dcache_req_if_rw,
    input  wire [(DREQ_NUM_REQS*DREQ_WORD_SIZE)-1 : 0]                dcache_req_if_byteen,
    input  wire [(DREQ_NUM_REQS*(32-$clog2(DREQ_WORD_SIZE)))-1 : 0]   dcache_req_if_addr,
    input  wire [(DREQ_NUM_REQS*(8*DREQ_WORD_SIZE))-1 : 0]            dcache_req_if_data,
    input  wire [(DREQ_NUM_REQS*DREQ_TAG_WIDTH)-1 : 0]                dcache_req_if_tag,
    input  wire                                                       dcache_rsp_if_ready,
    
    
    //ICache Request signals
    input  wire                                                       icache_rsp_if_ready,
    input  wire                                                       icache_req_if_valid,
    input  wire [(32-$clog2(IREQ_WORD_SIZE))-1 : 0]                   icache_req_if_addr,
    input  wire [IREQ_TAG_WIDTH-1 : 0]                                icache_req_if_tag,
    
    
    
    //Mem Response signals
    input  wire                                                       mem_req_if_ready,
    input  wire                                                       mem_rsp_if_valid,
    input  wire [MEMRSP_DATA_WIDTH-1 : 0]                             mem_rsp_if_data,
    input  wire [MEMRSP_TAG_WIDTH-1 : 0]                              mem_rsp_if_tag,
    
    
    //DCache Response signals
    output wire [DREQ_NUM_REQS-1 : 0]                                 dcache_req_if_ready,
    output wire                                                       dcache_rsp_if_valid,
    output wire [DRSP_NUM_REQS-1 : 0]                                 dcache_rsp_if_tmask,
    output wire [(DRSP_NUM_REQS*(8*DRSP_WORD_SIZE))-1 : 0]            dcache_rsp_if_data,
    output wire [DRSP_TAG_WIDTH-1 : 0]                                dcache_rsp_if_tag,
    
    
    //ICache Response signals
    output wire                                                       icache_req_if_ready,
    output wire                                                       icache_rsp_if_valid,
    output wire [(8*IRSP_WORD_SIZE)-1 : 0]                            icache_rsp_if_data,
    output wire [IRSP_TAG_WIDTH-1 : 0]                                icache_rsp_if_tag,
    
    
    //Memory Requests signals
    output wire                                                       mem_req_if_valid,
    output wire                                                       mem_req_if_rw,
    output wire [MEMREQ_DATA_SIZE-1 : 0]                              mem_req_if_byteen,
    output wire [MEMREQ_ADDR_WIDTH-1 : 0]                             mem_req_if_addr,
    output wire [MEMREQ_DATA_WIDTH-1 : 0]                             mem_req_if_data,
    output wire [MEMREQ_TAG_WIDTH-1 : 0]                              mem_req_if_tag,
    output wire                                                       mem_rsp_if_ready
                
);

    wire [DREQ_WORD_SIZE-1 : 0]                dcache_req_if_byteen_2d  [DREQ_NUM_REQS-1:0];
    wire [(32-$clog2(DREQ_WORD_SIZE))-1 : 0]   dcache_req_if_addr_2d    [DREQ_NUM_REQS-1:0];
    wire [(8*DREQ_WORD_SIZE)-1 : 0]            dcache_req_if_data_2d    [DREQ_NUM_REQS-1:0];
    wire [DREQ_TAG_WIDTH-1 : 0]                dcache_req_if_tag_2d     [DREQ_NUM_REQS-1:0];
    
    genvar i;
    generate
    
        for (i = 0; i < DREQ_NUM_REQS; i = i + 1) 
        begin
        
            assign  dcache_req_if_byteen_2d[i]   =   dcache_req_if_byteen[(i+1)*DREQ_WORD_SIZE-1 : i*DREQ_WORD_SIZE];
            assign  dcache_req_if_addr_2d[i]     =   dcache_req_if_addr[(i+1)*(32-$clog2(DREQ_WORD_SIZE))-1 : i*(32-$clog2(DREQ_WORD_SIZE))];
            assign  dcache_req_if_data_2d[i]     =   dcache_req_if_data[(i+1)*(8*DREQ_WORD_SIZE)-1 : i*(8*DREQ_WORD_SIZE)];
            assign  dcache_req_if_tag_2d[i]      =   dcache_req_if_tag[(i+1)*DREQ_TAG_WIDTH-1 : i*DREQ_TAG_WIDTH];
            
        end
        
    endgenerate
    
    localparam IMEMREQ_DATA_WIDTH = `ICACHE_MEM_DATA_WIDTH;
    localparam IMEMREQ_ADDR_WIDTH = `ICACHE_MEM_ADDR_WIDTH;
    localparam IMEMREQ_TAG_WIDTH  = `ICACHE_MEM_TAG_WIDTH;
    localparam IMEMREQ_DATA_SIZE  = IMEMREQ_DATA_WIDTH / 8; 
    
    wire                            icache_mem_req_if_valid;
    wire                            icache_mem_req_if_rw;
    wire [IMEMREQ_DATA_SIZE-1 : 0]  icache_mem_req_if_byteen;
    wire [IMEMREQ_ADDR_WIDTH-1 : 0] icache_mem_req_if_addr;
    wire [IMEMREQ_DATA_WIDTH-1 : 0] icache_mem_req_if_data;
    wire [IMEMREQ_TAG_WIDTH-1 : 0]  icache_mem_req_if_tag;
    wire                            icache_mem_req_if_ready; 
    
    localparam IMEMRSP_DATA_WIDTH = `ICACHE_MEM_DATA_WIDTH; 
    localparam IMEMRSP_TAG_WIDTH  = `ICACHE_MEM_TAG_WIDTH;
    
    wire                            icache_mem_rsp_if_valid;     
    wire [IMEMRSP_DATA_WIDTH-1 : 0] icache_mem_rsp_if_data;     
    wire [IMEMRSP_TAG_WIDTH-1 : 0]  icache_mem_rsp_if_tag;      
    wire                            icache_mem_rsp_if_ready; 
    
    localparam DMEMREQ_DATA_WIDTH = `DCACHE_MEM_DATA_WIDTH; 
    localparam DMEMREQ_ADDR_WIDTH = `DCACHE_MEM_ADDR_WIDTH; 
    localparam DMEMREQ_TAG_WIDTH  = `DCACHE_MEM_TAG_WIDTH;  
    localparam DMEMREQ_DATA_SIZE  = DMEMREQ_DATA_WIDTH / 8; 
    
    wire                            dcache_mem_req_if_valid;   
    wire                            dcache_mem_req_if_rw;      
    wire [DMEMREQ_DATA_SIZE-1 : 0]  dcache_mem_req_if_byteen;  
    wire [DMEMREQ_ADDR_WIDTH-1 : 0] dcache_mem_req_if_addr;    
    wire [DMEMREQ_DATA_WIDTH-1 : 0] dcache_mem_req_if_data;    
    wire [DMEMREQ_TAG_WIDTH-1 : 0]  dcache_mem_req_if_tag;     
    wire                            dcache_mem_req_if_ready;   
    

    localparam DMEMRSP_DATA_WIDTH = `DCACHE_MEM_DATA_WIDTH; 
    localparam DMEMRSP_TAG_WIDTH  = `DCACHE_MEM_TAG_WIDTH;  

    wire                            dcache_mem_rsp_if_valid;    
    wire [DMEMRSP_DATA_WIDTH-1 : 0] dcache_mem_rsp_if_data;     
    wire [DMEMRSP_TAG_WIDTH-1 : 0]  dcache_mem_rsp_if_tag;         
    wire                            dcache_mem_rsp_if_ready;    
    
    localparam DTMP_REQ_NUM_REQS  = `DCACHE_NUM_REQS;   
    localparam DTMP_REQ_WORD_SIZE = `DCACHE_WORD_SIZE;  
    
    localparam DTMP_REQ_TAG_WIDTH = `DCACHE_CORE_TAG_WIDTH -`SM_ENABLE; 
    
    wire [DTMP_REQ_NUM_REQS-1 : 0]                                   dcache_req_tmp_if_valid;    //  Validity of Requests sent to D-Cache.
    wire [DTMP_REQ_NUM_REQS-1 : 0]                                   dcache_req_tmp_if_rw;       //  Are Requests Read or Write?
    wire [(DTMP_REQ_NUM_REQS*DTMP_REQ_WORD_SIZE)-1 : 0]              dcache_req_tmp_if_byteen;   //  Request Byte Enable (Which Byte Lane has Valid Data).
    wire [(DTMP_REQ_NUM_REQS*(32-$clog2(DTMP_REQ_WORD_SIZE)))-1 : 0] dcache_req_tmp_if_addr;     //  Address to Read/Write from.
    wire [(DTMP_REQ_NUM_REQS*(8*DTMP_REQ_WORD_SIZE))-1 : 0]          dcache_req_tmp_if_data;     //  Data to Write to D-Cache.
    wire [(DTMP_REQ_NUM_REQS*DTMP_REQ_TAG_WIDTH)-1 : 0]              dcache_req_tmp_if_tag;      //  Tag Requested.
    wire [DTMP_REQ_NUM_REQS-1 : 0]                                   dcache_req_tmp_if_ready; 
    
    localparam DTMP_RSP_NUM_REQS  = `DCACHE_NUM_REQS; 
    localparam DTMP_RSP_WORD_SIZE = `DCACHE_WORD_SIZE; 
    localparam DTMP_RSP_TAG_WIDTH = `DCACHE_CORE_TAG_WIDTH -`SM_ENABLE;
    
    wire                                                      dcache_rsp_tmp_if_valid;    
    wire [DTMP_RSP_NUM_REQS-1 : 0]                            dcache_rsp_tmp_if_tmask;    
    wire [(DTMP_RSP_NUM_REQS*(8*DTMP_RSP_WORD_SIZE))-1 : 0]   dcache_rsp_tmp_if_data;     
    wire [DTMP_RSP_TAG_WIDTH-1 : 0]                           dcache_rsp_tmp_if_tag;      
    wire                                                      dcache_rsp_tmp_if_ready; 
    
    //////////////////////
    //                  //  
    //      I-Cache     //
    //                  //
    //////////////////////
    RV_cache #(
    
        .CACHE_ID           (`ICACHE_ID),
        .CACHE_SIZE         (`ICACHE_SIZE),
        .CACHE_LINE_SIZE    (`ICACHE_LINE_SIZE),
        .NUM_BANKS          (1),
        .WORD_SIZE          (`ICACHE_WORD_SIZE),
        .NUM_REQS           (1),
        .CREQ_SIZE          (`ICACHE_CREQ_SIZE),
        .CRSQ_SIZE          (`ICACHE_CRSQ_SIZE),
        .MSHR_SIZE          (`ICACHE_MSHR_SIZE),
        .MRSQ_SIZE          (`ICACHE_MRSQ_SIZE),
        .MREQ_SIZE          (`ICACHE_MREQ_SIZE),
        .WRITE_ENABLE       (0),
        .CORE_TAG_WIDTH     (`ICACHE_CORE_TAG_WIDTH),
        .CORE_TAG_ID_BITS   (`ICACHE_CORE_TAG_ID_BITS),
        .MEM_TAG_WIDTH      (`ICACHE_MEM_TAG_WIDTH)
        
    ) icache (

        .clk                (clk),
        .reset              (reset),

        //  Core Request.
        .core_req_valid     (icache_req_if_valid),
        .core_req_rw        (1'b0),
        .core_req_byteen    (0),
        .core_req_addr      (icache_req_if_addr),
        .core_req_data      (0),        
        .core_req_tag       (icache_req_if_tag),
        .core_req_ready     (icache_req_if_ready),

        //  Core Response
        .core_rsp_valid     (icache_rsp_if_valid),
        .core_rsp_data      (icache_rsp_if_data),
        .core_rsp_tag       (icache_rsp_if_tag),
        .core_rsp_ready     (icache_rsp_if_ready),
        .core_rsp_tmask     (),

        //  Memory Request.
        .mem_req_valid     (icache_mem_req_if_valid),
        .mem_req_rw        (icache_mem_req_if_rw),        
        .mem_req_byteen    (icache_mem_req_if_byteen),        
        .mem_req_addr      (icache_mem_req_if_addr),
        .mem_req_data      (icache_mem_req_if_data),
        .mem_req_tag       (icache_mem_req_if_tag),
        .mem_req_ready     (icache_mem_req_if_ready),        

        //  Memory response.
        .mem_rsp_valid     (icache_mem_rsp_if_valid),        
        .mem_rsp_data      (icache_mem_rsp_if_data),
        .mem_rsp_tag       (icache_mem_rsp_if_tag),
        .mem_rsp_ready     (icache_mem_rsp_if_ready)
        
    );
    
    
    //////////////////////
    //                  //  
    //      D-Cache     //
    //                  //
    //////////////////////
    RV_cache #(
    
        .CACHE_ID           (`DCACHE_ID),
        .CACHE_SIZE         (`DCACHE_SIZE),
        .CACHE_LINE_SIZE    (`DCACHE_LINE_SIZE),
        .NUM_BANKS          (`DCACHE_NUM_BANKS),
        .NUM_PORTS          (`DCACHE_NUM_PORTS),
        .WORD_SIZE          (`DCACHE_WORD_SIZE),
        .NUM_REQS           (`DCACHE_NUM_REQS),
        .CREQ_SIZE          (`DCACHE_CREQ_SIZE),
        .CRSQ_SIZE          (`DCACHE_CRSQ_SIZE),
        .MSHR_SIZE          (`DCACHE_MSHR_SIZE),
        .MRSQ_SIZE          (`DCACHE_MRSQ_SIZE),
        .MREQ_SIZE          (`DCACHE_MREQ_SIZE),
        .WRITE_ENABLE       (1),
        .CORE_TAG_WIDTH     (`DCACHE_CORE_TAG_WIDTH-`SM_ENABLE),
        .CORE_TAG_ID_BITS   (`DCACHE_CORE_TAG_ID_BITS-`SM_ENABLE),
        .MEM_TAG_WIDTH      (`DCACHE_MEM_TAG_WIDTH)
        
    ) dcache (
        
        .clk                (clk),
        .reset              (reset),

        //  Core Request.
        .core_req_valid     (dcache_req_tmp_if_valid),
        .core_req_rw        (dcache_req_tmp_if_rw),
        .core_req_byteen    (dcache_req_tmp_if_byteen),
        .core_req_addr      (dcache_req_tmp_if_addr),
        .core_req_data      (dcache_req_tmp_if_data),        
        .core_req_tag       (dcache_req_tmp_if_tag),
        .core_req_ready     (dcache_req_tmp_if_ready),

        //  Core Response.
        .core_rsp_valid     (dcache_rsp_tmp_if_valid),
        .core_rsp_tmask     (dcache_rsp_tmp_if_tmask),
        .core_rsp_data      (dcache_rsp_tmp_if_data),
        .core_rsp_tag       (dcache_rsp_tmp_if_tag),
        .core_rsp_ready     (dcache_rsp_tmp_if_ready),

        //  Memory Request.
        .mem_req_valid      (dcache_mem_req_if_valid),
        .mem_req_rw         (dcache_mem_req_if_rw),        
        .mem_req_byteen     (dcache_mem_req_if_byteen),        
        .mem_req_addr       (dcache_mem_req_if_addr),
        .mem_req_data       (dcache_mem_req_if_data),
        .mem_req_tag        (dcache_mem_req_if_tag),
        .mem_req_ready      (dcache_mem_req_if_ready),

        //  Memory Response.
        .mem_rsp_valid      (dcache_mem_rsp_if_valid),        
        .mem_rsp_data       (dcache_mem_rsp_if_data),
        .mem_rsp_tag        (dcache_mem_rsp_if_tag),
        .mem_rsp_ready      (dcache_mem_rsp_if_ready)
        
    ); 
    
    generate
    
        for (i = 0; i < `DCACHE_NUM_REQS; i = i + 1)
        begin
        
            RV_skid_buffer #(
            
                .DATAW ((32-$clog2(`DCACHE_WORD_SIZE)) + 1 + `DCACHE_WORD_SIZE + (8*`DCACHE_WORD_SIZE) + `DCACHE_CORE_TAG_WIDTH)
            
            ) req_buf (
                .clk       (clk),
                .reset     (reset),
                .valid_in  (dcache_req_if_valid[i]),        
                .data_in   ({dcache_req_if_addr_2d[i], dcache_req_if_rw[i], dcache_req_if_byteen_2d[i], dcache_req_if_data_2d[i], dcache_req_if_tag_2d[i]}),
                .ready_in  (dcache_req_if_ready[i]),
                .valid_out (dcache_req_tmp_if_valid[i]),
                .data_out  ({dcache_req_tmp_if_addr[((i+1)*(32-$clog2(DTMP_REQ_WORD_SIZE)))-1 : i*(32-$clog2(DTMP_REQ_WORD_SIZE))], 
                             dcache_req_tmp_if_rw[i], 
                             dcache_req_tmp_if_byteen[((i+1)*DTMP_REQ_WORD_SIZE)-1 : i*DTMP_REQ_WORD_SIZE], 
                             dcache_req_tmp_if_data[((i+1)*(8*DTMP_REQ_WORD_SIZE))-1 : i*(8*DTMP_REQ_WORD_SIZE)], 
                             dcache_req_tmp_if_tag[((i+1)*DTMP_REQ_TAG_WIDTH)-1 : i*DTMP_REQ_TAG_WIDTH]}),
                .ready_out (dcache_req_tmp_if_ready[i])
            );     
        
        end
        
        //  D-cache to Core Response.
        assign dcache_rsp_if_valid  = dcache_rsp_tmp_if_valid;
        assign dcache_rsp_if_tmask  = dcache_rsp_tmp_if_tmask;
        assign dcache_rsp_if_tag    = dcache_rsp_tmp_if_tag;
        assign dcache_rsp_if_data   = dcache_rsp_tmp_if_data;
        assign dcache_rsp_tmp_if_ready = dcache_rsp_if_ready;
    
    endgenerate
    
     wire [`DCACHE_MEM_TAG_WIDTH-1 : 0] icache_mem_req_tag;    
     
    //  Cast the I-Cache Tag to be the same width as D-Cache Tag to send to Memory Arbiter.
     generate
     
         if (`DCACHE_MEM_TAG_WIDTH > IMEMREQ_TAG_WIDTH) 
         begin
             assign icache_mem_req_tag = {{(`DCACHE_MEM_TAG_WIDTH - IMEMREQ_TAG_WIDTH){1'b0}}, icache_mem_req_if_tag};
         end
         else 
         begin
             assign icache_mem_req_tag = icache_mem_req_if_tag[`DCACHE_MEM_TAG_WIDTH-1 : 0];
         end
         
     endgenerate
     
     wire [`DCACHE_MEM_TAG_WIDTH-1 : 0] icache_mem_rsp_tag;
     assign icache_mem_rsp_if_tag = icache_mem_rsp_tag[`ICACHE_MEM_TAG_WIDTH-1 : 0];
     
    //  Instantiate a Memory Arbiter to handle I-Cache and D-Cache requests to memory.
     RV_mem_arb #(
     
         .NUM_REQS      (2),
         .DATA_WIDTH    (`DCACHE_MEM_DATA_WIDTH),
         .ADDR_WIDTH    (`DCACHE_MEM_ADDR_WIDTH),
         .TAG_IN_WIDTH  (`DCACHE_MEM_TAG_WIDTH),
         .TYPE          ("R"),
         .TAG_SEL_IDX   (1), // Skip 0 for NC flag
         .BUFFERED_REQ  (1),
         .BUFFERED_RSP  (2)
         
     ) mem_arb (
     
         .clk            (clk),
         .reset          (reset),
 
         //  Source Request.
         .req_valid_in   ({dcache_mem_req_if_valid,  icache_mem_req_if_valid}),
         .req_rw_in      ({dcache_mem_req_if_rw,     icache_mem_req_if_rw}),
         .req_byteen_in  ({dcache_mem_req_if_byteen, icache_mem_req_if_byteen}),
         .req_addr_in    ({dcache_mem_req_if_addr,   icache_mem_req_if_addr}),
         .req_data_in    ({dcache_mem_req_if_data,   icache_mem_req_if_data}),  
         .req_tag_in     ({dcache_mem_req_if_tag,    icache_mem_req_tag}),  
         .req_ready_in   ({dcache_mem_req_if_ready,  icache_mem_req_if_ready}),
 
         //  Memory Request.
         .req_valid_out  (mem_req_if_valid),
         .req_rw_out     (mem_req_if_rw),        
         .req_byteen_out (mem_req_if_byteen),        
         .req_addr_out   (mem_req_if_addr),
         .req_data_out   (mem_req_if_data),
         .req_tag_out    (mem_req_if_tag),
         .req_ready_out  (mem_req_if_ready),
 
         //  Source Response.
         .rsp_valid_out  ({dcache_mem_rsp_if_valid, icache_mem_rsp_if_valid}),
         .rsp_data_out   ({dcache_mem_rsp_if_data,  icache_mem_rsp_if_data}),
         .rsp_tag_out    ({dcache_mem_rsp_if_tag,   icache_mem_rsp_tag}),
         .rsp_ready_out  ({dcache_mem_rsp_if_ready, icache_mem_rsp_if_ready}),
         
         //  Memory Response.
         .rsp_valid_in   (mem_rsp_if_valid),
         .rsp_tag_in     (mem_rsp_if_tag),
         .rsp_data_in    (mem_rsp_if_data),
         .rsp_ready_in   (mem_rsp_if_ready)
         
     );
         
endmodule
