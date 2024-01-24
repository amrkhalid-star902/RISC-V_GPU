`timescale 1ns / 1ps

`include "RV_platform.vh"
 
module RV_elastic_buffer#(

    parameter DATAW     = 1,
    parameter SIZE      = 4,
    parameter OUT_REG   = 0

)(
    
    input wire                clk,
    input wire                reset,
    input wire                valid_in,
    input wire                ready_out,
    input wire [DATAW-1 : 0]  data_in,
    
    output wire               ready_in,
    output wire               valid_out,
    output wire [DATAW-1 : 0] data_out
    
);

    generate
    
        if(SIZE == 0)
        begin

            `UNUSED_VAR (clk)                 
            `UNUSED_VAR (reset)
            assign valid_out = valid_in;
            assign data_out  = data_in;
            assign ready_in  = ready_out;
        
        end
        else if(SIZE == 2)
        begin
        
            RV_skid_buffer #(
            
                .DATAW   (DATAW),
                .OUT_REG (OUT_REG)
                
            ) queue (
            
                .clk       (clk),
                .reset     (reset),
                .valid_in  (valid_in),        
                .data_in   (data_in),
                .ready_in  (ready_in),      
                .valid_out (valid_out),
                .data_out  (data_out),
                .ready_out (ready_out)
                
            );
        
        end
        else begin
            
            wire empty, full;
            wire push = valid_in && ready_in;
            wire pop  = valid_out && ready_out;
    
            RV_fifo_queue #(
            
                .DATAW   (DATAW),
                .SIZE    (SIZE),
                .OUT_REG (OUT_REG)
                
            ) queue (
            
                .clk    (clk),
                .reset  (reset),
                .push   (push),
                .pop    (pop),
                .data_in(data_in),
                .data_out(data_out),    
                .empty  (empty),
                .full   (full),
                .alm_empty(),
                .alm_full(),
                .size()
                
            );
    
            assign ready_in  = ~full;
            assign valid_out = ~empty;
        
        end
    
    endgenerate

endmodule
