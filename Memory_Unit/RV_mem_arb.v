`timescale 1ns / 1ps

`include "RV_define.vh"


module RV_mem_arb#(

    parameter NUM_REQS      = 2, 
    parameter DATA_WIDTH    = 8,
    parameter ADDR_WIDTH    = 4,
    parameter TAG_IN_WIDTH  = 3,    
    parameter TAG_SEL_IDX   = 1,
    parameter BUFFERED_REQ  = 0,
    parameter BUFFERED_RSP  = 0,
    parameter TYPE          = "P",
    parameter DATA_SIZE     = (DATA_WIDTH / 8),
    parameter LOG_NUM_REQS  = `CLOG2(NUM_REQS),
    parameter TAG_OUT_WIDTH = TAG_IN_WIDTH + LOG_NUM_REQS

)(

    input  wire clk,
    input  wire reset,
    
    input  wire [NUM_REQS-1 : 0]                  req_valid_in,
    input  wire [(NUM_REQS*TAG_IN_WIDTH)-1 : 0]   req_tag_in,
    input  wire [(NUM_REQS*ADDR_WIDTH)-1 : 0]     req_addr_in,
    input  wire [NUM_REQS-1 : 0]                  req_rw_in,
    input  wire [(NUM_REQS*DATA_SIZE)-1 : 0]      req_byteen_in,
    input  wire [(NUM_REQS*DATA_WIDTH)-1 : 0]     req_data_in,
    input  wire                                   req_ready_out,
    
    //Input Response
    input  wire                                   rsp_valid_in,
    input  wire [TAG_OUT_WIDTH-1 : 0]             rsp_tag_in,
    input  wire [DATA_WIDTH-1 : 0]                rsp_data_in,
    input  wire [NUM_REQS-1 : 0]                  rsp_ready_out,
    
    //Output Request
    output wire [NUM_REQS-1 : 0]                  req_ready_in,
    output wire                                   req_valid_out,
    output wire [TAG_OUT_WIDTH-1 : 0]             req_tag_out,
    output wire [ADDR_WIDTH-1 : 0]                req_addr_out,
    output wire                                   req_rw_out,
    output wire [DATA_SIZE-1 : 0]                 req_byteen_out,
    output wire [DATA_WIDTH-1 : 0]                req_data_out,
    
    //Output Response
    output wire                                   rsp_ready_in, 
    output wire [NUM_REQS-1 : 0]                  rsp_valid_out,
    output wire [(NUM_REQS*TAG_IN_WIDTH)-1 : 0]   rsp_tag_out,
    output wire [(NUM_REQS*DATA_WIDTH)-1 : 0]     rsp_data_out

);

    localparam REQ_DATAW = TAG_OUT_WIDTH + ADDR_WIDTH + 1 + DATA_SIZE + DATA_WIDTH;
    localparam RSP_DATAW = TAG_IN_WIDTH + DATA_WIDTH;
    
    wire [TAG_IN_WIDTH-1 : 0] req_tag_in_2d    [NUM_REQS-1 : 0];
    wire [ADDR_WIDTH-1 : 0]   req_addr_in_2d   [NUM_REQS-1 : 0];
    wire [DATA_SIZE-1 : 0]    req_byteen_in_2d [NUM_REQS-1 : 0];
    wire [DATA_WIDTH-1 : 0]   req_data_in_2d   [NUM_REQS-1 : 0];
    
    wire [TAG_IN_WIDTH-1 : 0] rsp_tag_out_2d   [NUM_REQS-1 : 0];
    wire [DATA_WIDTH-1 : 0]   rsp_data_out_2d  [NUM_REQS-1 : 0];
    
    genvar i;
    generate
    
        for (i = 0; i < NUM_REQS; i = i + 1) 
        begin
        
            assign  req_tag_in_2d[i]       =   req_tag_in[(i+1) * TAG_IN_WIDTH - 1:i * TAG_IN_WIDTH];
            assign  req_addr_in_2d[i]      =   req_addr_in[(i+1) * ADDR_WIDTH - 1:i * ADDR_WIDTH];
            assign  req_byteen_in_2d[i]    =   req_byteen_in[(i+1) * DATA_SIZE - 1:i * DATA_SIZE];
            assign  req_data_in_2d[i]      =   req_data_in[(i+1) * DATA_WIDTH - 1:i * DATA_WIDTH];
    
            assign  rsp_tag_out[(i+1) * TAG_IN_WIDTH - 1:i * TAG_IN_WIDTH]    =   rsp_tag_out_2d[i];
            assign  rsp_data_out[(i+1) * DATA_WIDTH - 1:i * DATA_WIDTH]       =   rsp_data_out_2d[i];
            
        end
        
    endgenerate
        
     
    generate
    
        if(NUM_REQS > 1)
        begin
        
            wire [(NUM_REQS*REQ_DATAW)-1 : 0] req_data_in_merged;
            for (i = 0; i < NUM_REQS; i = i + 1)
            begin
            
                wire [TAG_OUT_WIDTH-1 : 0] req_tag_in_w;
                RV_bits_insert #( 
                
                    .N   (TAG_IN_WIDTH),
                    .S   (LOG_NUM_REQS),
                    .POS (TAG_SEL_IDX)
                    
                ) bits_insert (
                
                    .data_in  (req_tag_in_2d[i]),
                    .sel_in   (i),
                    .data_out (req_tag_in_w)
                    
                );
                
                assign req_data_in_merged[((i+1) * REQ_DATAW) -1: i * REQ_DATAW] = 
                                         {req_tag_in_w, req_addr_in_2d[i], req_rw_in[i], req_byteen_in_2d[i], req_data_in_2d[i]};
            
            end
            
            //  Use the Stream Arbiter to choose Request to Grant.
            RV_stream_arbiter #(         
               
                .NUM_REQS (NUM_REQS),
                .DATAW    (REQ_DATAW),
                .BUFFERED (BUFFERED_REQ),
                .TYPE     (TYPE)
            
            ) req_arb (
            
                .clk       (clk),
                .reset     (reset),
                .valid_in  (req_valid_in),
                .data_in   (req_data_in_merged),
                .ready_in  (req_ready_in),
                .valid_out (req_valid_out),
                .data_out  ({req_tag_out, req_addr_out, req_rw_out, req_byteen_out, req_data_out}), //  This outputs the Tag, Address, RW, ByteEn, and Data of the Granted Request to Memory.
                .ready_out (req_ready_out)
                
            );
            
            wire [(NUM_REQS * RSP_DATAW)-1 : 0] rsp_data_out_merged;
            wire [LOG_NUM_REQS-1 : 0] rsp_sel = rsp_tag_in[(TAG_SEL_IDX+LOG_NUM_REQS)-1 : TAG_SEL_IDX];
            wire [TAG_IN_WIDTH-1 : 0] rsp_tag_in_w;
            
            //  Remove each request's index from the tag.
            RV_bits_remove #( 
            
                .N   (TAG_OUT_WIDTH),
                .S   (LOG_NUM_REQS),
                .POS (TAG_SEL_IDX)
                
            ) bits_remove (
            
                .data_in  (rsp_tag_in),
                .data_out (rsp_tag_in_w)
                
            );
            
            //  Use the Stream Demux to output the correct response back to each Request.
            RV_stream_demux #(
            
                .NUM_REQS (NUM_REQS),
                .DATAW    (RSP_DATAW),
                .BUFFERED (BUFFERED_RSP)
                
            ) rsp_demux (
            
                .clk       (clk),
                .reset     (reset),
                .sel_in    (rsp_sel),
                .valid_in  (rsp_valid_in),
                .data_in   ({rsp_tag_in_w, rsp_data_in}),   //  Data and the Requested Tag.
                .ready_in  (rsp_ready_in),
                .valid_out (rsp_valid_out),
                .data_out  (rsp_data_out_merged),   //  Data and the Requested Tag for every Request.
                .ready_out (rsp_ready_out)
                
            );
            
            for (i = 0; i < NUM_REQS; i = i + 1) 
            begin
            
                assign {rsp_tag_out_2d[i], rsp_data_out_2d[i]} = rsp_data_out_merged[((i+1) * RSP_DATAW) -1: i * RSP_DATAW];
            
            end   
        
        end
        else begin
        
            assign req_valid_out  = req_valid_in;
            assign req_tag_out    = req_tag_in;
            assign req_addr_out   = req_addr_in;
            assign req_rw_out     = req_rw_in;
            assign req_byteen_out = req_byteen_in;
            assign req_data_out   = req_data_in;
            assign req_ready_in   = req_ready_out;
    
            assign rsp_valid_out  = rsp_valid_in;
            assign rsp_tag_out    = rsp_tag_in;
            assign rsp_data_out   = rsp_data_in;
            assign rsp_ready_in   = rsp_ready_out;
        
        end
    
    endgenerate

endmodule
