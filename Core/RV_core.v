`timescale 1ns / 1ps

`include "RV_define.vh"

module RV_core#(

    parameter CORE_ID = 0

)(
    
    input  wire clk,
    input  wire reset,
    
    //Memory Response
    input  wire                                   mem_req_ready,
    input  wire                                   mem_rsp_valid,
    input  wire [`DCACHE_MEM_DATA_WIDTH-1 : 0]    mem_rsp_data,
    input  wire [`L1_MEM_TAG_WIDTH-1 : 0]         mem_rsp_tag,
    
    
    //Memory Request
    output wire                                   mem_req_valid,
    output wire                                   mem_req_rw,
    output wire [`DCACHE_MEM_BYTEEN_WIDTH-1 : 0]  mem_req_byteen,
    output wire [`DCACHE_MEM_ADDR_WIDTH-1 : 0]    mem_req_addr,
    output wire [`DCACHE_MEM_DATA_WIDTH-1 : 0]    mem_req_data,
    output wire [`L1_MEM_TAG_WIDTH-1 : 0]         mem_req_tag,
    output wire                                   mem_rsp_ready,
    
    //Busy Flag
    output wire                                   busy
    
);
    
    localparam MEMREQ_DATA_WIDTH = `DCACHE_MEM_DATA_WIDTH;      
    localparam MEMREQ_ADDR_WIDTH = `DCACHE_MEM_ADDR_WIDTH;      
    localparam MEMREQ_TAG_WIDTH  = `L1_MEM_TAG_WIDTH;           
    localparam MEMREQ_DATA_SIZE  = MEMREQ_DATA_WIDTH / 8;   
    
    wire                            mem_req_if_valid;    
    wire                            mem_req_if_rw;       
    wire [MEMREQ_DATA_SIZE-1 : 0]   mem_req_if_byteen;   
    wire [MEMREQ_ADDR_WIDTH-1 : 0]  mem_req_if_addr;     
    wire [MEMREQ_DATA_WIDTH-1 : 0]  mem_req_if_data;     
    wire [MEMREQ_TAG_WIDTH-1 : 0]   mem_req_if_tag;      
    wire                            mem_req_if_ready;  
    
    localparam MEMRSP_DATA_WIDTH = `DCACHE_MEM_DATA_WIDTH;      
    localparam MEMRSP_TAG_WIDTH  = `L1_MEM_TAG_WIDTH;           

    wire                            mem_rsp_if_valid;         
    wire [MEMRSP_DATA_WIDTH-1 : 0]  mem_rsp_if_data;           
    wire [MEMRSP_TAG_WIDTH-1 : 0]   mem_rsp_if_tag;                
    wire                            mem_rsp_if_ready;    
    
    //
    //  Output Memory Request Signals.
    //
    assign mem_req_valid    = mem_req_if_valid;
    assign mem_req_rw       = mem_req_if_rw;
    assign mem_req_byteen   = mem_req_if_byteen;
    assign mem_req_addr     = mem_req_if_addr;
    assign mem_req_data     = mem_req_if_data;
    assign mem_req_tag      = mem_req_if_tag;
    assign mem_req_if_ready = mem_req_ready;
    

    //
    //  Output Memory Response Signals.
    //
    assign mem_rsp_if_valid = mem_rsp_valid;
    assign mem_rsp_if_data  = mem_rsp_data;
    assign mem_rsp_if_tag   = mem_rsp_tag;
    assign mem_rsp_ready    = mem_rsp_if_ready;
    
    localparam DREQ_NUM_REQS  = `DCACHE_NUM_REQS;      
    localparam DREQ_WORD_SIZE = `DCACHE_WORD_SIZE;     
    localparam DREQ_TAG_WIDTH = `DCACHE_CORE_TAG_WIDTH;
    
    wire [DREQ_NUM_REQS-1 : 0]                                dcache_req_if_valid;    
    wire [DREQ_NUM_REQS-1 : 0]                                dcache_req_if_rw;      
    wire [(DREQ_NUM_REQS*DREQ_WORD_SIZE)-1 : 0]               dcache_req_if_byteen;   
    wire [(DREQ_NUM_REQS*(32-$clog2(DREQ_WORD_SIZE)))-1 : 0]  dcache_req_if_addr;     
    wire [(DREQ_NUM_REQS*(8*DREQ_WORD_SIZE))-1 : 0]           dcache_req_if_data;    
    wire [(DREQ_NUM_REQS*DREQ_TAG_WIDTH)-1 : 0]               dcache_req_if_tag;      
    wire [DREQ_NUM_REQS-1 : 0]                                dcache_req_if_ready;    
    
    
    localparam DRSP_NUM_REQS  = `DCACHE_NUM_REQS;      
    localparam DRSP_WORD_SIZE = `DCACHE_WORD_SIZE;     
    localparam DRSP_TAG_WIDTH = `DCACHE_CORE_TAG_WIDTH;  
    
    wire                                                        dcache_rsp_if_valid;    
    wire [DRSP_NUM_REQS-1 : 0]                                  dcache_rsp_if_tmask;    
    wire [(DRSP_NUM_REQS*(8*DRSP_WORD_SIZE))-1 : 0]             dcache_rsp_if_data;    
    wire [DRSP_TAG_WIDTH-1 : 0]                                 dcache_rsp_if_tag;      
    wire                                                        dcache_rsp_if_ready;    
    
    
    localparam IREQ_WORD_SIZE = `ICACHE_WORD_SIZE;      
    localparam IREQ_TAG_WIDTH = `ICACHE_CORE_TAG_WIDTH; 

    wire                                     icache_req_if_valid;    
    wire [(32-$clog2(IREQ_WORD_SIZE))-1 : 0] icache_req_if_addr;     
    wire [IREQ_TAG_WIDTH-1 : 0]              icache_req_if_tag;      
    wire                                     icache_req_if_ready;    
    
       
    localparam IRSP_WORD_SIZE = `ICACHE_WORD_SIZE;      
    localparam IRSP_TAG_WIDTH = `ICACHE_CORE_TAG_WIDTH;   

    wire                                icache_rsp_if_valid;    
    wire [(8 * IRSP_WORD_SIZE)-1:0]     icache_rsp_if_data;     
    wire [IRSP_TAG_WIDTH-1:0]           icache_rsp_if_tag;      
    wire                                icache_rsp_if_ready;    
    
    
    ///////////////////////
    //                   //  
    //      Pipeline     //
    //                   //
    ///////////////////////
    RV_pipeline #(
    
        .CORE_ID(CORE_ID)
        
    ) pipeline (

        .clk(clk),
        .reset(reset),

        // Dcache core request
        .dcache_req_valid   (dcache_req_if_valid),
        .dcache_req_rw      (dcache_req_if_rw),
        .dcache_req_byteen  (dcache_req_if_byteen),
        .dcache_req_addr    (dcache_req_if_addr),
        .dcache_req_data    (dcache_req_if_data),
        .dcache_req_tag     (dcache_req_if_tag),
        .dcache_req_ready   (dcache_req_if_ready),

        // Dcache core reponse    
        .dcache_rsp_valid   (dcache_rsp_if_valid),
        .dcache_rsp_tmask   (dcache_rsp_if_tmask),
        .dcache_rsp_data    (dcache_rsp_if_data),
        .dcache_rsp_tag     (dcache_rsp_if_tag),
        .dcache_rsp_ready   (dcache_rsp_if_ready),

        // Icache core request
        .icache_req_valid   (icache_req_if_valid),
        .icache_req_addr    (icache_req_if_addr),
        .icache_req_tag     (icache_req_if_tag),
        .icache_req_ready   (icache_req_if_ready),

        // Icache core reponse    
        .icache_rsp_valid   (icache_rsp_if_valid),
        .icache_rsp_data    (icache_rsp_if_data),
        .icache_rsp_tag     (icache_rsp_if_tag),
        .icache_rsp_ready   (icache_rsp_if_ready),

        // Status
        .busy(busy)
        
    );  

    //////////////////////////
    //                      //  
    //      Memory Unit     //
    //                      //
    //////////////////////////
    RV_mem_unit #(
    
        .CORE_ID(CORE_ID),
        .DREQ_NUM_REQS(DREQ_NUM_REQS),
        .DREQ_WORD_SIZE(DREQ_WORD_SIZE),
        .DREQ_TAG_WIDTH(DREQ_TAG_WIDTH),
        .DRSP_NUM_REQS(DRSP_NUM_REQS),
        .DRSP_WORD_SIZE(DRSP_WORD_SIZE),
        .DRSP_TAG_WIDTH(DRSP_TAG_WIDTH),
        .IREQ_TAG_WIDTH(IREQ_TAG_WIDTH),
        .IREQ_WORD_SIZE(IREQ_WORD_SIZE),
        .IRSP_TAG_WIDTH(IRSP_TAG_WIDTH),
        .IRSP_WORD_SIZE(IRSP_WORD_SIZE),
        .MEMREQ_DATA_WIDTH(MEMREQ_DATA_WIDTH),
        .MEMREQ_ADDR_WIDTH(MEMREQ_ADDR_WIDTH),
        .MEMREQ_TAG_WIDTH(MEMREQ_TAG_WIDTH),
        .MEMREQ_DATA_SIZE(MEMREQ_DATA_SIZE),
        .MEMRSP_DATA_WIDTH(MEMRSP_DATA_WIDTH),
        .MEMRSP_TAG_WIDTH(MEMRSP_TAG_WIDTH)
        
    ) mem_unit (

        .clk(clk),
        .reset(reset),

        //  Core <-> D-Cache.   
        /********************************************************
                RV_dcache_req_if_slave --> dcache_req_if_ 
        ********************************************************/
        .dcache_req_if_valid(dcache_req_if_valid),
        .dcache_req_if_rw(dcache_req_if_rw),
        .dcache_req_if_byteen(dcache_req_if_byteen),
        .dcache_req_if_addr(dcache_req_if_addr),
        .dcache_req_if_data(dcache_req_if_data),
        .dcache_req_if_tag(dcache_req_if_tag), 
        .dcache_req_if_ready(dcache_req_if_ready),

        /********************************************************
                RV_dcache_rsp_if_master --> dcache_rsp_if_ 
        ********************************************************/
        .dcache_rsp_if_valid(dcache_rsp_if_valid),
        .dcache_rsp_if_tmask(dcache_rsp_if_tmask),
        .dcache_rsp_if_data(dcache_rsp_if_data),
        .dcache_rsp_if_tag(dcache_rsp_if_tag),
        .dcache_rsp_if_ready(dcache_rsp_if_ready),
        

        //  Core <-> I-Cache. 
        /********************************************************
                RV_icache_req_if.slave --> icache_req_if_ 
        ********************************************************/   
        .icache_req_if_valid(icache_req_if_valid),
        .icache_req_if_addr(icache_req_if_addr),
        .icache_req_if_tag(icache_req_if_tag),  
        .icache_req_if_ready(icache_req_if_ready), 

        /********************************************************
                RV_icache_rsp_if.master --> icache_rsp_if_ 
        ********************************************************/
        .icache_rsp_if_valid(icache_rsp_if_valid),    
        .icache_rsp_if_data(icache_rsp_if_data),
        .icache_rsp_if_tag(icache_rsp_if_tag),  
        .icache_rsp_if_ready(icache_rsp_if_ready),  

        //  Memory.
        /********************************************************
                RV_mem_req_if_master --> mem_req_if_ 
        ********************************************************/ 
        .mem_req_if_valid(mem_req_if_valid),   
        .mem_req_if_rw(mem_req_if_rw),
        .mem_req_if_byteen(mem_req_if_byteen),
        .mem_req_if_addr(mem_req_if_addr),
        .mem_req_if_data(mem_req_if_data),
        .mem_req_if_tag(mem_req_if_tag),
        .mem_req_if_ready(mem_req_if_ready),

        /********************************************************
                RV_mem_rsp_if_slave --> mem_rsp_if_ 
        ********************************************************/
        .mem_rsp_if_valid(mem_rsp_if_valid),    
        .mem_rsp_if_data(mem_rsp_if_data),
        .mem_rsp_if_tag(mem_rsp_if_tag),
        .mem_rsp_if_ready(mem_rsp_if_ready)
        
    );
    
    
endmodule
