`timescale 1ns / 1ps

`include "RV_cache_define.vh"


module RV_tag_access#(

    parameter CACHE_ID          = 0,
    parameter BANK_ID           = 0,
    parameter CACHE_SIZE        = 1,
    parameter CACHE_LINE_SIZE   = 1,
    parameter NUM_BANKS         = 1,
    parameter NUM_PORTS         = 1,
    parameter WORD_SIZE         = 4,
    parameter BANK_ADDR_OFFSET  = 0

)(

    input wire clk,
    input wire reset,
    
    input  wire                              stall,
    input  wire                              lookup,
    input  wire [`LINE_ADDR_WIDTH-1:0]       addr,
    input  wire                              fill,
    input  wire                              flush,
    output wire                              tag_match

);

    wire [`TAG_SELECT_BITS-1 : 0] read_tag;
    wire read_valid;
    
    wire [`LINE_SELECT_BITS-1:0]  line_addr  = addr[`LINE_SELECT_BITS-1:0];
    wire [`TAG_SELECT_BITS-1 : 0] line_tag   = `LINE_TAG_ADDR(addr);
    
    
    RV_sp_ram #(
    
        .DATAW       (`TAG_SELECT_BITS + 1), 
        .SIZE        (`LINES_PER_BANK),
        .INIT_ENABLE (0)
        
    ) tag_store (
    
        .clk   (clk),    
        .addr  (line_addr),                 
        .wren  (fill || flush),             
        .wdata ({!flush, line_tag}),        
        .rdata ({read_valid, read_tag})    
        
    );
    
    
    assign tag_match = read_valid && (line_tag == read_tag);  

endmodule
