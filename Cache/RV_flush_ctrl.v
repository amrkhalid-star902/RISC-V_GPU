`timescale 1ns / 1ps

`include "RV_cache_define.vh"


module RV_flush_ctrl#(

    parameter CACHE_SIZE        = 16384,
    parameter CACHE_LINE_SIZE   = 1, 
    parameter NUM_BANKS         = 1 

)(

    input wire clk,
    input wire reset,
    
    output wire [`LINE_SELECT_BITS-1:0] addr_out,
    output wire                         valid_out

);

    reg flush_enable; 
    reg [`LINE_SELECT_BITS-1:0] flush_ctr;
    
    always@(posedge clk)
    begin
    
        if(reset)
        begin
        
            flush_enable <= 1;
            flush_ctr    <= 0;
        
        end
        else begin
        
            if(flush_enable)
            begin
            
                if (flush_ctr == ((2 ** `LINE_SELECT_BITS)-1)) 
                begin
                
                    flush_enable <= 0;  //  Disable Flush.
                
                end
                
                flush_ctr <= flush_ctr + 1;
            
            end
        
        end
    
    end
    
    assign addr_out  = flush_ctr;       
    assign valid_out = flush_enable;


endmodule
