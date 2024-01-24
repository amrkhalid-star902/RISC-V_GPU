`timescale 1ns / 1ps

`include "RV_define.vh"

module RV_fp_fma#(

    parameter TAGW  = 1,
    parameter LANES = 1

)(

    input wire clk,
    input wire reset,
    
    input  wire valid_in,
    
    input wire [TAGW-1 : 0] tag_in,
    input wire [`INST_FRM_BITS-1:0] frm,
    
    input wire do_madd,                          //Signals module to perform one of FMADD, FMSUB, FNMSUB, or FNMADD.
    input wire do_sub,                           //Signals module to perform subtraction instead of addition.
    input wire do_neg,                           //Signals module to perform negated version of operation.
    
    input  wire ready_out,                        //Core is Ready to receive result.

    
    input  wire [(LANES * 32) - 1:0] dataa,       //  Operand A.
    input  wire [(LANES * 32) - 1:0] datab,       //  Operand B.
    input  wire [(LANES * 32) - 1:0] datac,       //  Operand C.
    output wire [(LANES * 32) - 1:0] result,      //  Result.
    
    output wire has_fflags,                       // Does this module produce any status flags?
    
    //Status Flags
    output wire [LANES-1 : 0] fflags_NV,          //Invalid
    output wire [LANES-1 : 0] fflags_DZ,          //Divide by zero
    output wire [LANES-1 : 0] fflags_OF,          //Overflow
    output wire [LANES-1 : 0] fflags_UF,          //1-Underflow
    output wire [LANES-1 : 0] fflags_NX,          //Inexact
    
    output wire [TAGW-1 : 0] tag_out,             //Output Tag.
    output wire valid_out,                        //Result is valid
    output wire ready_in


);

    //Converting Flattened ports into 2D array
    wire     [31:0]    dataa_packed     [LANES-1:0];
    wire     [31:0]    datab_packed     [LANES-1:0];
    wire     [31:0]    datac_packed     [LANES-1:0];
    wire     [31:0]    result_packed    [LANES-1:0];
    
    //
    //  Repacking flattened ports into 2D arrays.
    //
    genvar i;
    generate
        for (i = 0; i < LANES; i = i + 1) begin  
            assign  dataa_packed[i]   =   dataa[(i+1) * 32 - 1:i * 32];
            assign  datab_packed[i]   =   datab[(i+1) * 32 - 1:i * 32];
            assign  datac_packed[i]   =   datac[(i+1) * 32 - 1:i * 32];
            assign  result[(i+1) * 32 - 1:i * 32]   =   result_packed[i];
        end
    endgenerate
    
    wire stall  = ~ready_out && valid_out;
    wire enable = ~stall;
    
    //perform the operations on each lane
    generate
        
        for(i = 0; i < LANES ; i = i + 1)begin
            
            reg [31:0] a , b , c; //Operands A , B , C.
            
            //  FMADD: Fused multiply-add ((op[0] * op[1]) + op[2]).
            //  FMSUB: Fused multiply-subtract ((op[0] * op[1]) - op[2]).
            //  FNMSUB: Negated fused multiply-subtract (-(op[0] * op[1]) + op[2]).
            //  FNMADD: Negated fused multiply-add (-(op[0] * op[1]) - op[2]).
            //  ADD: Addition (op[1] + op[2]) (note the operand indices).
            //  SUB: Subtraction (op[1] - op[2]) (note the operand indices).
            //  MUL: Multiplication (op[0] * op[1]).
            always@(*)
            begin
            
                // Do one of : MADD/MSUB/NMADD/NMSUB.
                if(do_madd)begin
                
                    //Optain the negative version of A
                    a = do_neg ? {~dataa_packed[i][31] , dataa_packed[i][30:0]} : dataa_packed[i];
                    
                    //B is always posistive
                    b = datab_packed[i];
                    
                    //Operand C is negative in Fused multiply-subtract or Negated fused multiply-add, but not Negated fused multiply-subtract.
                    c = (do_neg ^ do_sub) ? {~datac_packed[i][31], datac_packed[i][30:0]} : datac_packed[i];
                
                end
                //Now one of the following operations will be done : ADD/SUB/MUL
                else begin
                
                    //  do_neg determines MUL operation if do_madd is false.
                    if(do_neg)begin
                    
                        a = dataa_packed[i];
                        b = datab_packed[i];
                        c = 0;
                    
                    end
                    else begin
                    
                        // ADD or SUB(B +/ -C)
                        a = 32'h3f800000; // 1.0f
                        b = dataa_packed[i];
                        c = do_sub ? {~datab_packed[i][31], datab_packed[i][30:0]} : datab_packed[i];
                    
                    end
                    
                end
            
            end
            
            FusedMulAdd fpma(
                
                .clk(clk),
                .reset(reset),
                .en(enable),
                .a(a),
                .b(b),
                .c(c),
                .q(result_packed[i])
                
            );
        
        end
    
    endgenerate
    
    `UNUSED_VAR (frm)
    
   RV_shift_register #(
        .DATAW  (1 + TAGW),
        .DEPTH  (3),
        .RESETW(1 + TAGW)
    ) shift_reg (
        .clk(clk),
        .reset    (reset),
        .enable   (enable),
        .data_in  ({valid_in,  tag_in}),
        .data_out ({valid_out, tag_out})
    );
    
    //  FMA is ready as long as it is enabled (not stalled).
    assign ready_in = enable;
    
    //
    //  FMA does not output status flags, so they are all 0.
    //
    assign has_fflags = 0;

    assign fflags_NV = 0;
    assign fflags_DZ = 0;
    assign fflags_OF = 0;
    assign fflags_UF = 0;
    assign fflags_NX = 0;

endmodule
