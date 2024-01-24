`timescale 1ns / 1ps

/*
    This module does Parallel Prefix Computation using Kogge-Stone style prefix tree
    for one of three operations : XOR, AND, OR. 
    Parallel Prefix (also called a Scan) is an important calculation for parallel computing
    which takes an input d and outputs:
    {d[0], (d[0] ? d[1]), (d[0] ? d[1] ? d[2]), (d[0] ? d[1] ? d[2] ? d[3]), etc..}
    Where "?" is one of the three operations (XOR, AND, OR). 
*/

module RV_scan#(

    parameter N       = 7, 
    parameter OP      = 2,
    parameter REVERSE = 0 

)(

    input  wire [N-1 : 0] data_in,
    output wire [N-1 : 0] data_out

);

    genvar i;
    generate
    
        localparam LOGN = $clog2(N);
        
        wire [N-1 : 0] t [LOGN : 0];
        
        wire [N-1 : 0] data_in_reversed;
        for(i = 0 ; i < N ; i = i + 1)
        begin
        
            assign data_in_reversed[i] = data_in[N-1-i];
        
        end
        
        //  Reversed : High to Low, so input the data in its original order.
        if (REVERSE)
         begin
         
            assign t[0] = data_in;
            
        end 
        else begin
        
           assign t[0] = data_in_reversed; 
        
        end
        
        if((N == 2) && (OP == 1))
        begin
            
            //  {d[0], (d[0] & d[1])}
            assign t[LOGN] = {t[0][1], &t[0][1:0]};
        
        end
        else if((N == 3) && (OP == 1))
        begin
            
            assign t[LOGN] = {t[0][2], &t[0][2:1], &t[0][2:0]};
        
        end
        else if((N == 4) && (OP == 1))
        begin
            
            //  {d[0], (d[0] & d[1]), (d[0] & d[1] & d[2]), (d[0] & d[1] & d[2] & d[3])}
            assign t[LOGN] = {t[0][3], &t[0][3:2], &t[0][3:1], &t[0][3:0]};
        
        end
        else begin  
              
            //  The General Case:
            //      It is a series of LOGN steps. Each step performs the OP (XOR, AND, OR)
            //      on the previous step and a shifted version of it. Each step (i) the shifted
            //      version is shifted by 2^i. This accomplishes the computation described above:
            //      {d[0], (d[0] ? d[1]), (d[0] ? d[1] ? d[2]), (d[0] ? d[1] ? d[2] ? d[3]), etc..}
            //      Since in each step, the shifted version at each index holds previously computed 
            //      bits. 
            //      For example: when computing (d[0] ? d[1] ? d[2] ? d[3]), 
            //      (d[0] ? d[1]) is already computed for the bits on the left while (d[2] ? d[3]) is being computed.
            //      So it is shifted to the right by 2^1 and XOR'd with (d[2] ? d[3]).
            
            wire [N-1 : 0] fill;
            for(i = 0 ; i < LOGN ; i = i + 1)
            begin
            
                wire [N-1 : 0] shifted = ({fill , t[i]} >> (1 << i));
                
                if(OP == 0)
                begin
                
                    assign fill   = {N{1'b0}};        //  What's filled on the left when shifting to the left. XOR'ing with 0 does nothing.
                    assign t[i+1] = t[i] ^ shifted;
                
                end
                
                if(OP == 1)
                begin
                
                    assign fill   = {N{1'b1}};        //  What's filled on the left when shifting to the left. AND'ing with 1 does nothing.
                    assign t[i+1] = t[i] & shifted;
                
                end
                
                if(OP == 2)
                begin
                
                    assign fill   = {N{1'b0}};        //  What's filled on the left when shifting to the left. OR'ing with 0 does nothing.
                    assign t[i+1] = t[i] | shifted;
                
                end
                            
            end
        
        
        end
        
        //  Reversed : High to Low, so output the data in its original order.
        if (REVERSE) 
        begin
        
            assign data_out = t[LOGN];
            
        end 
        
        //  Otherwise, reverse the data so it's back to {MSB..LSB}.
        else begin
        
            for (i = 0; i < N; i = i + 1) 
            begin
            
                assign data_out[i] = t[LOGN][N-1-i];
                
            end   
                 
        end
         
    
    endgenerate


endmodule
