`timescale 1ns / 1ps

`include "RV_platform.vh"

module RV_shift_register#(

    parameter DATAW  = 8,
    parameter RESETW = 0,
    parameter DEPTH  = 2,
    parameter DEPTHW = $clog2(DEPTH)

)(

    input  wire clk,
    input  wire reset,
    input  wire enable,
    input  wire [DATAW-1 : 0] data_in,
    output wire [DATAW-1 : 0] data_out

);

    generate
    
        if(RESETW != 0)
        begin
        
            if(RESETW == DATAW)
            begin
        
                RV_shift_register_wr #(
                
                    .DATAW (DATAW),
                    .DEPTH (DEPTH)
                    
                ) sr (
                    .clk      (clk),
                    .reset    (reset),
                    .enable   (enable),
                    .data_in  (data_in),
                    .data_out (data_out)
                );
        
            end
            else begin
            
                RV_shift_register_wr #(
                
                    .DATAW (RESETW),
                    .DEPTH (DEPTH)
                    
                ) sr (
                    .clk      (clk),
                    .reset    (reset),
                    .enable   (enable),
                    .data_in  (data_in[DATAW-1:DATAW-RESETW]),
                    .data_out (data_out[DATAW-1:DATAW-RESETW])
                );
                
                RV_shift_register_nr #(
                
                    .DATAW (DATAW-RESETW),
                    .DEPTH (DEPTH)
                    
                ) sr_nr (
                    .clk      (clk),
                    .enable   (enable),
                    .data_in  (data_in[DATAW-RESETW-1:0]),
                    .data_out (data_out[DATAW-RESETW-1:0])
                );
            
            
            end
        
        end
        else begin
        
            `UNUSED_VAR (reset)
            // If RESETW is zero, generate a shift register that does not support reset.
            RV_shift_register_nr #(
            
                .DATAW (DATAW),
                .DEPTH (DEPTH)
                
            ) sr (
                .clk      (clk),
                .enable   (enable),
                .data_in  (data_in),
                .data_out (data_out)
            );
        
        
        end
        
    endgenerate

endmodule
