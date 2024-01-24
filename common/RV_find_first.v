`timescale 1ns / 1ps

//`include "RV_clog2.vh"

module RV_find_first#(
    
    parameter N       = 4,
    parameter DATAW   = 2,
    parameter REVERSE = 0
    
)(

    input   wire    [(DATAW * N)-1:0]   data_i,     //  Input Data.
    input   wire    [N-1:0]             valid_i,    //  Input Valid Signals.
    output  wire    [DATAW-1:0]         data_o,     //  Output (First) Data.
    output  wire                        valid_o     //  Output Valid Signal.

);

    localparam  LOGN    =   $clog2(N);
    localparam  TL      =   (1 << LOGN) - 1;        //  2^n - 1     (Index of the leftmost leaf of the tree, the starting position of the first input).
    localparam  TN      =   (1 << (LOGN+1)) - 1;    //  2^(n+1) - 1 (Index of the rightmost leaf of the tree, the starting position of the last input).
    
    wire    [DATAW-1:0] data_2D [N-1:0];        //  2D Array of the flattened data input.
    wire    [TN-1:0]    s_n;                    //  An Array for the Valid signals in the tree.
    wire    [DATAW-1:0] d_n  [TN-1:0];          //  An Array for the Data signals in the tree.
    
    genvar i;
    genvar j;
    
    generate
    
        //  Reassigning the flattened input port into a 2D array.
        for (i = 0; i < N; i = i + 1) begin
            assign  data_2D[i]   =   data_i[(i+1) * DATAW - 1:i * DATAW];
        end
        
        
        //  Setting the inputs and valid signals as the leaves of the tree (In reverse order if REVERSE is set).
        for (i = 0; i < N; i = i + 1) begin
            assign s_n[TL+i] = REVERSE ? valid_i[N-1-i] : valid_i[i];
            assign d_n[TL+i] = REVERSE ? data_2D[N-1-i] : data_2D[i];
        end
        
        //  If N is not a power of 2, the binary tree will have more leaves than inputs (Ex: if N = 10, there will be 16 leaves).
        //  Setting the extra leaves as 0 for Valid signals and Data.
        for (i = TL+N; i < TN; i = i + 1) begin
            assign s_n[i] = 0;
            assign d_n[i] = 0;
        end
        
        //  Going through the tree from the leaves up and setting each parent to the first valid signal out of the two children.
        for (j = 0; j < LOGN; j = j + 1) begin
            for (i = 0; i < (2**j); i = i + 1) begin
        
                // Setting the valid of the parent if either of the children are valid.
                assign s_n[2**j-1 + i] = s_n[2**(j+1)-1 + i*2] | s_n[2**(j+1)-1 + i*2+1]; 
        
                //  If the left child is valid set the parent to that child's data, otherwise set the parent to be the right child.
                //  This moves the first valid data up at each level of the tree.
                //  If neither child is valid the right child is moved up the Data tree but ignored since its Valid signal would be 0. 
                assign d_n[2**j - 1+i] = s_n[2**(j+1)-1 + i*2] ? d_n[2**(j+1)-1 + i*2] : d_n[2**(j+1)-1 + i*2+1]; 
            end
        end     
            
        //  Assigning the output to be the root of the tree.
        assign valid_o = s_n[0];
        assign data_o  = d_n[0];
    
    endgenerate
    


endmodule
