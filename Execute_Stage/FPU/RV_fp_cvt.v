`timescale 1ns / 1ps

`include "RV_define.vh"

/// Modified port of cast module from fpnew Libray 
/// reference: https://github.com/pulp-platform/fpnew

module RV_fp_cvt#(

    parameter TAGW  = 1,
    parameter LANES = 1

)(
    
    input wire clk,
    input wire reset, 
    input wire  valid_in,
    input wire [TAGW-1:0] tag_in,
    input wire [`INST_FRM_BITS-1:0] frm,
    input wire is_itof,
    input wire is_signed,
    input wire [(LANES*32)-1:0]  dataa,
    input wire  ready_out,
    
    output wire ready_in,
    output wire [(LANES*32)-1:0] result,
    output wire has_fflags,
    output wire [LANES-1:0] fflags_NV, // Invalid
    output wire [LANES-1:0] fflags_DZ, // Divide by zero
    output wire [LANES-1:0] fflags_OF, // Overflow
    output wire [LANES-1:0] fflags_UF, // Underflow
    output wire [LANES-1:0] fflags_NX, // Inexact
    output wire [TAGW-1:0] tag_out,
    output wire valid_out
    
);

    localparam MAN_BITS = 23;
    localparam EXP_BITS = 8;
    localparam EXP_BIAS = 2**(EXP_BITS-1)-1;
    
    // Use 32-bit integer
    localparam MAX_INT_WIDTH = 32;
    
    // The internal mantissa includes normal bit or an entire integer
    localparam INT_MAN_WIDTH = (MAN_BITS+1) > MAX_INT_WIDTH ? (MAN_BITS+1) : MAX_INT_WIDTH;
    // The lower 2p+3 bits of the internal FMA result will be needed for leading-zero detection
    localparam LZC_RESULT_WIDTH = $clog2(INT_MAN_WIDTH);
    
    // The internal exponent must be able to represent the smallest denormal input value as signed
    // or the number of bits in an integer
    localparam INT_EXP_WIDTH = ($clog2(MAX_INT_WIDTH) > (EXP_BITS > $clog2(EXP_BIAS + MAN_BITS) ? EXP_BITS : $clog2(EXP_BIAS + MAN_BITS)) ?
                               MAX_INT_WIDTH : (EXP_BITS > $clog2(EXP_BIAS + MAN_BITS) ? EXP_BITS : $clog2(EXP_BIAS + MAN_BITS))) + 1;
                               
    // shift amount for denormalization
    localparam SHAMT_BITS = $clog2(INT_MAN_WIDTH+1);
    
    localparam FMT_SHIFT_COMPENSATION = INT_MAN_WIDTH - 1 - MAN_BITS;
    localparam NUM_FP_STICKY  = 2 * INT_MAN_WIDTH - MAN_BITS - 1;   // removed mantissa, 1. and R
    localparam NUM_INT_STICKY = 2 * INT_MAN_WIDTH - MAX_INT_WIDTH;  // removed int and R
    
    //  Static Casting used to Convert Parameter Widths.
    function automatic signed [INT_MAN_WIDTH - 1:0] INT_MAN_WIDTH_Cast;
        input reg signed [INT_MAN_WIDTH - 1:0] in;   //  Input to Cast.
        INT_MAN_WIDTH_Cast = in;    //  Output the input back as a signal with the correct width.
    endfunction
    
    wire [31:0]  dataa_2D [LANES-1:0];
    
    wire [(7 * LANES)-1:0] fp_clss;
    wire [LANES-1:0] fp_clss_is_normal;
    wire [LANES-1:0] fp_clss_is_zero;
    wire [LANES-1:0] fp_clss_is_subnormal;
    wire [LANES-1:0] fp_clss_is_inf;
    wire [LANES-1:0] fp_clss_is_nan;
    wire [LANES-1:0] fp_clss_is_quiet;
    wire [LANES-1:0] fp_clss_is_signaling; 
    
    genvar i;
    generate
        for (i = 0; i < LANES; i = i + 1) begin
            assign {fp_clss_is_normal[i],
                    fp_clss_is_zero[i],
                    fp_clss_is_subnormal[i],
                    fp_clss_is_inf[i],
                    fp_clss_is_nan[i],
                    fp_clss_is_quiet[i],
                    fp_clss_is_signaling[i]} = fp_clss[((i+1)*7)-1:i*7];
    
            assign dataa_2D[i] = dataa[((i+1)*32)-1:i*32];
        end
    endgenerate
    
    generate
        for (i = 0; i < LANES; i = i + 1) begin
            RV_fp_class #( 
                .EXP_BITS (EXP_BITS),
                .MAN_BITS (MAN_BITS)
            ) fp_class (
                .exp_i  (dataa_2D[i][30:23]),
                .man_i  (dataa_2D[i][22:0]),
                .clss_o (fp_clss[((i+1)*7)-1:i*7])
            );
        end
    endgenerate
    
    wire [(LANES * INT_MAN_WIDTH)-1:0] encoded_mant; // input mantissa with implicit bit    
    wire [(LANES * INT_EXP_WIDTH)-1:0] fmt_exponent;    
    wire [LANES-1:0]                    input_sign;
    
    generate
    
        for (i = 0; i < LANES; i = i + 1) begin
            
            wire [INT_MAN_WIDTH-1:0] int_mantissa;
            wire [INT_MAN_WIDTH-1:0] fmt_mantissa;
            wire fmt_sign       = dataa_2D[i][31];
            wire int_sign       = dataa_2D[i][31] & is_signed;
            assign int_mantissa = int_sign ? (-dataa_2D[i]) : dataa_2D[i];
            assign fmt_mantissa = INT_MAN_WIDTH_Cast({fp_clss_is_normal[i], dataa_2D[i][MAN_BITS-1:0]});
    
            assign fmt_exponent[((i+1)*INT_EXP_WIDTH)-1:i*INT_EXP_WIDTH] =  {1'b0, dataa_2D[i][(MAN_BITS + EXP_BITS) - 1 : MAN_BITS]} +
                                                                            {1'b0, fp_clss_is_subnormal[i]};
    
            assign encoded_mant[((i+1)*INT_MAN_WIDTH)-1:i*INT_MAN_WIDTH] = is_itof ? int_mantissa : fmt_mantissa;
    
            assign input_sign[i]   = is_itof ? int_sign : fmt_sign;    
            
        end
    
    endgenerate
    
    // First pipeline syage 
    
    wire                    valid_in_s0;
    wire [TAGW-1:0]         tag_in_s0;
    wire                    is_itof_s0;
    wire                    unsigned_s0;
    wire [2:0]              rnd_mode_s0;
    wire [(7 * LANES)-1:0]  fp_clss_s0;
    wire [LANES-1:0]        input_sign_s0;
    wire [(LANES * INT_EXP_WIDTH)-1:0] fmt_exponent_s0;
    wire [(LANES * INT_MAN_WIDTH)-1:0] encoded_mant_s0;
    wire stall;
    
    RV_pipe_register #(
        .DATAW  (1 + TAGW + 1 + `INST_FRM_BITS + 1 + LANES * (7 + 1 + INT_EXP_WIDTH + INT_MAN_WIDTH)),
        .RESETW (1)
    ) pipe_reg0 (
        .clk      (clk),
        .reset    (reset),
        .enable   (~stall),
        .data_in  ({valid_in,    tag_in,    is_itof,    !is_signed,  frm,         fp_clss,    input_sign,    fmt_exponent,    encoded_mant}),
        .data_out ({valid_in_s0, tag_in_s0, is_itof_s0, unsigned_s0, rnd_mode_s0, fp_clss_s0, input_sign_s0, fmt_exponent_s0, encoded_mant_s0})
    );
    
    // Normalization

    wire [LZC_RESULT_WIDTH-1:0] renorm_shamt_s0 [LANES-1:0]; // renormalization shift amount
    wire [LANES-1:0] mant_is_zero_s0;                       // for integer zeroes
    
    generate
        for (i = 0; i < LANES; i = i + 1) begin
            wire mant_is_nonzero;
            RV_lzc #(
                .N    (INT_MAN_WIDTH),
                .MODE (1)
            ) lzc (
                .in_i    (encoded_mant_s0[((i+1)*INT_MAN_WIDTH)-1:i*INT_MAN_WIDTH]),
                .cnt_o   (renorm_shamt_s0[i]),
                .valid_o (mant_is_nonzero)
            );
            assign mant_is_zero_s0[i] = ~mant_is_nonzero;  
        end
    endgenerate
    
    wire [(LANES * INT_MAN_WIDTH)-1:0] input_mant_s0;      // normalized input mantissa    
    wire [(LANES * INT_EXP_WIDTH)-1:0] input_exp_s0;       // unbiased true exponent
    
    generate
        for (i = 0; i < LANES; i = i + 1) begin
        
           // Realign input mantissa, append zeroes if destination is wider
            assign input_mant_s0[((i+1)*INT_MAN_WIDTH)-1:i*INT_MAN_WIDTH] = encoded_mant_s0[((i+1)*INT_MAN_WIDTH)-1:i*INT_MAN_WIDTH] << renorm_shamt_s0[i];
    
            // Unbias exponent and compensate for shift
            wire [INT_EXP_WIDTH-1:0] fp_input_exp = fmt_exponent_s0[((i+1)*INT_EXP_WIDTH)-1:i*INT_EXP_WIDTH] + (FMT_SHIFT_COMPENSATION - EXP_BIAS) - {1'b0, renorm_shamt_s0[i]};                                 
            wire [INT_EXP_WIDTH-1:0] int_input_exp = (INT_MAN_WIDTH-1) - {1'b0, renorm_shamt_s0[i]};
    
            assign input_exp_s0[((i+1)*INT_EXP_WIDTH)-1:i*INT_EXP_WIDTH] = is_itof_s0 ? int_input_exp : fp_input_exp;
            
        end
    endgenerate
    
    //Second Pipline Stage

    wire                    valid_in_s1;
    wire [TAGW-1:0]         tag_in_s1;
    wire                    is_itof_s1;
    wire                    unsigned_s1;
    wire [2:0]              rnd_mode_s1;
    wire [(7 * LANES)-1:0]  fp_clss_s1;
    wire [LANES-1:0]        input_sign_s1;
    wire [LANES-1:0]        mant_is_zero_s1;
    wire [(LANES * INT_MAN_WIDTH)-1:0] input_mant_s1;
    wire [(LANES * INT_EXP_WIDTH)-1:0] input_exp_s1;
    
    RV_pipe_register #(
        .DATAW  (1 + TAGW + 1 + `INST_FRM_BITS + 1 + LANES * (7 + 1 + 1 + INT_MAN_WIDTH + INT_EXP_WIDTH)),
        .RESETW (1)
    ) pipe_reg1 (
        .clk      (clk),
        .reset    (reset),
        .enable   (~stall),
        .data_in  ({valid_in_s0, tag_in_s0, is_itof_s0, unsigned_s0, rnd_mode_s0, fp_clss_s0, input_sign_s0, mant_is_zero_s0, input_mant_s0, input_exp_s0}),
        .data_out ({valid_in_s1, tag_in_s1, is_itof_s1, unsigned_s1, rnd_mode_s1, fp_clss_s1, input_sign_s1, mant_is_zero_s1, input_mant_s1, input_exp_s1})
    ); 
    
    
    // Perform adjustments to mantissa and exponent

    wire [(LANES * (2*INT_MAN_WIDTH+1)) - 1:0] destination_mant_s1;
    wire [(LANES * INT_EXP_WIDTH)-1:0] final_exp_s1;
    wire [LANES-1:0]                    of_before_round_s1;
    
    generate
        for (i = 0; i < LANES; i = i + 1) begin
            reg [2*INT_MAN_WIDTH:0] preshift_mant;      // mantissa before final shift                
            reg [SHAMT_BITS-1:0]    denorm_shamt;       // shift amount for denormalization
            reg [INT_EXP_WIDTH-1:0] final_exp;          // after eventual adjustments
            reg                     of_before_round;
    
            always @(*) begin           
                 
                // Default assignment
                final_exp       = input_exp_s1[((i+1)*INT_EXP_WIDTH)-1:i*INT_EXP_WIDTH] + EXP_BIAS; // take exponent as is, only look at lower bits
                preshift_mant   = {input_mant_s1[((i+1)*INT_MAN_WIDTH)-1:i*INT_MAN_WIDTH], 33'b0};  // Place mantissa to the left of the shifter
                denorm_shamt    = 0;      // right of mantissa
                of_before_round = 1'b0;
    
                // Handle INT casts
                if (is_itof_s1) begin                   
                    if ($signed(input_exp_s1[((i+1)*INT_EXP_WIDTH)-1:i*INT_EXP_WIDTH]) >= $signed(2**EXP_BITS-1-EXP_BIAS)) begin
                        // Overflow or infinities (for proper rounding)
                        final_exp     = (2**EXP_BITS-2); // largest normal value
                        preshift_mant = ~0;  // largest normal value and RS bits set
                        of_before_round = 1'b1;
                    end else if ($signed(input_exp_s1[((i+1)*INT_EXP_WIDTH)-1:i*INT_EXP_WIDTH]) < $signed(-MAN_BITS-EXP_BIAS)) begin
                        // Limit the shift to retain sticky bits
                        final_exp     = 0; // denormal result
                        denorm_shamt  = (2 + MAN_BITS); // to sticky                
                    end else if ($signed(input_exp_s1[((i+1)*INT_EXP_WIDTH)-1:i*INT_EXP_WIDTH]) < $signed(1-EXP_BIAS)) begin
                        // Denormalize underflowing values
                        final_exp     = 0; // denormal result
                        denorm_shamt  = (1-EXP_BIAS) - input_exp_s1[((i+1)*INT_EXP_WIDTH)-1:i*INT_EXP_WIDTH]; // adjust right shifting               
                    end
                end else begin                                
                    if ($signed(input_exp_s1[((i+1)*INT_EXP_WIDTH)-1:i*INT_EXP_WIDTH]) >= $signed((MAX_INT_WIDTH-1) + unsigned_s1)) begin
                        // overflow: when converting to unsigned the range is larger by one
                        denorm_shamt = 0; // prevent shifting
                        of_before_round = 1'b1;                
                    end else if ($signed(input_exp_s1[((i+1)*INT_EXP_WIDTH)-1:i*INT_EXP_WIDTH]) < $signed(-1)) begin
                        // underflow
                        denorm_shamt = MAX_INT_WIDTH+1; // all bits go to the sticky
                    end else begin
                        // By default right shift mantissa to be an integer
                        denorm_shamt = (MAX_INT_WIDTH-1) - input_exp_s1[((i+1)*INT_EXP_WIDTH)-1:i*INT_EXP_WIDTH];
                    end              
                end     
              
            end
    
            assign destination_mant_s1[((i+1)*(2*INT_MAN_WIDTH+1))-1:i*(2*INT_MAN_WIDTH+1)] = preshift_mant >> denorm_shamt;
            assign final_exp_s1[((i+1)*INT_EXP_WIDTH)-1:i*INT_EXP_WIDTH]        = final_exp;
            assign of_before_round_s1[i]  = of_before_round;
        end
    endgenerate
    
    
    //Third piline stage
    
    wire                    valid_in_s2;
    wire [TAGW-1:0]         tag_in_s2;
    wire                    is_itof_s2;
    wire                    unsigned_s2;
    wire [2:0]              rnd_mode_s2;
    wire [(7 * LANES)-1:0]  fp_clss_s2;   
    wire [LANES-1:0]        mant_is_zero_s2;
    wire [LANES-1:0]        input_sign_s2;

    wire [2*INT_MAN_WIDTH:0] destination_mant_s2_2D [LANES-1:0];
    wire [(LANES * (2*INT_MAN_WIDTH+1)) - 1:0] destination_mant_s2;

    wire [(LANES * INT_EXP_WIDTH)-1:0] final_exp_s2;
    wire [INT_EXP_WIDTH-1:0] final_exp_s2_2D [LANES-1:0];

    wire [LANES-1:0]        of_before_round_s2;
    
    generate
        for (i = 0; i < LANES; i = i + 1) begin
            assign destination_mant_s2_2D[i] = destination_mant_s2[((i+1)*(2*INT_MAN_WIDTH+1))-1:i*(2*INT_MAN_WIDTH+1)];
            assign final_exp_s2_2D[i] = final_exp_s2[((i+1)*INT_EXP_WIDTH)-1:i*INT_EXP_WIDTH];
        end
    endgenerate
    
    RV_pipe_register #(
        .DATAW  (1 + TAGW + 1 + 1 + `INST_FRM_BITS + LANES * (7 + 1 + 1 + (2*INT_MAN_WIDTH+1) + INT_EXP_WIDTH + 1)),
        .RESETW (1)
    ) pipe_reg2 (
        .clk      (clk),
        .reset    (reset),
        .enable   (~stall),
        .data_in  ({valid_in_s1, tag_in_s1, is_itof_s1, unsigned_s1, rnd_mode_s1, fp_clss_s1, mant_is_zero_s1, input_sign_s1, destination_mant_s1, final_exp_s1, of_before_round_s1}),
        .data_out ({valid_in_s2, tag_in_s2, is_itof_s2, unsigned_s2, rnd_mode_s2, fp_clss_s2, mant_is_zero_s2, input_sign_s2, destination_mant_s2, final_exp_s2, of_before_round_s2})
    );
    
    wire [LANES-1:0]       rounded_sign;
    wire [(LANES * 32) -1:0] rounded_abs;     // absolute value of result after rounding
    wire [1:0]  fp_round_sticky_bits [LANES-1:0];
    wire [1:0]  int_round_sticky_bits [LANES-1:0];
    
    generate
        for (i = 0; i < LANES; i = i + 1) begin
        
            wire [MAN_BITS-1:0]      final_mant;        // mantissa after adjustments
            wire [MAX_INT_WIDTH-1:0] final_int;         // integer shifted in position
            wire [1:0]               round_sticky_bits;
            wire [31:0]              fmt_pre_round_abs;
            wire [31:0]              pre_round_abs;
    
            // Extract final mantissa and round bit, discard the normal bit (for FP)
            assign {final_mant, fp_round_sticky_bits[i][1]} = destination_mant_s2_2D[i][2*INT_MAN_WIDTH-1 : 2*INT_MAN_WIDTH-1 - (MAN_BITS+1) + 1];
            assign {final_int, int_round_sticky_bits[i][1]} = destination_mant_s2_2D[i][2*INT_MAN_WIDTH   : 2*INT_MAN_WIDTH   - (MAX_INT_WIDTH+1) + 1];
    
            // Collapse sticky bits
            assign fp_round_sticky_bits[i][0]  = (| destination_mant_s2_2D[i][NUM_FP_STICKY-1:0]);
            assign int_round_sticky_bits[i][0] = (| destination_mant_s2_2D[i][NUM_INT_STICKY-1:0]);
    
            // select RS bits for destination operation
            assign round_sticky_bits = is_itof_s2 ? fp_round_sticky_bits[i] : int_round_sticky_bits[i];
    
            // Pack exponent and mantissa into proper rounding form
            assign fmt_pre_round_abs = {1'b0, final_exp_s2_2D[i][EXP_BITS-1:0], final_mant[MAN_BITS-1:0]};
    
            // Select output with destination format and operation
            assign pre_round_abs = is_itof_s2 ? fmt_pre_round_abs : final_int;
    
            // Perform the rounding
            RV_fp_rounding #(
                .DATA_WIDTH (32)
            ) fp_rounding (
                .abs_value_i    (pre_round_abs),
                .sign_i         (input_sign_s2[i]),
                .round_sticky_bits_i(round_sticky_bits),
                .rnd_mode_i     (rnd_mode_s2),
                .effective_subtraction_i(1'b0),
                .abs_rounded_o  (rounded_abs[((i+1)*32)-1:i*32]),
                .sign_o         (rounded_sign[i]),
                .exact_zero_o()
            );
            
        end
    endgenerate
    
    //Fourth Stage of pipline
    wire                    valid_in_s3;
    wire [TAGW-1:0]         tag_in_s3;
    wire                    is_itof_s3;
    wire                    unsigned_s3;

    wire [(7 * LANES)-1:0]  fp_clss_s3;   

    wire [LANES-1:0] fp_clss_s3_is_normal;
    wire [LANES-1:0] fp_clss_s3_is_zero;
    wire [LANES-1:0] fp_clss_s3_is_subnormal;
    wire [LANES-1:0] fp_clss_s3_is_inf;
    wire [LANES-1:0] fp_clss_s3_is_nan;
    wire [LANES-1:0] fp_clss_s3_is_quiet;
    wire [LANES-1:0] fp_clss_s3_is_signaling;
    
    wire [LANES-1:0]        mant_is_zero_s3;
    wire [LANES-1:0]        input_sign_s3;
    wire [LANES-1:0]        rounded_sign_s3;

    wire [(LANES * 32) -1:0] rounded_abs_s3;
    wire [31:0]  rounded_abs_s3_2D [LANES-1:0];

    wire [LANES-1:0]        of_before_round_s3;
    
    generate
        for (i = 0; i < LANES; i = i + 1) begin
            assign {fp_clss_s3_is_normal[i],
                    fp_clss_s3_is_zero[i],
                    fp_clss_s3_is_subnormal[i],
                    fp_clss_s3_is_inf[i],
                    fp_clss_s3_is_nan[i],
                    fp_clss_s3_is_quiet[i],
                    fp_clss_s3_is_signaling[i]} = fp_clss_s3[((i+1)*7)-1:i*7];

            assign rounded_abs_s3_2D[i] = rounded_abs_s3[((i+1)*32)-1:i*32];
        end
    endgenerate
    
    RV_pipe_register #(
        .DATAW  (1 + TAGW + 1 + 1 + LANES * (7 + 1 + 1 + 32 + 1 + 1)),
        .RESETW (1)
    ) pipe_reg3 (
        .clk      (clk),
        .reset    (reset),
        .enable   (~stall),
        .data_in  ({valid_in_s2, tag_in_s2, is_itof_s2, unsigned_s2, fp_clss_s2, mant_is_zero_s2, input_sign_s2, rounded_abs,    rounded_sign,    of_before_round_s2}),
        .data_out ({valid_in_s3, tag_in_s3, is_itof_s3, unsigned_s3, fp_clss_s3, mant_is_zero_s3, input_sign_s3, rounded_abs_s3, rounded_sign_s3, of_before_round_s3})
    );
    
    wire [LANES-1:0] of_after_round;
    wire [LANES-1:0] uf_after_round;
    wire [31:0] fmt_result [LANES-1:0];
    wire [31:0] rounded_int_res [LANES-1:0]; // after possible inversion
    wire [LANES-1:0] rounded_int_res_zero;  // after rounding
    
    generate
    
        for (i = 0; i < LANES; i = i + 1) begin
            // Assemble regular result, nan box short ones. Int zeroes need to be detected
            assign fmt_result[i] = (is_itof_s3 & mant_is_zero_s3[i]) ? 0 : {rounded_sign_s3[i], rounded_abs_s3_2D[i][EXP_BITS+MAN_BITS-1:0]};
    
            // Classification after rounding select by destination format
            assign uf_after_round[i] = (rounded_abs_s3_2D[i][EXP_BITS+MAN_BITS-1:MAN_BITS] == 0); // denormal
            assign of_after_round[i] = (rounded_abs_s3_2D[i][EXP_BITS+MAN_BITS-1:MAN_BITS] == ~0); // inf exp.
    
            // Negative integer result needs to be brought into two's complement
            assign rounded_int_res[i] = rounded_sign_s3[i] ? (-rounded_abs_s3_2D[i]) : rounded_abs_s3_2D[i];
            assign rounded_int_res_zero[i] = (rounded_int_res[i] == 0);
        end
        
    endgenerate
    
    // FP Special case handling

    wire [31:0]  fp_special_result [LANES-1:0];

    wire [(LANES * 5)-1:0]    fp_special_status;

    wire [LANES-1:0]        fp_result_is_special;

    wire [EXP_BITS-1:0] QNAN_EXPONENT = 2**EXP_BITS-1;
    wire [MAN_BITS-1:0] QNAN_MANTISSA = 2**(MAN_BITS-1);
    
    generate
        for (i = 0; i < LANES; i = i + 1) begin
            // Detect special case from source format, I2F casts don't produce a special result
            assign fp_result_is_special[i] = ~is_itof_s3 & (fp_clss_s3_is_zero[i] | fp_clss_s3_is_nan[i]);
    
            // Signalling input NaNs raise invalid flag, otherwise no flags set
            assign fp_special_status[((i+1)*5)-1:i*5] = fp_clss_s3_is_signaling[i] ? {1'b1, 4'h0} : 5'h0;   // invalid operation
    
            // Assemble result according to destination format
            assign fp_special_result[i] = fp_clss_s3_is_zero[i] ? ({32{input_sign_s3}} << 31) // signed zero
                                                                        : {1'b0, QNAN_EXPONENT, QNAN_MANTISSA}; // qNaN
        end
    endgenerate
    
    // INT Special case handling

    reg [31:0]   int_special_result [LANES-1:0];
    wire [(LANES * 5)-1:0]    int_special_status;
    wire [LANES-1:0]        int_result_is_special;
    
    generate
        for (i = 0; i < LANES; i = i + 1) begin
             // Assemble result according to destination format
            always @(*) begin
                if (input_sign_s3[i] && !fp_clss_s3_is_nan[i]) begin
                    int_special_result[i][30:0] = 0;               // alone yields 2**(31)-1
                    int_special_result[i][31]   = ~unsigned_s3;    // for unsigned casts yields 2**31
                end else begin
                    int_special_result[i][30:0] = 2**(31) - 1;     // alone yields 2**(31)-1
                    int_special_result[i][31]   = unsigned_s3;     // for unsigned casts yields 2**31
                end
            end            
    
            // Detect special case from source format (inf, nan, overflow, nan-boxing or negative unsigned)
            assign int_result_is_special[i] = fp_clss_s3_is_nan[i] 
                                            | fp_clss_s3_is_inf[i] 
                                            | of_before_round_s3[i] 
                                            | (input_sign_s3[i] & unsigned_s3 & ~rounded_int_res_zero[i]);
                                            
            // All integer special cases are invalid
            assign int_special_status[((i+1)*5)-1:i*5] = {1'b1, 4'h0};
            
        end
    endgenerate
    
    // Result selection and Output handshake

    wire [(LANES * 5)-1:0] tmp_fflags;    
    wire [(LANES * 32) - 1:0] tmp_result;
    
    generate
    
        for (i = 0; i < LANES; i = i + 1) begin
    
            wire fp_regular_status_NV; // 4-Invalid
            wire fp_regular_status_DZ; // 3-Divide by zero
            wire fp_regular_status_OF; // 2-Overflow
            wire fp_regular_status_UF; // 1-Underflow
            wire fp_regular_status_NX; // 0-Inexact
    
            wire [5 - 1:0] int_regular_status;
            wire [5 - 1:0] fp_status;
            wire [5 - 1:0] int_status;    
            wire [31:0] fp_result, int_result;
    
            wire inexact = is_itof_s3 ? (| fp_round_sticky_bits[i]) // overflow is invalid in i2f;        
                                      : (| fp_round_sticky_bits[i]) | (~fp_clss_s3_is_inf[i] & (of_before_round_s3[i] | of_after_round[i]));
                                      
            assign fp_regular_status_NV = is_itof_s3 & (of_before_round_s3[i] | of_after_round[i]); // overflow is invalid for I2F casts
            assign fp_regular_status_DZ = 1'b0; // no divisions
            assign fp_regular_status_OF = ~is_itof_s3 & (~fp_clss_s3_is_inf[i] & (of_before_round_s3[i] | of_after_round[i])); // inf casts no OF
            assign fp_regular_status_UF = uf_after_round[i] & inexact;
            assign fp_regular_status_NX = inexact;
    
            assign int_regular_status = (| int_round_sticky_bits[i]) ? {4'h0, 1'b1} : 5'h0;
    
            assign fp_result  = fp_result_is_special[i]  ? fp_special_result[i]  : fmt_result[i];        
            assign int_result = int_result_is_special[i] ? int_special_result[i] : rounded_int_res[i];
    
            assign fp_status  = fp_result_is_special[i]  ? fp_special_status[((i+1)*5)-1:i*5]  : {fp_regular_status_NV,
                                                                                                                       fp_regular_status_DZ,
                                                                                                                       fp_regular_status_OF,
                                                                                                                       fp_regular_status_UF,
                                                                                                                       fp_regular_status_NX};
            assign int_status = int_result_is_special[i] ? int_special_status[((i+1)*5)-1:i*5] : int_regular_status;
    
            // Select output depending on special case detection
            assign tmp_result[((i+1)*32)-1:i*32] = is_itof_s3 ? fp_result : int_result;
            assign tmp_fflags[((i+1)*5)-1:i*5] = is_itof_s3 ? fp_status : int_status;
        end
        
    endgenerate
    
    assign stall = ~ready_out && valid_out;

    wire [(LANES * 5)-1:0] fflags;

    RV_pipe_register #(
        .DATAW  (1 + TAGW + (LANES * 32) + (LANES * 5)),
        .RESETW (1)
    ) pipe_reg4 (
        .clk      (clk),
        .reset    (reset),
        .enable   (!stall),
        .data_in  ({valid_in_s3, tag_in_s3, tmp_result, tmp_fflags}),
        .data_out ({valid_out,   tag_out,   result,     fflags})
    );
    
    generate
    
        for (i = 0; i < LANES; i = i + 1) begin
            assign {fflags_NV[i],
                    fflags_DZ[i],
                    fflags_OF[i],
                    fflags_UF[i],
                    fflags_NX[i]} = fflags[((i+1)*5)-1:i*5];
        end
        
    endgenerate 
    
    assign ready_in = ~stall;

    assign has_fflags = 1'b1;
    
endmodule
