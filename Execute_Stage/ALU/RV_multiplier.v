`timescale 1ns / 1ps


module RV_multiplier#(

    parameter WIDTHA  = 32,
    parameter WIDTHB  = 32,
    parameter WIDTHP  = 64,  //Width of the  product
    parameter SIGNED  = 0,
    parameter LATENCY = 0

)(
    
    input  wire clk,
    input  wire enable,
    input  wire reset,
    input  wire [WIDTHA-1 : 0] dataa,
    input  wire [WIDTHB-1 : 0] datab,
    output wire [WIDTHP-1 : 0] result
    
);

    wire [WIDTHP-1 : 0] result_temp;
    
    if(SIGNED)
    begin
    
        assign result_temp = $signed(dataa) * $signed(datab);
    
    end
    else begin
    
        assign result_temp = dataa * datab;
    
    end
    
    if(LATENCY == 0)
    begin
        
        assign result = result_temp;
    
    end
    else begin
    
        reg [WIDTHP-1 : 0] pipe_results [LATENCY-1 : 0];
        genvar i;
        always@(posedge clk)
        begin
        
            if(enable)
            begin
            
                pipe_results[0] <= result_temp;
                
            end
        
        end
        
        for (i = 1; i < LATENCY; i=i+1) 
        begin
            
            always@(posedge clk)
            begin
            
                if(enable)
                begin
                    
                    pipe_results[i] <= pipe_results[i-1];
                
                end
            
            end
        
        end
        
        assign result = pipe_results[LATENCY-1];
        
    end

endmodule
