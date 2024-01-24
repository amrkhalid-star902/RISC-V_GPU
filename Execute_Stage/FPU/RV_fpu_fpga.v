`timescale 1ns / 1ps

`default_nettype none

`include "RV_define.vh"

module RV_fpu_fpga#(

    parameter TAGW = 2

)(

    input  wire clk,
    input  wire reset,
    input  wire valid_in,
    input  wire [TAGW-1 : 0] tag_in,
    input  wire [`INST_FPU_BITS-1:0] op_type,
    input  wire [`INST_MOD_BITS-1:0] frm,
    input  wire [(`NUM_THREADS*32)-1 : 0] dataa,
    input  wire [(`NUM_THREADS*32)-1 : 0] datab,
    input  wire [(`NUM_THREADS*32)-1 : 0] datac,
    input  wire ready_out,
    
    output  wire ready_in,
    output  wire [(`NUM_THREADS*32)-1 : 0] result,
    output  wire has_fflags,
    output  wire [`NUM_THREADS-1 : 0] fflags_NV,
    output  wire [`NUM_THREADS-1 : 0] fflags_DZ,
    output  wire [`NUM_THREADS-1 : 0] fflags_OF,
    output  wire [`NUM_THREADS-1 : 0] fflags_UF,
    output  wire [`NUM_THREADS-1 : 0] fflags_NX,
    output  wire [TAGW-1 : 0] tag_out,
    output  wire valid_out

);

    localparam FPU_FMA  = 0;
    localparam FPU_SQRT = 2;
    localparam FPU_CVT  = 3;
    localparam FPU_NCP  = 4;
    localparam NUM_FPC  = 3;
    localparam FPC_BITS = $clog2(NUM_FPC);
    
    wire fma_ready_in , cvt_ready_in , ncp_ready_in , sqrt_ready_in;
    wire [(`NUM_THREADS*32)-1 : 0] fma_result , cvt_result , ncp_result , sqrt_result;
    wire [TAGW-1 : 0] fma_tag , cvt_tag , ncp_tag , sqrt_tag;
    wire fma_valid_out , cvt_valid_out , ncp_valid_out , sqrt_valid_out;
    reg  fma_ready_out , cvt_ready_out , ncp_ready_out , sqrt_ready_out;
    
    
    wire fma_has_fflags , cvt_has_fflags , ncp_has_fflags , sqrt_has_fflags;
    wire [`NUM_THREADS-1 : 0] fma_fflags_NV  , cvt_fflags_NV  , ncp_fflags_NV , sqrt_fflags_NV;
    wire [`NUM_THREADS-1 : 0] fma_fflags_DZ  , cvt_fflags_DZ  , ncp_fflags_DZ , sqrt_fflags_DZ;
    wire [`NUM_THREADS-1 : 0] fma_fflags_OF  , cvt_fflags_OF  , ncp_fflags_OF , sqrt_fflags_OF;
    wire [`NUM_THREADS-1 : 0] fma_fflags_UF  , cvt_fflags_UF  , ncp_fflags_UF , sqrt_fflags_UF;
    wire [`NUM_THREADS-1 : 0] fma_fflags_NX  , cvt_fflags_NX  , ncp_fflags_NX , sqrt_fflags_NX;
    
    reg [NUM_FPC-1 : 0] core_select;
    reg do_madd, do_sub, do_neg, is_itof, is_signed;
    
    always@(*)
    begin
    
        do_madd   = 0;
        do_sub    = 0;
        do_neg    = 0;
        is_itof   = 0;
        is_signed = 0;
        
        case(op_type)
        
            `INST_FPU_ADD : begin
                
                core_select = FPU_FMA;
                
            end
            
            `INST_FPU_SUB : begin
                
                core_select = FPU_FMA;
                do_sub      = 1;
                
            end
            
            `INST_FPU_MUL : begin
                
                core_select = FPU_FMA;
                do_neg      = 1;
                
            end
            
            `INST_FPU_MADD : begin
                
                core_select = FPU_FMA;
                do_madd     = 1;
                
            end
            
            `INST_FPU_MSUB : begin
                
                core_select = FPU_FMA;
                do_madd     = 1;
                do_sub      = 1;
                
            end
            
            `INST_FPU_NMADD : begin
                
                core_select = FPU_FMA;
                do_madd     = 1;
                do_neg      = 1;
                
            end
            
            `INST_FPU_NMSUB : begin
                
                core_select = FPU_FMA;
                do_madd     = 1;
                do_sub      = 1;
                do_neg      = 1;
                
            end
            
            `INST_FPU_CVTWS : begin
            
                core_select = FPU_CVT;
                is_signed   = 1;
            
            end
            
            `INST_FPU_CVTWUS : begin
            
                core_select = FPU_CVT;
            
            end
            
            `INST_FPU_CVTSW : begin
            
                core_select = FPU_CVT;
                is_itof     = 1;
                is_signed   = 1;
            
            end
            
            `INST_FPU_CVTSWU : begin
            
                core_select = FPU_CVT;
                is_itof     = 1;
            
            end
            
            `INST_FPU_SQRT : begin
                
                core_select = FPU_SQRT;
            
            end
            
            default : begin
            
                core_select = FPU_NCP;  
            
            end
            
        endcase
    
    end
    
    reg has_fflags_n , valid_out_n , ready_in_n;
    reg [`NUM_THREADS-1 : 0] out_fflags_nv;
    reg [`NUM_THREADS-1 : 0] out_fflags_dz;
    reg [`NUM_THREADS-1 : 0] out_fflags_of;
    reg [`NUM_THREADS-1 : 0] out_fflags_uf;
    reg [`NUM_THREADS-1 : 0] out_fflags_nx;
    reg [(`NUM_THREADS*32)-1 : 0] out_result;
    reg [TAGW-1 : 0] tag_out_r;
    
    always@(*)
    begin

        fma_ready_out      = 0;
        cvt_ready_out      = 0;
        ncp_ready_out      = 0;
        has_fflags_n       = 1'b0;
        out_fflags_nv      = {(`NUM_THREADS){1'b0}};
        out_fflags_dz      = {(`NUM_THREADS){1'b0}};
        out_fflags_of      = {(`NUM_THREADS){1'b0}};
        out_fflags_uf      = {(`NUM_THREADS){1'b0}};
        out_fflags_nx      = {(`NUM_THREADS){1'b0}};
        out_result         = {(`NUM_THREADS*32){1'b0}};
        tag_out_r          = {(TAGW){1'b0}};
    
        case(core_select)
        
        
            FPU_FMA : begin
            
                has_fflags_n  = fma_has_fflags;
                out_fflags_nv = fma_fflags_NV;
                out_fflags_dz = fma_fflags_DZ;
                out_fflags_of = fma_fflags_OF;
                out_fflags_uf = fma_fflags_UF;
                out_fflags_nx = fma_fflags_NX;
                out_result    = fma_result;
                tag_out_r     = fma_tag;
                valid_out_n   = fma_valid_out;
                ready_in_n    = fma_ready_in;
                fma_ready_out = ready_out;
            
            end
            
            FPU_CVT : begin
            
                has_fflags_n  = cvt_has_fflags;
                out_fflags_nv = cvt_fflags_NV;
                out_fflags_dz = cvt_fflags_DZ;
                out_fflags_of = cvt_fflags_OF;
                out_fflags_uf = cvt_fflags_UF;
                out_fflags_nx = cvt_fflags_NX;
                out_result    = cvt_result;
                tag_out_r     = cvt_tag;
                valid_out_n   = cvt_valid_out;
                ready_in_n    = cvt_ready_in;
                cvt_ready_out = ready_out;
            
            end
            
            FPU_NCP : begin
            
                has_fflags_n  = ncp_has_fflags;
                out_fflags_nv = ncp_fflags_NV;
                out_fflags_dz = ncp_fflags_DZ;
                out_fflags_of = ncp_fflags_OF;
                out_fflags_uf = ncp_fflags_UF;
                out_fflags_nx = ncp_fflags_NX;
                out_result    = ncp_result;
                tag_out_r     = ncp_tag;
                valid_out_n   = ncp_valid_out;
                ready_in_n    = ncp_ready_in;
                ncp_ready_out = ready_out;
            
            end
            
            FPU_SQRT : begin
            
	            has_fflags_n   = sqrt_has_fflags;
                out_fflags_nv  = sqrt_fflags_NV;
                out_fflags_dz  = sqrt_fflags_DZ;
                out_fflags_of  = sqrt_fflags_OF;
                out_fflags_uf  = sqrt_fflags_UF;
                out_fflags_nx  = sqrt_fflags_NX;
                out_result     = sqrt_result;
                tag_out_r      = sqrt_tag;
                valid_out_n    = sqrt_valid_out;
                ready_in_n     = sqrt_ready_in;
                sqrt_ready_out = ready_out;
            
            end
        
        endcase
    
    end
    
    RV_fp_fma #(
        .TAGW (TAGW),
        .LANES(`NUM_THREADS)
    ) fp_fma (
        .clk        (clk), 
        .reset      (reset),   
        .valid_in   (valid_in && (core_select == FPU_FMA)),
        .ready_in   (fma_ready_in),    
        .tag_in     (tag_in),  
        .frm        (frm),
        .do_madd    (do_madd),
        .do_sub     (do_sub),
        .do_neg     (do_neg),
        .dataa      (dataa), 
        .datab      (datab),    
        .datac      (datac),   
        .has_fflags (fma_has_fflags),
        .fflags_NV  (fma_fflags_NV),          
        .fflags_DZ  (fma_fflags_DZ),          
        .fflags_OF  (fma_fflags_OF),          
        .fflags_UF  (fma_fflags_UF),          
        .fflags_NX  (fma_fflags_NX),          
        .result     (fma_result),
        .tag_out    (fma_tag),
        .ready_out  (fma_ready_out),
        .valid_out  (fma_valid_out)
    );
    
    RV_fp_cvt #(
        .TAGW (TAGW),
        .LANES(`NUM_THREADS)
    ) fp_cvt (
        .clk        (clk), 
        .reset      (reset),   
        .valid_in   (valid_in && (core_select == FPU_CVT)),
        .ready_in   (cvt_ready_in),    
        .tag_in     (tag_in), 
        .frm        (frm),
        .is_itof    (is_itof),   
        .is_signed  (is_signed),        
        .dataa      (dataa),  
        .has_fflags (cvt_has_fflags),

        .fflags_NV  (cvt_fflags_NV),
        .fflags_DZ  (cvt_fflags_DZ),
        .fflags_OF  (cvt_fflags_OF),
        .fflags_UF  (cvt_fflags_UF),
        .fflags_NX  (cvt_fflags_NX),

        .result     (cvt_result),
        .tag_out    (cvt_tag),
        .ready_out  (cvt_ready_out),
        .valid_out  (cvt_valid_out)
    );
    
    RV_fp_ncomp #(
        .TAGW (TAGW),
        .LANES(`NUM_THREADS)
    ) fp_ncomp (
        .clk        (clk),
        .reset      (reset),   
        .valid_in   (valid_in && (core_select == FPU_NCP)),
        .ready_in   (ncp_ready_in),        
        .tag_in     (tag_in),        
        .op_type    (op_type),
        .frm        (frm),
        .dataa      (dataa),
        .datab      (datab),
        .result     (ncp_result), 
        .has_fflags (ncp_has_fflags),

        .fflags_NV  (ncp_fflags_NV),
        .fflags_DZ  (ncp_fflags_DZ),
        .fflags_OF  (ncp_fflags_OF),
        .fflags_UF  (ncp_fflags_UF),
        .fflags_NX  (ncp_fflags_NX),

        .tag_out    (ncp_tag),
        .ready_out  (ncp_ready_out),
        .valid_out  (ncp_valid_out)
    );
    
    RV_fp_sqrt#(
        
        .TAGW(TAGW),
        .LANES(`NUM_THREADS)
    
    )fp_sqrt(
    
        .clk(clk),
        .reset(reset),
        
        .valid_in(valid_in && (core_select == FPU_SQRT)),
        .ready_out(sqrt_ready_out),
        .tag_in(tag_in),
        .frm(frm),
        .dataa(dataa),
        
        .ready_in(sqrt_ready_in),
        .result(sqrt_result),
        .has_fflags(sqrt_has_fflags),
        .fflags_NV(sqrt_fflags_NV), // 4-Invalid
        .fflags_DZ(sqrt_fflags_DZ), // 3-Divide by zero
        .fflags_OF(sqrt_fflags_OF), // 2-Overflow
        .fflags_UF(sqrt_fflags_UF), // 1-Underflow
        .fflags_NX(sqrt_fflags_NX), // 0-Inexact
        .tag_out(sqrt_tag),
        .valid_out(sqrt_valid_out)
    
    );
    
    
    assign valid_out  = valid_out_n;
    assign has_fflags = has_fflags_n;
    assign tag_out    = tag_out_r;
    assign result     = out_result;
    assign fflags_NV  = out_fflags_nv;
    assign fflags_DZ  = out_fflags_dz;
    assign fflags_OF  = out_fflags_of;
    assign fflags_UF  = out_fflags_uf;
    assign fflags_NX  = out_fflags_nx;
    assign ready_in   = ready_in_n;
    
endmodule
