`timescale 1ns / 1ps

`include "RV_define.vh"

module RV_fp_sqrt#(
    
    parameter TAGW  = 2,
    parameter LANES = 2

)(

    input  wire clk,
    input  wire reset,
    
    input  wire                        valid_in,
    input  wire                        ready_out,
    input  wire [TAGW-1 : 0]           tag_in,
    input  wire [`INST_FRM_BITS-1 : 0] frm,
    input  wire [(LANES*32)-1 : 0]     dataa,
    
    output wire                        ready_in,
    output wire [(LANES*32)-1 : 0]     result,
    output wire                        has_fflags,
    output wire [LANES-1 : 0]          fflags_NV, // 4-Invalid
    output wire [LANES-1 : 0]          fflags_DZ, // 3-Divide by zero
    output wire [LANES-1 : 0]          fflags_OF, // 2-Overflow
    output wire [LANES-1 : 0]          fflags_UF, // 1-Underflow
    output wire [LANES-1 : 0]          fflags_NX, // 0-Inexact
    output wire [TAGW-1:0]             tag_out,
    output wire                        valid_out

);

    wire [31 : 0] dataa_2d  [LANES-1 : 0];
    wire [31 : 0] result_2d [LANES-1 : 0];
    
    genvar i;
    generate
    
        for(i = 0; i < LANES; i = i + 1)
        begin
        
            assign dataa_2d[i] = dataa[((i+1)*32)-1 : i*32];
            assign result[((i+1)*32)-1 : i*32] = result_2d[i];
        
        end
    
    endgenerate
    
    wire stall  = ~ready_out && valid_out;
    wire enable = ~stall;
    wire push   = valid_in  && ready_in; 
    wire pop    = valid_out && ready_out;
    wire start  = push && enable;
    
    wire [LANES-1 : 0] busy, valid;
    
    generate
    
        for(i = 0; i < LANES; i = i + 1)
        begin
        
            fp_sqrt sqrt(
            
                .clk(clk),
                .reset(reset),
                .start(start),
                .dataIn(dataa_2d[i]),
                
                .busy(busy[i]),
                .valid(valid[i]),
                .result(result_2d[i])
                
            );    
        
        end
    
    endgenerate
    
    wire is_busy = &busy;
    assign ready_in  = !is_busy && enable;
    assign valid_out = &valid;
    
    RV_shift_register #(
    
        .DATAW  (TAGW),
        .DEPTH  (0),
        .RESETW (TAGW)
        
    ) shift_reg (
    
        .clk      (clk),
        .reset    (reset),
        .enable   (pop),
        .data_in  (tag_in),
        .data_out (tag_out)
        
    );
    
    assign has_fflags = 0;
    assign fflags_NV  = {LANES{1'b0}};
    assign fflags_DZ  = {LANES{1'b0}};
    assign fflags_OF  = {LANES{1'b0}};
    assign fflags_UF  = {LANES{1'b0}};
    assign fflags_NX  = {LANES{1'b0}};
    
endmodule
