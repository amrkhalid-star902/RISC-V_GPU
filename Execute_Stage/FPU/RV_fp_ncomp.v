`timescale 1ns / 1ps

`include "RV_define.vh"


module RV_fp_ncomp#(
    
    parameter TAGW  = 1,
    parameter LANES = 1

)(
    
    input wire clk,
    input wire reset,
    input wire valid_in,
    input wire [TAGW-1 : 0] tag_in,
    input wire [`INST_FPU_BITS-1 : 0] op_type,
    input wire [`INST_FRM_BITS-1 : 0] frm,
    input wire [(LANES*32)-1 : 0] dataa,
    input wire [(LANES*32)-1 : 0] datab,
    input wire ready_out,
    
    output wire ready_in,
    output wire [(LANES*32)-1 : 0] result,
    output wire has_fflags,
    output wire [LANES-1 : 0] fflags_NV,
    output wire [LANES-1 : 0] fflags_DZ,
    output wire [LANES-1 : 0] fflags_OF,
    output wire [LANES-1 : 0] fflags_UF,
    output wire [LANES-1 : 0] fflags_NX,
    output wire [TAGW-1 : 0]  tag_out,
    output wire valid_out
    
);

    localparam  EXP_BITS = 8;
    localparam  MAN_BITS = 23;

    //Converting flat data to 2d ones
    wire [31:0] dataa_2D[LANES-1:0];
    wire [31:0] datab_2D[LANES-1:0];
    
    localparam  NEG_INF     = 32'h00000001,
                NEG_NORM    = 32'h00000002,
                NEG_SUBNORM = 32'h00000004,
                NEG_ZERO    = 32'h00000008,
                POS_ZERO    = 32'h00000010,
                POS_SUBNORM = 32'h00000020,
                POS_NORM    = 32'h00000040,
                POS_INF     = 32'h00000080,
                QUT_NAN     = 32'h00000200;
                
                
    wire [(8*LANES)-1:0] a_exponent_flattened;             // Wire for flattened signal a_exponent_flattened
    wire [(23*LANES)-1:0] a_mantissa_flattened;            // Wire for flattened signal a_mantissa_flattened
    
    wire [LANES-1:0] a_sign, b_sign;                       // Wires for sign signals a_sign and b_sign
    wire [7:0] a_exponent[LANES-1:0];                      // Wires for exponent signals a_exponent
    wire [7:0] b_exponent[LANES-1:0];                      // Wires for exponent signals b_exponent
    wire [22:0] a_mantissa[LANES-1:0];                     // Wires for mantissa signals a_mantissa
    wire [22:0] b_mantissa[LANES-1:0];                     // Wires for mantissa signals b_mantissa
                
    wire [7-1:0] a_clss[LANES-1:0];           // Wires for class signals a_clss
    wire [(7*LANES)-1:0] a_clss_flattened;    // Wire for flattened signal a_clss_flattened
    wire [LANES-1:0] a_clss_is_zero;                       // Wires for zero class indicator signals a_clss_is_zero
    
    wire [LANES-1:0] a_clss_is_normal;                     // Wires for normal class indicator signals a_clss_is_normal
    wire [LANES-1:0] a_clss_is_subnormal;                  // Wires for subnormal class indicator signals a_clss_is_subnormal
    wire [LANES-1:0] a_clss_is_inf;                        // Wires for infinity class indicator signals a_clss_is_inf
    wire [LANES-1:0] a_clss_is_nan;                        // Wires for NaN class indicator signals a_clss_is_nan
    wire [LANES-1:0] a_clss_is_quiet;                      // Wires for quiet NaN class indicator signals a_clss_is_quiet
    wire [LANES-1:0] a_clss_is_signaling;                  // Wires for signaling NaN class indicator signals a_clss_is_signaling
    
    wire [7-1:0] b_clss[LANES-1:0];           // Wires for class signals b_clss
    wire [(7*LANES)-1:0] b_clss_flattened;    // Wire for flattened signal b_clss_flattened
    wire [LANES-1:0] b_clss_is_zero;                       // Wires for zero class indicator signals b_clss_is_zero

    wire [LANES-1:0] b_clss_is_normal;                     // Wires for normal class indicator signals b_clss_is_normal
    wire [LANES-1:0] b_clss_is_subnormal;                  // Wires for subnormal class indicator signals b_clss_is_subnormal
    wire [LANES-1:0] b_clss_is_inf;                        // Wires for infinity class indicator signals b_clss_is_inf
    wire [LANES-1:0] b_clss_is_nan;                        // Wires for NaN class indicator signals b_clss_is_nan
    wire [LANES-1:0] b_clss_is_quiet;                      // Wires for quiet NaN class indicator signals b_clss_is_quiet
    wire [LANES-1:0] b_clss_is_signaling;                  // Wires for signaling NaN class indicator signals b_clss_is_signaling
    wire [LANES-1:0] a_smaller, ab_equal;                  // Wires for comparison signals a_smaller and ab_equal
    
    wire [(32*LANES)-1:0] tmp_result_flattened;  // Flattened version of temporary result
    reg [31:0] tmp_result [LANES-1:0];           // Temporary result for each lane
    reg [LANES-1:0] tmp_fflags_NV;               // 4-Invalid flags for each lane
    reg [LANES-1:0] tmp_fflags_DZ;               // 3-Divide by zero flags for each lane
    reg [LANES-1:0] tmp_fflags_OF;               // 2-Overflow flags for each lane
    reg [LANES-1:0] tmp_fflags_UF;               // 1-Underflow flags for each lane
    reg [LANES-1:0] tmp_fflags_NX;               // 0-Inexact flags for each lane
    
    // First Pipeline stage
    wire [(32*LANES)-1:0] dataa_s0_flattened;                  // Flattened signal for dataa_s0
    wire [(32*LANES)-1:0] datab_s0_flattened;                  // Flattened signal for datab_s0
    wire [(8*LANES)-1:0] a_exponent_s0_flattened;              // Flattened signal for a_exponent_s0
    wire [(23*LANES)-1:0] a_mantissa_s0_flattened;             // Flattened signal for a_mantissa_s0
    
    wire valid_in_s0;                                         // Valid signal in stage0
    wire [TAGW-1:0] tag_in_s0;                                // Tag signal in stage0
    wire [`INST_FPU_BITS-1:0] op_type_s0;                     // Operation type signal in stage0
    wire [`INST_FRM_BITS-1:0] frm_s0;                         // Floating-point rounding mode signal in stage0
    wire [31:0] dataa_s0[LANES-1:0];                          // Dataa signal in stage0
    
    wire [31:0] datab_s0[LANES-1:0];                           // Datab signal in stage0
    
    wire [LANES-1:0] a_sign_s0, b_sign_s0;                     // Sign signals in stage0
    wire [7:0]  a_exponent_s0[LANES-1:0];                      // Exponent signals in stage0
    wire [22:0] a_mantissa_s0[LANES-1:0];                      // Mantissa signals in stage0
    
    wire [7*LANES-1:0] a_clss_s0_flattened;       // Flattened signal for a_clss_s0
    wire [7*LANES-1:0] b_clss_s0_flattened;       // Flattened signal for b_clss_s0
    
    wire [LANES-1:0] a_clss_s0_is_normal;                      // Individual class bits signals for a_clss_s0
    wire [LANES-1:0] a_clss_s0_is_zero;                        // Individual class bits signals for a_clss_s0
    wire [LANES-1:0] a_clss_s0_is_subnormal;                   // Individual class bits signals for a_clss_s0
    wire [LANES-1:0] a_clss_s0_is_inf;                         // Individual class bits signals for a_clss_s0
    wire [LANES-1:0] a_clss_s0_is_nan;                         // Individual class bits signals for a_clss_s0
    wire [LANES-1:0] a_clss_s0_is_quiet;                       // Individual class bits signals for a_clss_s0
    wire [LANES-1:0] a_clss_s0_is_signaling;                   // Individual class bits signals for a_clss_s0
    
    wire [LANES-1:0] b_clss_s0_is_normal;                      // Individual class bits signals for b_clss_s0
    wire [LANES-1:0] b_clss_s0_is_zero;                        // Individual class bits signals for b_clss_s0
    wire [LANES-1:0] b_clss_s0_is_subnormal;                   // Individual class bits signals for b_clss_s0
    wire [LANES-1:0] b_clss_s0_is_inf;                         // Individual class bits signals for b_clss_s0
    wire [LANES-1:0] b_clss_s0_is_quiet;                       // Individual class bits signals for b_clss_s0
    
    wire [LANES-1:0] b_clss_s0_is_nan;                         // Individual class bits signals for b_clss_s0
    wire [LANES-1:0] b_clss_s0_is_signaling;                   // Individual class bits signals for b_clss_s0
    wire [LANES-1:0] a_smaller_s0, ab_equal_s0;                // Comparison signals in stage0
    
    

    
    
    genvar i ;
    generate
    for ( i = 0; i <LANES; i = i + 1) begin
        assign dataa_2D[i] = dataa[((i+1) * 32) - 1:i * 32];                          // Converting flattened input signals to 2D arrays for dataa
        assign datab_2D[i] = datab[((i+1) * 32) - 1:i * 32];                          // Converting flattened input signals to 2D arrays for datab
        assign dataa_s0[i] = dataa_s0_flattened[((i+1) * 32) - 1:i * 32];             // Converting flattened input signals to 2D arrays for dataa_s0
        assign datab_s0[i] = datab_s0_flattened[((i+1) * 32) - 1:i * 32];             // Converting flattened input signals to 2D arrays for datab_s0
        assign a_exponent_s0[i] = a_exponent_s0_flattened[((i+1) * 8) - 1:i * 8];     // Converting flattened input signals to 2D arrays for a_exponent_s0
        assign a_mantissa_s0[i] = a_mantissa_s0_flattened[((i+1) * 23) - 1:i * 23];   // Converting flattened input signals to 2D arrays for a_mantissa_s0

        assign a_exponent_flattened[((i+1) * 8)-1:i * 8] = a_exponent[i];                   // Assigning a_exponent to flattened signal a_exponent_flattened
        assign a_mantissa_flattened[((i+1) * 23)-1:i * 23] = a_mantissa[i];                 // Assigning a_mantissa to flattened signal a_mantissa_flattened
        assign tmp_result_flattened[((i+1) * 32)-1:i * 32] = tmp_result[i];                 // Assigning tmp_result to flattened signal tmp_result_flattened
        assign a_clss_flattened[((i+1) * 7)-1:i * 7] = a_clss[i]; // Assigning a_clss to flattened signal a_clss_flattened
        assign b_clss_flattened[((i+1) * 7)-1:i * 7] = b_clss[i]; // Assigning b_clss to flattened signal b_clss_flattened
    end
    endgenerate
    
    generate
        for (i = 0; i < LANES; i = i + 1) begin
            assign {a_clss_is_normal[i], a_clss_is_zero[i], a_clss_is_subnormal[i], a_clss_is_inf[i], a_clss_is_nan[i],a_clss_is_quiet[i],a_clss_is_signaling[i]} = a_clss_flattened[((i+1) * 7) - 1: i * 7]; // Extracting individual class bits from flattened signal a_clss_flattened
            assign {b_clss_is_normal[i], b_clss_is_zero[i], b_clss_is_subnormal[i], b_clss_is_inf[i], b_clss_is_nan[i],b_clss_is_quiet[i],b_clss_is_signaling[i]} = b_clss_flattened[((i+1) * 7) - 1: i * 7]; // Extracting individual class bits from flattened signal b_clss_flattened
        end
    endgenerate
    
    
    generate
        // Setup
       for (i = 0; i < LANES; i = i + 1) begin
            assign a_sign[i] = dataa_2D[i][31];                                // Extract sign bit from 2D array dataa_2D
            assign a_exponent[i] = dataa_2D[i][30:23];                         // Extract exponent bits from 2D array dataa_2D
            assign a_mantissa[i] = dataa_2D[i][22:0];                          // Extract mantissa bits from 2D array dataa_2D
    
            assign b_sign[i] = datab_2D[i][31];                                // Extract sign bit from 2D array datab_2D
            assign b_exponent[i] = datab_2D[i][30:23];                         // Extract exponent bits from 2D array datab_2D
            assign b_mantissa[i] = datab_2D[i][22:0];                          // Extract mantissa bits from 2D array datab_2D

        // Instantiate RV_fp_class module for input a
        RV_fp_class #( 
            .EXP_BITS (EXP_BITS),
            .MAN_BITS (MAN_BITS)
        ) fp_class_a (
            .exp_i  (a_exponent[i]),
            .man_i  (a_mantissa[i]),
            .clss_o(a_clss [i])    

        );
        // Instantiate RV_fp_class module for input b
        RV_fp_class #( 
            .EXP_BITS (EXP_BITS),
            .MAN_BITS (MAN_BITS)
        ) fp_class_b (
            .exp_i  (b_exponent[i]),
            .man_i  (b_mantissa[i]),
            .clss_o(b_clss[i])    

        );

        assign a_smaller[i] = $signed(dataa_2D[i]) < $signed(datab_2D[i]); // Compare dataa_2D and datab_2D for smaller-than condition
        assign ab_equal[i]  = (dataa_2D[i] == datab_2D[i]) | (a_clss_is_zero[i] & b_clss_is_zero[i]); // Check for equality or both inputs being zero
        
       end
       
    endgenerate
    
    generate
        for (i = 0; i < LANES; i = i + 1) begin
            assign {a_clss_s0_is_normal[i], a_clss_s0_is_zero[i], a_clss_s0_is_subnormal[i], a_clss_s0_is_inf[i], a_clss_s0_is_nan[i], a_clss_s0_is_quiet[i], a_clss_s0_is_signaling[i]} = a_clss_s0_flattened[((i+1) * 7) - 1: i * 7]; // Extracting individual class bits from flattened signal a_clss_s0_flattened
            assign {b_clss_s0_is_normal[i], b_clss_s0_is_zero[i], b_clss_s0_is_subnormal[i], b_clss_s0_is_inf[i], b_clss_s0_is_nan[i], b_clss_s0_is_quiet[i], b_clss_s0_is_signaling[i]} = b_clss_s0_flattened[((i+1) * 7) - 1: i * 7]; // Extracting individual class bits from flattened signal b_clss_s0_flattened
        end
    endgenerate

    wire stall;                                     //is used to control the pipeline stages within the module
    
    
    RV_pipe_register #(
        .DATAW  (1 + TAGW + `INST_FPU_BITS + `INST_FRM_BITS + LANES * (2 * 32 + 1 + 1 + 8 + 23 + 2 * 7 + 1 + 1)),
        .RESETW (1),
        .DEPTH  (0)
    ) pipe_reg0 (
        .clk      (clk),                                      // Clock input
        .reset    (reset),                                    // Reset input
        .enable   (!stall),                                   // Enable input (negation of `stall`)
        .data_in  ({valid_in, tag_in, op_type, frm, dataa, datab, a_sign, b_sign, a_exponent_flattened, a_mantissa_flattened, a_clss_flattened, b_clss_flattened, a_smaller, ab_equal}),   // Input data connections
        .data_out ({valid_in_s0, tag_in_s0, op_type_s0, frm_s0, dataa_s0_flattened, datab_s0_flattened, a_sign_s0, b_sign_s0, a_exponent_s0_flattened, a_mantissa_s0_flattened, a_clss_s0_flattened, b_clss_s0_flattened, a_smaller_s0, ab_equal_s0})    // Output data connections
    );
    
        reg [31:0] fclass_mask  [LANES-1:0];  // generate a 10-bit mask for integer reg

        generate
        // FCLASS
        for ( i = 0; i < LANES; i = i + 1) begin
        
            always @(*) begin 
                // Check if a_clss_s0 is normal
                if (a_clss_s0_is_normal[i]) begin
                    fclass_mask[i] = a_sign_s0[i] ? NEG_NORM : POS_NORM; // Assign negative or positive normal value
                end 
                // Check if a_clss_s0 is infinite
                else if (a_clss_s0_is_inf[i]) begin
                    fclass_mask[i] = a_sign_s0[i] ? NEG_INF : POS_INF; // Assign negative or positive infinity value
                end 
                // Check if a_clss_s0 is zero
                else if (a_clss_s0_is_zero[i]) begin
                    fclass_mask[i] = a_sign_s0[i] ? NEG_ZERO : POS_ZERO; // Assign negative or positive zero value
                end 
                // Check if a_clss_s0 is subnormal
                else if (a_clss_s0_is_subnormal[i]) begin
                    fclass_mask[i] = a_sign_s0[i] ? NEG_SUBNORM : POS_SUBNORM; // Assign negative or positive subnormal value
                end 
                // Check if a_clss_s0 is NaN
                else if (a_clss_s0_is_nan[i]) begin
                    fclass_mask[i] = {22'h0, a_clss_s0_is_quiet[i], a_clss_s0_is_signaling[i], 8'h0}; // Assign NaN value based on quiet/signaling flags
                end 
                // Default case
                else begin                     
                    fclass_mask[i] = QUT_NAN; // Assign quiet NaN value
                end
                
            end
            
        end
        
    endgenerate
    
    reg [31:0] fminmax_res [LANES-1:0];  // result of fmin/fmax
    
    generate
        for (i = 0; i < LANES; i = i + 1) begin : GEN_BLOCK
            always @(*) begin
                // Check if both a_clss_s0 and b_clss_s0 are NaN
                if (a_clss_s0_is_nan[i] && b_clss_s0_is_nan[i])
                    fminmax_res[i] = {1'b0, 8'hff, 1'b1, 22'd0}; // Assign canonical qNaN
                    // Check if only a_clss_s0 is NaN
                 else if (a_clss_s0_is_nan[i]) 
                    fminmax_res[i] = datab_s0[i]; // Assign value of datab_s0
                 // Check if only b_clss_s0 is NaN
                 else if (b_clss_s0_is_nan[i]) 
                    fminmax_res[i] = dataa_s0[i]; // Assign value of dataa_s0
                 else begin 
                    // Use frm_s0 LSB to distinguish MIN and MAX
                    case (frm_s0)
                        3: fminmax_res[i] = a_smaller_s0[i] ? dataa_s0[i] : datab_s0[i]; // Assign smaller value between dataa_s0 and datab_s0
                        4: fminmax_res[i] = a_smaller_s0[i] ? datab_s0[i] : dataa_s0[i]; // Assign larger value between dataa_s0 and datab_s0
                        //default: fminmax_res[i] = 'x;  // don't care value
                        default: fminmax_res[i] = 0;  // don't care value
                    endcase
                 end
            end
        end
    endgenerate
    
    reg [31:0] fsgnj_res [LANES-1:0];    // result of sign injection
     generate
        // Sign injection    
        for (i = 0; i < LANES; i = i + 1) begin : GEN_BLOCK1
            always @(*) begin
                // Perform sign injection based on frm_s0
                case (frm_s0)
                    0: fsgnj_res[i] = { b_sign_s0[i], a_exponent_s0[i], a_mantissa_s0[i]}; // Copy the sign of b and the exponent/mantissa of a
                    1: fsgnj_res[i] = {~b_sign_s0[i], a_exponent_s0[i], a_mantissa_s0[i]}; // Invert the sign of b and keep the exponent/mantissa of a
                    2: fsgnj_res[i] = { a_sign_s0[i] ^ b_sign_s0[i], a_exponent_s0[i], a_mantissa_s0[i]}; // XOR the signs of a and b, and keep the exponent/mantissa of a
                    //default: fsgnj_res[i] = 'x;  // don't care value
                    default: fsgnj_res[i] = 0;  // don't care value
                endcase
            end
        end
    endgenerate
    
    // Comparison    
    reg [31:0] fcmp_res  [LANES-1:0];     // result of comparison
    reg [LANES-1:0] fcmp_fflags_NV;     // 4-Invalid
    reg [LANES-1:0] fcmp_fflags_DZ;     // 3-Divide by zero
    reg [LANES-1:0] fcmp_fflags_OF;     // 2-Overflow
    reg [LANES-1:0] fcmp_fflags_UF;     // 1-Underflow
    reg [LANES-1:0] fcmp_fflags_NX;     // 0-Inexact
    
    
    generate
    for ( i = 0; i < LANES; i = i + 1) begin
        always @(*) begin
            case (frm_s0)
                `INST_FRM_RNE: begin // LE- Round to Nearest Ties to Even
                        // Set flags
                        fcmp_fflags_NV[i] = 1'b0;    // No invalid operation
                        fcmp_fflags_DZ[i] = 1'b0;    // No divide by zero
                        fcmp_fflags_OF[i] = 1'b0;    // No overflow
                        fcmp_fflags_UF[i] = 1'b0;    // No underflow
                        fcmp_fflags_NX[i] = 1'b0;    // No inexact operation
                        if (a_clss_s0_is_nan[i] || b_clss_s0_is_nan[i]) begin
                            // NaN comparison
                            fcmp_res[i] = 32'h0;         // Comparison result is zero
                            fcmp_fflags_NV[i] = 1'b1;    // Set invalid operation flag
                    end else begin
                        // Non-NaN comparison
                        fcmp_res[i] = {31'h0, (a_smaller_s0[i] | ab_equal_s0[i])};  // Set result based on comparison
                    end
                end
                `INST_FRM_RTZ: begin // LS - Round towards Zero
                        // Set flags
                        fcmp_fflags_NV[i] = 1'b0;    // No invalid operation
                        fcmp_fflags_DZ[i] = 1'b0;    // No divide by zero
                        fcmp_fflags_OF[i] = 1'b0;    // No overflow
                        fcmp_fflags_UF[i] = 1'b0;    // No underflow
                        fcmp_fflags_NX[i] = 1'b0;    // No inexact operation

                        if (a_clss_s0_is_nan[i] || b_clss_s0_is_nan[i]) begin
                            // NaN comparison
                            fcmp_res[i] = 32'h0;         // Comparison result is zero
                            fcmp_fflags_NV[i] = 1'b1;    // Set invalid operation flag
                    end else begin
                         // Non-NaN comparison
                        fcmp_res[i] = {31'h0, (a_smaller_s0[i] & ~ab_equal_s0[i])};  // Set result based on comparison
                    end                    
                end
                `INST_FRM_RDN: begin // EQ - Round down (towards negative infinity)
                         // Set flags
                        fcmp_fflags_NV[i] = 1'b0;    // No invalid operation
                        fcmp_fflags_DZ[i] = 1'b0;    // No divide by zero
                        fcmp_fflags_OF[i] = 1'b0;    // No overflow
                        fcmp_fflags_UF[i] = 1'b0;    // No underflow
                        fcmp_fflags_NX[i] = 1'b0;    // No inexact operation
                        if (a_clss_s0_is_nan[i] || b_clss_s0_is_nan[i]) begin
                            // NaN comparison
                            fcmp_res[i] = 32'h0;         // Comparison result is zero
                            fcmp_fflags_NV[i] = a_clss_s0_is_signaling[i] | b_clss_s0_is_signaling[i];  // Set invalid operation flag based on signaling NaNs
                        end else begin
                            // Non-NaN comparison
                            fcmp_res[i] = {31'h0, ab_equal_s0[i]};  // Set result based on comparison
                        end
                end
                default: begin

                   // Default case - no specific rounding mode
                    fcmp_res[i] = 0;            // Comparison result is zero
                    fcmp_fflags_NV[i] = 0;      // No invalid operation
                    fcmp_fflags_DZ[i] = 0;      // No divide by zero
                    fcmp_fflags_OF[i] = 0;      // No overflow
                    fcmp_fflags_UF[i] = 0;      // No underflow
                    fcmp_fflags_NX[i] = 0;      // No inexact operation                     
                end
            endcase
        end
    end
    endgenerate
    
    generate
    
            for (i = 0; i < LANES; i = i + 1) begin
            always @(*) begin
                case (op_type_s0)
                    `INST_FPU_CLASS: begin            //when op_type_s0 is equal to INST_FPU_CLASS
                        tmp_result[i] = fclass_mask[i];                   // Assign fclass_mask to tmp_result
                        tmp_fflags_NV [i] = 0;                            // Reset fflags_NV to 0
                        tmp_fflags_DZ [i] = 0;                            // Reset fflags_DZ to 0
                        tmp_fflags_OF [i] = 0;                            // Reset fflags_OF to 0
                        tmp_fflags_UF [i] = 0;                            // Reset fflags_UF to 0
                        tmp_fflags_NX [i] = 0;                            // Reset fflags_NX to 0
                    end   
                    `INST_FPU_CMP: begin              //when op_type_s0 is equal to INST_FPU_CMP
                        tmp_result[i] = fcmp_res[i];                       // Assign fcmp_res to tmp_result
                        tmp_fflags_NV [i] = fcmp_fflags_NV [i];            // Assign fcmp_fflags_NV to tmp_fflags_NV
                        tmp_fflags_DZ [i] = fcmp_fflags_DZ [i];            // Assign fcmp_fflags_DZ to tmp_fflags_DZ
                        tmp_fflags_OF [i] = fcmp_fflags_OF [i];            // Assign fcmp_fflags_OF to tmp_fflags_OF
                        tmp_fflags_UF [i] = fcmp_fflags_UF [i];            // Assign fcmp_fflags_UF to tmp_fflags_UF
                        tmp_fflags_NX [i] = fcmp_fflags_NX [i];            // Assign fcmp_fflags_NX to tmp_fflags_NX
                    end      
                    //`FPU_MISC:
                    default: begin
                        case (frm_s0)
                            0,1,2: begin
                                tmp_result[i] = fsgnj_res[i];               // Assign fsgnj_res to tmp_result
                                tmp_fflags_NV [i] = 0;                      // Reset fflags_NV to 0
                                tmp_fflags_DZ [i] = 0;                      // Reset fflags_DZ to 0
                                tmp_fflags_OF [i] = 0;                      // Reset fflags_OF to 0
                                tmp_fflags_UF [i] = 0;                      // Reset fflags_UF to 0
                                tmp_fflags_NX [i] = 0;                      // Reset fflags_NX to 0
            
                            end
                            3,4: begin
                                tmp_result[i] = fminmax_res[i];             // Assign fminmax_res to tmp_result
                                tmp_fflags_NV [i] = 0;                      // Reset fflags_NV to 0
                                tmp_fflags_DZ [i] = 0;                      // Reset fflags_DZ to 0
                                tmp_fflags_OF [i] = 0;                      // Reset fflags_OF to 0
                                tmp_fflags_UF [i] = 0;                      // Reset fflags_UF to 0
                                tmp_fflags_NX [i] = 0;                      // Reset fflags_NX to 0
                                tmp_fflags_NV [i] = a_clss_s0_is_signaling [i]| b_clss_s0_is_signaling [i];  // Assign fflags_NV based on signaling NaN
                            end
                            //5,6,7: MOVE
                            default: begin
                                tmp_result[i] = dataa_s0[i];                // Assign dataa_s0 to tmp_result
                                tmp_fflags_NV [i] = 0;                      // Reset fflags_NV to 0
                                tmp_fflags_DZ [i] = 0;                      // Reset fflags_DZ to 0
                                tmp_fflags_OF [i] = 0;                      // Reset fflags_OF to 0
                                tmp_fflags_UF [i] = 0;                      // Reset fflags_UF to 0
                                tmp_fflags_NX [i] = 0;                      // Reset fflags_NX to 0
                            end
                        endcase
                    end    
                endcase
            end
        end
    endgenerate
    
    // Determine whether the current operation requires fflags (flags) handling
    //If any of the  conditions evaluate to true, has_fflags_s0 will be assigned 
    //a value of 1 (indicating that fflags handling is required) and 0 otherwise.
    wire has_fflags_s0 = ((op_type_s0 == `INST_FPU_MISC) 
                          && (frm_s0 == 3                   // MIN
                          || frm_s0 == 4))                  // MAX 
                          || (op_type_s0 == `INST_FPU_CMP); // CMP
                          
    // The stall signal is assigned the value of ~ready_out && valid_out. It
    // is typically used to stall the pipeline when the output is not ready to accept new data.
    assign stall = ~ready_out && valid_out;
                      
    wire [(LANES*5)-1:0] fflags;
                      
   RV_pipe_register #(
      .DATAW  (1 + TAGW + (LANES * 32) + 1 + (LANES * 5))
    ) pipe_reg1 (
         .clk      (clk),
         .reset    (reset),
         .enable   (!stall),
         .data_in  ({valid_in_s0, tag_in_s0, tmp_result_flattened, has_fflags_s0,{tmp_fflags_NV,tmp_fflags_DZ,tmp_fflags_OF,tmp_fflags_UF,tmp_fflags_NX}}),
         .data_out ({valid_out,   tag_out,   result,     has_fflags,    fflags})
   );
   
    generate
       genvar j;
       for (j = 0; j < LANES; j = j + 1) begin
           assign {fflags_NV[j], fflags_DZ[j], fflags_OF[j], fflags_UF[j], fflags_NX[j]} = fflags[((j+1) * 5) - 1: j * 5];
       end
   endgenerate

   assign ready_in = ~stall;//indicate to the previous stage of the pipeline that the current stage is ready to accept new data.
    
    
endmodule
