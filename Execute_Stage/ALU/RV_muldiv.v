`timescale 1ns / 1ps

`include "RV_define.vh"

module RV_muldiv(

    input  wire clk,
    input  wire reset,
    
    input  wire [`INST_MUL_BITS-1 : 0]             alu_op,
    input  wire [`UUID_BITS-1 : 0]                 uuid_in,
    input  wire [`NW_BITS-1 : 0]                   wid_in,
    input  wire [`NUM_THREADS-1 : 0]               tmask_in,
    input  wire [31 : 0]                           PC_in,
    input  wire [`NR_BITS-1 : 0]                   rd_in,
    input  wire                                    wb_in,
    input  wire [(`NUM_THREADS*32)-1 : 0]          alu_in1,
    input  wire [(`NUM_THREADS*32)-1 : 0]          alu_in2,
    input  wire                                    valid_in,
    input  wire                                    ready_out,
    
    output wire [`UUID_BITS-1 : 0]                 uuid_out,
    output wire [`NW_BITS-1 : 0]                   wid_out,
    output wire [`NUM_THREADS-1 : 0]               tmask_out,
    output wire [31 : 0]                           PC_out,
    output wire [`NR_BITS-1 : 0]                   rd_out,
    output wire                                    wb_out,
    output wire [(`NUM_THREADS*32)-1 : 0]          data_out,
    output wire                                    ready_in,
    output wire                                    valid_out
    
);
    
    wire [31 : 0] alu_in1_2d [`NUM_THREADS-1 : 0];
    wire [31 : 0] alu_in2_2d [`NUM_THREADS-1 : 0];
    wire [31 : 0] mul_result [`NUM_THREADS-1 : 0]; 
    
    wire [(`NUM_THREADS*32)-1 : 0] mul_result_1d;
    
    
    genvar i;
    generate
    
        for(i = 0 ; i < `NUM_THREADS ; i = i + 1)
        begin
        
            assign alu_in1_2d[i] = alu_in1[((i+1)*32)-1 : i*32];
            assign alu_in2_2d[i] = alu_in2[((i+1)*32)-1 : i*32];
            
            assign mul_result_1d[((i+1)*32)-1 : i*32] = mul_result[i];
            
        end
        
    endgenerate
    wire stall_out;
    wire is_div_op = `INST_MUL_IS_DIV(alu_op);
    
    wire [`UUID_BITS-1 : 0]   mul_uuid_out;
    wire [`NW_BITS-1 : 0]     mul_wid_out;
    wire [`NUM_THREADS-1 : 0] mul_tmask_out;
    wire [31 : 0]             mul_PC_out;
    wire [`NR_BITS-1 : 0]     mul_rd_out;
    wire                      mul_wb_out;
    wire                      mul_valid_out;
    
    wire mul_valid_in = valid_in && !is_div_op; 
    wire mul_ready_in = ~stall_out || ~mul_valid_out;
    
    wire is_mulh_in      = (alu_op != `INST_MUL_MUL);
    wire is_signed_mul_a = (alu_op != `INST_MUL_MULHU);
    wire is_signed_mul_b = (alu_op != `INST_MUL_MULHU && alu_op != `INST_MUL_MULHSU);
    
    wire is_mulh_out;
    
    generate
    
        for(i = 0 ; i < `NUM_THREADS ; i = i + 1)
        begin
        
            wire [32:0] mul_in1 = {is_signed_mul_a & alu_in1_2d[i][31] , alu_in1_2d[i]};
            wire [32:0] mul_in2 = {is_signed_mul_b & alu_in2_2d[i][31] , alu_in2_2d[i]};
            wire [65:0] mul_result_tmp;
            
            RV_multiplier #(
            
                .WIDTHA  (33),
                .WIDTHB  (33),
                .WIDTHP  (66),
                .SIGNED  (1),
                .LATENCY (`LATENCY_IMUL)
                
            ) multiplier (
            
                .clk    (clk),
                .enable (mul_ready_in),
                .dataa  (mul_in1),
                .datab  (mul_in2),
                .result (mul_result_tmp)
                
            );
            
            assign mul_result[i] = is_mulh_out ? mul_result_tmp[63:32] : mul_result_tmp[31:0];
        
        end
    
    endgenerate
    
    RV_shift_register #(
    
        .DATAW  (1 + `UUID_BITS + `NW_BITS + `NUM_THREADS + 32 + `NR_BITS + 1 + 1),
        .DEPTH  (`LATENCY_IMUL),
        .RESETW (1)
        
    ) mul_shift_reg (
    
        .clk(clk),
        .reset    (reset),
        .enable   (mul_ready_in),
        .data_in  ({mul_valid_in,  uuid_in,      wid_in,      tmask_in,       PC_in,      rd_in,      wb_in,      is_mulh_in}),
        .data_out ({mul_valid_out, mul_uuid_out, mul_wid_out, mul_tmask_out,  mul_PC_out, mul_rd_out, mul_wb_out, is_mulh_out})
    
    );
    
    //Divison Side
    wire [(`NUM_THREADS*32)-1 : 0] div_result;
    
    wire [`UUID_BITS-1 : 0]   div_uuid_out;
    wire [`NW_BITS-1 : 0]     div_wid_out;
    wire [`NUM_THREADS-1 : 0] div_tmask_out;
    wire [31 : 0]             div_PC_out;
    wire [`NR_BITS-1 : 0]     div_rd_out;
    wire                      div_wb_out;
    
    wire is_rem_op_in  = (alu_op == `INST_MUL_REM) || (alu_op == `INST_MUL_REMU);
    wire is_signed_div = (alu_op == `INST_MUL_DIV) || (alu_op == `INST_MUL_REM);     
    wire div_valid_in  = valid_in && is_div_op; 
    wire div_ready_out = ~stall_out && ~mul_valid_out;
    wire div_ready_in;
    wire div_valid_out;
    
    wire [(`NUM_THREADS*32)-1 : 0] div_result_tmp , rem_result_tmp;
    wire is_rem_op_out;
    
    RV_serial_div #(
    
        .WIDTHN (32),
        .WIDTHD (32),
        .WIDTHQ (32),
        .WIDTHR (32),
        .LANES  (`NUM_THREADS),
        .TAGW   (64 + `NW_BITS + `NUM_THREADS + 32 + `NR_BITS + 1 + 1)
    
    ) divide (
    
        .clk       (clk),
        .reset     (reset),        
        .valid_in  (div_valid_in),
        .ready_in  (div_ready_in),
        .signed_mode(is_signed_div),
        .tag_in    ({uuid_in, wid_in, tmask_in, PC_in, rd_in, wb_in, is_rem_op_in}),
        .numer     (alu_in1),
        .denom     (alu_in2),
        .quotient  (div_result_tmp),
        .remainder (rem_result_tmp),
        .ready_out (div_ready_out),
        .valid_out (div_valid_out),
        .tag_out   ({div_uuid_out, div_wid_out, div_tmask_out, div_PC_out, div_rd_out, div_wb_out, is_rem_op_out})
    
    );
    
    assign div_result = is_rem_op_out ? rem_result_tmp : div_result_tmp; 
    
    //Response
    wire                      rsp_valid = mul_valid_out || div_valid_out;  
    wire [`UUID_BITS-1 : 0]   rsp_uuid  = mul_valid_out ? mul_uuid_out : div_uuid_out;
    wire [`NW_BITS-1 : 0]     rsp_wid   = mul_valid_out ? mul_wid_out : div_wid_out;
    wire [`NUM_THREADS-1 : 0] rsp_tmask = mul_valid_out ? mul_tmask_out : div_tmask_out;
    wire [31 : 0]             rsp_PC    = mul_valid_out ? mul_PC_out : div_PC_out;
    wire [`NR_BITS-1 : 0]     rsp_rd    = mul_valid_out ? mul_rd_out : div_rd_out;
    wire                      rsp_wb    = mul_valid_out ? mul_wb_out : div_wb_out;
    
    wire [(`NUM_THREADS*32)-1 : 0] rsp_data = mul_valid_out ? mul_result_1d : div_result;
    
    assign stall_out = ~ready_out && valid_out;
    
    RV_pipe_register #(
    
        .DATAW  (1 + `UUID_BITS + `NW_BITS + `NUM_THREADS + 32 + `NR_BITS + 1 + (`NUM_THREADS * 32)),
        .RESETW (1)
        
    ) pipe_reg (
    
        .clk      (clk),
        .reset    (reset),
        .enable   (~stall_out),
        .data_in  ({rsp_valid, rsp_uuid, rsp_wid, rsp_tmask, rsp_PC, rsp_rd, rsp_wb, rsp_data}),
        .data_out ({valid_out, uuid_out, wid_out, tmask_out, PC_out, rd_out, wb_out, data_out})
        
    );
    
    assign ready_in = is_div_op ? div_ready_in : mul_ready_in;
    
    
endmodule
