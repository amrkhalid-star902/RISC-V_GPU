`timescale 1ns / 1ps



module RV_fp_class#(

    parameter MAN_BITS = 23,  //Number of mantissa bits
    parameter EXP_BITS = 8    //Number of exponent bits

)(

    input  wire [EXP_BITS-1 : 0] exp_i,     //Exponent Input
    input  wire [MAN_BITS-1 : 0] man_i,     //mantissa bits
    output wire [6 : 0] clss_o              //Floating-point class bits
    
);

    wire clss_o_is_normal ;          // Wire: Flag for normal number class
    wire clss_o_is_zero;             // Wire: Flag for zero class
    wire clss_o_is_subnormal;        // Wire: Flag for subnormal number class
    wire clss_o_is_inf ;             // Wire: Flag for infinite class
    wire clss_o_is_nan ;             // Wire: Flag for NaN (Not-a-Number) class
    wire clss_o_is_quiet;            // Wire: Flag for quiet NaN class
    wire clss_o_is_signaling;        // Wire: Flag for signaling NaN class
    
    wire is_normal    = (exp_i != {EXP_BITS{1'b0}}) && (exp_i != {EXP_BITS{1'b1}});             // Check if the number is normal, checks if the exponent is neither all zeros nor all ones, which indicates a normal number.
    wire is_zero      = (exp_i == {EXP_BITS{1'b0}}) && (man_i == {MAN_BITS{1'b0}});             // Check if the number is zero, checks if both the exponent and mantissa are equal to zero, indicating a zero value.
    wire is_subnormal = (exp_i == {EXP_BITS{1'b0}}) && (man_i != {MAN_BITS{1'b0}});             // Check if the number is subnormal, checks if the exponent is zero and the mantissa is not zero, which indicates a subnormal number.
    wire is_inf       = (exp_i == {EXP_BITS{1'b1}}) && (man_i == {MAN_BITS{1'b0}});             // Check if the number is infinite,  checks if the exponent is all ones and the mantissa is zero, indicating an infinite value.
    wire is_nan       = (exp_i == {EXP_BITS{1'b1}}) && (man_i != {MAN_BITS{1'b0}});             // Check if the number is NaN (Not-a-Number), checks if the exponent is all ones and the mantissa is not zero, indicating a NaN value.
    wire is_signaling = is_nan && ~man_i[MAN_BITS-1];               // Check if the NaN is signaling, To identify a signaling NaN, the expression first checks whether the input number is classified as NaN (is_nan), and then checks if the most significant bit (man_i[MAN_BITS-1]) of the mantissa is not set.
    wire is_quiet     = is_nan && ~is_signaling;                    // Check if the NaN is quiet, to identify a quiet NaN, the expression first checks whether the input number is classified as NaN (is_nan), and then checks if the negation of the is_signaling flag is true.

    assign clss_o_is_normal    = is_normal;                         // Assign normal flag
    assign clss_o_is_zero      = is_zero;                           // Assign zero flag
    assign clss_o_is_subnormal = is_subnormal;                      // Assign subnormal flag
    assign clss_o_is_inf       = is_inf;                            // Assign infinite flag
    assign clss_o_is_nan       = is_nan;                            // Assign NaN flag
    assign clss_o_is_quiet     = is_quiet;                          // Assign quiet NaN flag
    assign clss_o_is_signaling = is_signaling;                      // Assign signaling NaN flag

    assign clss_o = {clss_o_is_normal,clss_o_is_zero, clss_o_is_subnormal,clss_o_is_inf,clss_o_is_nan,clss_o_is_quiet,clss_o_is_signaling};   // Concatenate all class flags to form the output

endmodule
