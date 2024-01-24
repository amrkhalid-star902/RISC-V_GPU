`timescale 1ns / 1ps


module RV_stream_demux#(

    parameter NUM_REQS     = 2,
    parameter LANES        = 1,
    parameter DATAW        = 8,
    parameter BUFFERED     = 0,
    parameter LOG_NUM_REQS = (((NUM_REQS) > 1) ? $clog2(NUM_REQS) : 1) 

)(
    
    input  wire clk,
    input  wire reset,
    
    input  wire [(LANES*LOG_NUM_REQS-1) : 0]        sel_in,
    input  wire [LANES-1 : 0]                       valid_in,
    input  wire [(LANES*DATAW-1) : 0]               data_in,  
    input  wire [(NUM_REQS*LANES-1) : 0]            ready_out,
    
    output wire [LANES-1 : 0]                       ready_in,
    output wire [(NUM_REQS*LANES-1) : 0]            valid_out,
    output wire [(NUM_REQS*LANES*DATAW-1) : 0]      data_out
    
);
    
    genvar i , j;
    generate
    
        if(NUM_REQS > 1)
        begin
        
            for(j = 0; j < LANES; j = j + 1)
            begin
            
                reg  [NUM_REQS-1:0]  valid_in_sel;
                wire [NUM_REQS-1:0]  ready_in_sel; 
                   
                always@(*)
                begin
               
                    valid_in_sel            = 0;
                    valid_in_sel[sel_in[(j+1)*LOG_NUM_REQS-1 : j*LOG_NUM_REQS]] = valid_in[j];
               
                end
                
                assign ready_in[j] = ready_in_sel[sel_in[(j+1)*LOG_NUM_REQS-1 : j*LOG_NUM_REQS]];
                
                for(i = 0; i < NUM_REQS; i = i + 1)
                begin
                
                    RV_skid_buffer #(
                    
                        .DATAW    (DATAW),
                        .PASSTHRU (0 == BUFFERED),
                        .OUT_REG  (2 == BUFFERED)
                        
                    ) out_buffer (
                    
                        .clk(clk),
                        .reset(reset),
                        .valid_in(valid_in_sel[i]),
                        .data_in(data_in[(j+1)*DATAW-1 : j*DATAW]),
                        .ready_in(ready_in_sel[i]),
                        .valid_out(valid_out[(i*LANES) + j]),
                        .data_out(data_out[(((i*LANES) + j)+1)*DATAW-1 : ((i*LANES) + j)*DATAW]),
                        .ready_out(ready_out[(i*LANES) + j])
                        
                    );       
                
                end
                
            end
        
        end
        else begin
        
            assign valid_out = valid_in;        
            assign data_out  = data_in;
            assign ready_in  = ready_out;
        
        end
    
    endgenerate

endmodule
