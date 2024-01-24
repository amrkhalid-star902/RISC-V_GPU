`timescale 1ns / 1ps


module fp_sqrt(

    input  wire clk,
    input  wire start,
    input  wire reset,
    input  wire [31 : 0] dataIn,
    
    output wire busy,
    output wire valid,
    output wire [31 : 0] result
    
);

    wire [7  : 0] exp_unbiased, exp_final;
    wire [22 : 0] mantissa, root_man;
    wire [27 : 0] rad;
    wire [27 : 0] root;
    
    
    assign exp_unbiased = dataIn[30:23] - 8'd127;
    assign exp_final    = (exp_unbiased >> 1) + 8'd127;
    assign mantissa     = dataIn[22:0];
    assign rad = {4'h1, mantissa, 1'b0};
    
    fixed_sqrt #(
    
        .WIDTH(28),
        .FBITS(24)
    
    )sqrt(
    
        .clk(clk),
        .start(start),
        .reset(reset),
        .rad(rad), 
        .busy(busy),
        .valid(valid),
        .root(root),
        .rem()
    
    );
    
    assign root_man = exp_unbiased[0] ? root[24:2] : root[23:1];
    
    assign result = {1'b0, exp_final, root_man};
    
endmodule
