`timescale 1ns / 1ps

/// Modified port of rouding module from fpnew Libray
/// reference: https://github.com/pulp-platform/fpnew

`include "RV_define.vh"


module RV_fp_rounding#(    

    parameter DATA_WIDTH = 32
    
)(
    
    input wire [DATA_WIDTH-1 : 0] abs_value_i,
    input wire                    sign_i,
    
    //Some informations about the rounding operation
    input wire [1 : 0]            round_sticky_bits_i,
    input wire [2 : 0]            rnd_mode_i,
    input wire                    effective_subtraction_i,
    
    output wire [DATA_WIDTH-1 : 0] abs_rounded_o,
    output wire                    sign_o,
    output wire                    exact_zero_o
    
);


    //The decision value for rounding operation
    reg round_up;
    
    //Rounding modes from RISC-V archtitecture
    /* Rounding Mode Mnemonic Meaning */
    /* 000 */ /* RNE */ /* Round to Nearest, ties to Even */
    /* 001 */ /* RTZ */ /* Round towards Zero */
    /* 010 */ /* RDN */ /* Round Down (towards -?) */
    /* 011 */ /* RUP */ /* Round Up (towards +?) */
    /* 100 */ /* RMM */ /* Round to Nearest, ties to Max Magnitude */
    /* 101 */ /* Invalid. Reserved for future use. */
    /* 110 */ /* Invalid. Reserved for future use. */
    /* 111 */ /* In instruction's rm field, selects dynamic rounding mode; */
    /* In Rounding Mode register, Invalid */
    
    always@(*) 
    begin
    
        case(rnd_mode_i)
        
            `INST_FRM_RNE: begin
            
                case(round_sticky_bits_i)
                    
                    2'b00 , 2'b01 : round_up = 1'b0;
                    2'b10 :   round_up = abs_value_i[0];
                    2'b11 :   round_up = 1'b1;
                    default : round_up = 1'bx;
                
                endcase
            
            end//end `INST_FRM_RNE
            
            `INST_FRM_RTZ: round_up = 1'b0; // always round down
            `INST_FRM_RDN: round_up = (| round_sticky_bits_i) & sign_i;  // to 0 if +, away if -
            `INST_FRM_RUP: round_up = (| round_sticky_bits_i) & ~sign_i; // to 0 if -, away if +
            `INST_FRM_RMM: round_up = round_sticky_bits_i[1]; // round down if < ulp/2 away, else up
             default:  round_up = 1'bx; // propagate x
        
        endcase
    
    end
    
    assign abs_rounded_o = abs_value_i + {{(DATA_WIDTH-1){1'b0}} ,round_up};
    // True zero result is a zero result without dirty round/sticky bits
    assign exact_zero_o = (abs_value_i == 0) && (round_sticky_bits_i == 0);
    
    // In case of effective subtraction (thus signs of addition operands must have differed) and a
    // true zero result, the result sign is '-' in case of RDN and '+' for other modes.
    assign sign_o = (exact_zero_o && effective_subtraction_i) ? (rnd_mode_i == `INST_FRM_RDN)
                                                              : sign_i;
    

endmodule
