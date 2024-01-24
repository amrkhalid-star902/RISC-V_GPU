`timescale 1ns / 1ps


module RV_lzc #(
    parameter N    = 8,         //  Input Width.
    parameter MODE = 0,         //  0 -> Trailing Zero, 1 -> Leading Zero.
    parameter LOGN = $clog2(N)   //  Log of N.
) (
    input  wire [N-1:0]    in_i,    //  Input to count zeroes in.
    output wire [LOGN-1:0] cnt_o,   //  Number of Leading/Trailing zeroes.
    output wire            valid_o  //  Output count is not be valid if the input is all zeroes.
);




wire [(N * LOGN)-1:0] indices_flattened;    //  Contains indices of in_i in binary: 000, 001, 010, 011, etc..

genvar i;

generate

    //Assign Indices.
    for (i = 0; i < N; i = i + 1) begin

        //  Fill indices with the numbers from 0 -> N
        //  In ascending order (for Trailing Zeroes), or descending order (for Leading Zeroes).
        assign indices_flattened[(i+1) * LOGN - 1:i * LOGN] = MODE ? (N[LOGN-1:0] - 1'b1 - i[LOGN-1:0]) : i[LOGN-1:0];
    end
    
endgenerate

    //  Instantiate Find_First to find the first 1 in the input.
    //  For Leading Zeroes, the input is flipped , then the 1 with lowest index is chosen.
    //      in_i = 00010101     -->     1010(1)000      -->     cnt_o = 3.
    //  That index is the number of zeroes before it.

    //  For Trailing Zeroes, the 1 with lowest index is chosen.
    //      in_i = 00110000     -->     001(1)0000      -->     cnt_o = 4.
    //  That index is the number of zeroes after it.
    RV_find_first #(
        .N       (N),
        .DATAW   (LOGN),
        .REVERSE (MODE)
    ) find_first (        
        .data_i  (indices_flattened),
        .valid_i (in_i),
        .data_o  (cnt_o),
        .valid_o (valid_o)
    );

endmodule