`timescale 1ns / 1ps



module VX_adder_tree#(

    parameter N     = 4,
    parameter DATAW = 8

)(
    
    input wire clk,
    input wire reset,
    
    input wire en,
    input wire [(N*DATAW)-1 : 0] dataIn,
    
    output reg [DATAW-1 : 0] dout,
    output reg active
    
);
    
    localparam LOGN = $clog2(N);
    localparam  TL      =   (1 << LOGN) - 1;        //  2^n - 1     (Index of the leftmost leaf of the tree, the starting position of the first input).
    localparam  TN      =   (1 << (LOGN+1)) - 1;    //  2^(n+1) - 1 (Index of the rightmost leaf of the tree, the starting position of the last input).
    
    //Converting flat input to 2d
    wire [DATAW-1 : 0] data2d [N-1 : 0];
    wire [DATAW-1 : 0] d_n  [TN-1:0];          //  An Array for the Data signals in the tree.    
    wire [DATAW-1 : 0] result;
    
    genvar i , j;
    generate
        
        //  Reassigning the flattened input port into a 2D array.
        for (i = 0; i < N; i = i + 1) begin
        
            assign  data2d[i]   =   dataIn[(i+1) * DATAW - 1:i * DATAW];
            
        end
        
        //  Setting the inputs and valid signals as the leaves of the tree (In reverse order if REVERSE is set).
        for (i = 0; i < N; i = i + 1) begin
        
            assign d_n[TL+i] = data2d[i];
            
        end
        
        //  If N is not a power of 2, the binary tree will have more leaves than inputs (Ex: if N = 10, there will be 16 leaves).
        //  Setting the extra leaves as 0 for Valid signals and Data.
        for (i = TL+N; i < TN; i = i + 1) begin

            assign d_n[i] = 0;
            
        end
        
        //  Going through the tree from the leaves up and setting each parent to the first valid signal out of the two children.
        for (j = 0; j < LOGN; j = j + 1) begin
            for (i = 0; i < (2**j); i = i + 1) begin
        
                
                assign d_n[2**j-1 + i] = d_n[2**(j+1)-1 + i*2] + d_n[2**(j+1)-1 + i*2+1]; 
        
            end
        end  
        
        assign result = d_n[0];
        
    endgenerate
    
    always@(posedge clk)
    begin
    
        if(reset)
        begin
        
             dout   <= 0;  
             active <= 0;     
        
        end
        else begin
        
            if(en)
            begin
            
                dout    <= result;
                active  <= 1;
                
            end
            else begin
            
                dout    <= 0;
                active  <= 0;
            
            end
            
        end
        
    end

endmodule
