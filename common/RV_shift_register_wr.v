`timescale 1ns / 1ps



module RV_shift_register_wr#(

    parameter DATAW = 8,
    parameter DEPTH = 2,
    parameter DEPTHW = $clog2(DEPTH)

)(

    input  wire clk,
    input  wire reset,
    input  wire enable,
    input  wire [DATAW-1 : 0] data_in,
    output wire [DATAW-1 : 0] data_out

);

    reg [DATAW-1:0]  entries   [DEPTH-1:0];
    integer i , r;
    
    always@(posedge clk)
    begin
    
        if(reset)
        begin
        
            for(r = 0 ; r < DEPTH ; r = r + 1)
            begin
            
                entries[r] <= 0;
            
            end
        
        end
        
        else if(enable) begin
        
            for(i = DEPTH-1; i > 0 ; i = i - 1)
            begin
            
                entries[i] <= entries[i-1]; 
                entries[0] <= data_in;
            end
        
        end
    
    end
    
    
    assign data_out = entries[DEPTH-1];



endmodule
