`timescale 1ns / 1ps



module VX_accumlate#(

    parameter DATAW = 8,
    parameter N     = 4

)(
    
    input  wire clk,
    input  wire reset,
    input  wire enable,
    input  wire [DATAW-1 : 0] dataIn,
    output wire [DATAW-1 : 0] dataOut,
    output wire valid_out
    
);

    reg [DATAW-1 : 0] accum_reg;
    //reg valid_r;
    reg [$clog2(N) : 0] counter;
    
    always@(posedge clk)
    begin
    
        if(reset)
        begin
        
            accum_reg <= 0;
            counter   <= N;
            //valid_r <= 0;
            
        end
        else begin
            //valid_r <= ~(|counter);
            if(enable)
            begin
            
                accum_reg <= valid_out ? dataIn : accum_reg + dataIn;
                counter   <= valid_out ? N-1 : counter - 1'b1;
                
            
            end
        
        end
    
    end
    
    assign valid_out = ~(|counter);
    assign dataOut   = accum_reg;
    
endmodule
