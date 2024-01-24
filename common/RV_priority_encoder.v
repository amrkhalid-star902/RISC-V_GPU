`timescale 1ns / 1ps


module RV_priority_encoder#(

    parameter N       = 8,
    parameter REVERSE = 0,
    parameter MODEL   = 2, 
    parameter LN      =  (((N) > 1) ? $clog2(N) : 1) 

)(
    
    input  wire [N-1 : 0]  data_in, 
    output wire [N-1 : 0]  onehot,
    output wire [LN-1 : 0] index,
    output wire            valid_out
    
);

    integer j;
    genvar  i;
    
    wire [N-1 : 0] reversed;
    
    generate
    
        if(REVERSE)
        begin
            
            for ( i = 0; i < N; i =i+1)
            begin
           
                assign reversed[N-i-1] = data_in[i];
           
            end 
        
        end
        else begin
        
            assign reversed = data_in;
        
        end
        
        if(N == 1)
        begin
        
            assign onehot    = reversed;
            assign index     = 0;
            assign valid_out = reversed;
        
        end
        else if(N == 2)
        begin
        
           assign onehot    = {~reversed[0], reversed[0]};
           assign index     = ~reversed[0];
           assign valid_out = (| reversed);
        
        end
        else if(MODEL == 1)
        begin
        
            wire [N-1 : 0] scan_lo;
            RV_scan #(
            
                .N  (N),
                .OP (2)
                
            ) scan (
            
                .data_in  (reversed), // Input data to scan
                .data_out (scan_lo)   // Output of the scan
            
            );
            
            RV_lzc #(
            
                .N (N)
                
            ) lzc (
            
                .in_i   (reversed),    // Input data to count leading zeroes for
                .cnt_o  (index),       // Output of the leading zeroes count
                .valid_o() 
            
            );
            
            assign onehot    = scan_lo & {(~scan_lo[N-2:0]), 1'b1};
            assign valid_out = scan_lo[N-1];
        
        end
        else begin
        
            reg [LN-1 : 0] index_r;
            reg [N-1 : 0]  onehot_r;
            
            always@(*)
            begin
            
                index_r  = {LN{1'bx}}; 
                onehot_r = {N{1'bx}};
                   
                for(j = N-1 ; j >= 0 ; j = j-1)
                begin
               
                    if(reversed[j])
                    begin
                    
                        index_r     = j[LN-1 : 0];
                        onehot_r    = 0;
                        onehot_r[j] = 1'b1;
                    
                    end
               
                end
            
            end
            
            assign index     = index_r;
            assign onehot    = onehot_r;
            assign valid_out = (| reversed); 
        
        end
    
    endgenerate

endmodule
