`timescale 1ns / 1ps

 `include "RV_platform.vh"


//This module is used to count the number of ones in input vector

module RV_popcount#(

    parameter MODEL = 1,
    parameter N     = 4,
    parameter M     = $clog2(N+1)

)(
    
    input  wire [N-1 : 0] in_i,
    output wire [M-1 : 0] cnt_o
    
);

    if(N == 1)
    begin
    
        assign cnt_o = in_i;
    
    end
    else if(MODEL == 1)
    begin
        
        //Tree base approach
        localparam PN    = 1 << $clog2(N);
        localparam LOGPN = $clog2(PN);
        
        wire [M-1:0] tmp [0:PN-1][0:PN-1];
        
        for (genvar i = 0; i < N; i = i + 1) 
        begin  
        
            assign tmp[0][i] = in_i[i];
            
        end

        for (genvar i = N; i < PN; i = i + 1) 
        begin        
        
            assign tmp[0][i] = 0;
            
        end

        for (genvar j = 0; j < LOGPN; j = j + 1) 
        begin
        
            for (genvar i = 0; i < (1 << (LOGPN-j-1)); i = i + 1) 
            begin
            
                assign tmp[j+1][i] = tmp[j][i*2] + tmp[j][i*2+1];
                
            end
            
        end

        assign cnt_o = tmp[LOGPN][0];
    
    end
    else begin
    
        //For loop based approach
        reg [M-1:0] count_ones;
        integer idx;

        always@(*) 
        begin
        
          count_ones = 'b0;
          for( idx = 0; idx<N; idx = idx + 1) 
          begin
          
            count_ones = count_ones + {{M-1{1'b0}},in_i[idx]};
            
          end
          
        end
        assign cnt_o = count_ones;
    
    end

endmodule
