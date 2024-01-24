`timescale 1ns / 1ps

`include "RV_define.vh"


module RV_alu_unit#(

    parameter CORE_ID = 0

)(
    
    input  wire clk,
    input  wire reset,
    
    input  wire                             alu_req_if_valid,
    input  wire [`UUID_BITS-1 : 0]          alu_req_if_uuid,
    input  wire [`NW_BITS-1 : 0]            alu_req_if_wid,
    input  wire [`NUM_THREADS-1 : 0]        alu_req_if_tmask,
    input  wire [31 : 0]                    alu_req_if_PC,
    input  wire [31 : 0]                    alu_req_if_next_PC,
    input  wire [`INST_ALU_BITS-1 : 0]      alu_req_if_op_type,
    input  wire [`INST_MOD_BITS-1 : 0]      alu_req_if_op_mod,
    input  wire                             alu_req_if_use_PC,
    input  wire                             alu_req_if_use_imm,
    input  wire [31 : 0]                    alu_req_if_imm,
    input  wire [`NT_BITS-1 : 0]            alu_req_if_tid,
    input  wire [(`NUM_THREADS*32)-1 : 0]   alu_req_if_rs1_data,
    input  wire [(`NUM_THREADS*32)-1 : 0]   alu_req_if_rs2_data,
    input  wire [`NR_BITS-1 : 0]            alu_req_if_rd,
    input  wire                             alu_req_if_wb,
    input  wire                             alu_commit_if_ready,
    
    output wire                             alu_req_if_ready,
    output wire                             branch_ctl_if_valid,
    output wire [`NW_BITS-1 : 0]            branch_ctl_if_wid,
    output wire                             branch_ctl_if_taken,
    output wire [31 : 0]                    branch_ctl_if_dest,
    output wire                             alu_commit_if_valid,
    output wire [`UUID_BITS-1 : 0]          alu_commit_if_uuid,
    output wire [`NW_BITS-1 : 0]            alu_commit_if_wid,
    output wire [`NUM_THREADS-1 : 0]        alu_commit_if_tmask,
    output wire [31 : 0]                    alu_commit_if_PC,
    output wire [(`NUM_THREADS*32)-1 : 0]   alu_commit_if_data,
    output wire [`NR_BITS-1 : 0]            alu_commit_if_rd,
    output wire                             alu_commit_if_wb,
    output wire                             alu_commit_if_eop
    
);

    wire [31 : 0] alu_req_if_rs1_data_2d [`NUM_THREADS-1 : 0];
    wire [31 : 0] alu_req_if_rs2_data_2d [`NUM_THREADS-1 : 0];
    wire [31 : 0] alu_jal_result         [`NUM_THREADS-1 : 0];
    wire [(`NUM_THREADS*32)-1 : 0] alu_jal_result_1d;
    
    genvar i;
    generate
    
        for(i = 0 ; i < `NUM_THREADS ; i = i + 1)
        begin
        
            assign alu_req_if_rs1_data_2d[i] = alu_req_if_rs1_data[((i+1)*32)-1 : i*32];
            assign alu_req_if_rs2_data_2d[i] = alu_req_if_rs2_data[((i+1)*32)-1 : i*32];
            
            assign alu_jal_result_1d[((i+1)*32)-1 : i*32] = alu_jal_result[i];
            
        end
    
    endgenerate
    
    reg [31 : 0] alu_result [`NUM_THREADS-1 : 0];
    
    wire [31 : 0] add_result  [`NUM_THREADS-1 : 0];
    wire [32 : 0] sub_result  [`NUM_THREADS-1 : 0];
    wire [31 : 0] shr_result  [`NUM_THREADS-1 : 0];
    reg  [31 : 0] misc_result [`NUM_THREADS-1 : 0];
    
    wire ready_in;
    
    wire                          is_br_op     = `INST_ALU_IS_BR(alu_req_if_op_mod);
    wire [`INST_ALU_BITS-1 : 0]   alu_op       = alu_req_if_op_type;
    wire [`INST_BR_BITS-1 : 0]    br_op        = alu_req_if_op_type;
    wire                          alu_signed   = `INST_ALU_SIGNED(alu_op); 
    wire [1 : 0]                  alu_op_class = `INST_ALU_OP_CLASS(alu_op); 
    wire                          is_sub       = (alu_op == `INST_ALU_SUB);
    
    wire [31 : 0] alu_in1      [`NUM_THREADS-1 : 0];
    wire [31 : 0] alu_in2      [`NUM_THREADS-1 : 0];
    wire [31 : 0] alu_in1_PC   [`NUM_THREADS-1 : 0];
    wire [31 : 0] alu_in2_imm  [`NUM_THREADS-1 : 0];
    wire [31 : 0] alu_in2_less [`NUM_THREADS-1 : 0];
    
    genvar j;
    generate
    
        for(j = 0 ; j < `NUM_THREADS ; j = j + 1)
        begin
        
            assign alu_in1[j] = alu_req_if_rs1_data_2d[j];
            assign alu_in2[j] = alu_req_if_rs2_data_2d[j];
            
            assign alu_in1_PC[j]   = alu_req_if_use_PC ? alu_req_if_PC : alu_in1[j];
            assign alu_in2_imm[j]  = alu_req_if_use_imm ? alu_req_if_imm : alu_in2[j];
            assign alu_in2_less[j] = (alu_req_if_use_imm && ~is_br_op) ? alu_req_if_imm : alu_in2[j];
        
        end
        
        for(j = 0 ; j < `NUM_THREADS ; j = j + 1)
        begin
        
            assign add_result[j] = alu_in1_PC[j] + alu_in2_imm[j];
        
        end    
        
        for(j = 0 ; j < `NUM_THREADS ; j = j + 1)
        begin
        
            wire [32 : 0] sub_in1 = {alu_signed & alu_in1[j][31] , alu_in1[j]};
            wire [32 : 0] sub_in2 = {alu_signed & alu_in2_less[j][31] , alu_in2_less[j]};
            
            assign sub_result[j] = sub_in1 - sub_in2;
            
        end
        
        for(j = 0 ; j < `NUM_THREADS ; j = j + 1)
        begin
        
            wire [32 : 0] shr_in1 = {alu_signed & alu_in1[j][31] , alu_in1[j]};
            assign shr_result[j]  = ($signed(shr_in1) >>> alu_in2_imm[j]);
        
        end
        
        for(j = 0 ; j < `NUM_THREADS ; j = j + 1)
        begin
        
            always@(*)
            begin
            
                case(alu_op)
                
                    `INST_ALU_AND: misc_result[j] = alu_in1[j] & alu_in2_imm[j];
                    `INST_ALU_OR:  misc_result[j] = alu_in1[j] | alu_in2_imm[j];
                    `INST_ALU_XOR: misc_result[j] = alu_in1[j] ^ alu_in2_imm[j];
                    default: misc_result[j] = alu_in1[j] << alu_in2_imm[j][4:0];
                
                endcase
            
            end
        
        end
        
        for(j = 0 ; j < `NUM_THREADS ; j = j + 1)
        begin
        
            always@(*)
            begin
            
                case(alu_op_class)
                
                    2'b00: alu_result[j] = add_result[j];
                    2'b01: alu_result[j] = {31'b0 , sub_result[j][32]};
                    2'b10: alu_result[j] = is_sub ? sub_result[j][31:0] : shr_result[j];
                    default: alu_result[j] = misc_result[j];
                
                endcase
            
            end
        
        end
    
    endgenerate
    
    wire is_jal = is_br_op && (br_op == `INST_BR_JAL || br_op == `INST_BR_JALR);
    generate
    
        for(i = 0 ; i < `NUM_THREADS ; i = i + 1)
        begin
            assign alu_jal_result [i] = is_jal ? alu_req_if_next_PC : alu_result[i]; 
        end
    
    endgenerate
    
    wire [31 : 0] br_dest    = add_result[alu_req_if_tid];
    wire [32 : 0] cmp_result = sub_result[alu_req_if_tid];  
    
    wire is_less  = cmp_result[32];
    wire is_equal = ~(|cmp_result[31:0]);
    
    wire alu_valid_in;
    wire alu_ready_in;
    wire alu_valid_out;
    wire alu_ready_out;
    
    wire [`UUID_BITS-1 : 0]         alu_uuid;
    wire [`NW_BITS-1 : 0]           alu_wid;
    wire [`NUM_THREADS-1 : 0]       alu_tmask;
    wire [31 : 0]                   alu_PC;
    wire [`NR_BITS-1 : 0]           alu_rd;
    wire                            alu_wb;
    wire [(`NUM_THREADS*32)-1 : 0]  alu_data_1d;
    wire [`INST_BR_BITS-1 : 0]      br_op_r;
    wire [31 : 0]                   br_dest_r;
    wire                            is_less_r;
    wire                            is_equal_r;
    wire                            is_br_op_r;
    
    assign alu_ready_in = alu_ready_out || ~alu_valid_out;
    
    RV_pipe_register #(
    
        .DATAW  (1 + `UUID_BITS + `NW_BITS + `NUM_THREADS + 32 + `NR_BITS + 1 + (`NUM_THREADS * 32) + 1 + `INST_BR_BITS + 1 + 1 + 32),
        .RESETW (1)
        
    ) pipe_reg (
    
        .clk      (clk),
        .reset    (reset),
        .enable   (alu_ready_in),
        .data_in  ({alu_valid_in,  alu_req_if_uuid, alu_req_if_wid, alu_req_if_tmask, alu_req_if_PC, alu_req_if_rd, alu_req_if_wb, alu_jal_result_1d, is_br_op,   br_op,   is_less,   is_equal,   br_dest}),
        .data_out ({alu_valid_out, alu_uuid,        alu_wid,        alu_tmask,        alu_PC,        alu_rd,        alu_wb,        alu_data_1d,       is_br_op_r, br_op_r, is_less_r, is_equal_r, br_dest_r})
    
    );
    
    wire br_neg    = `INST_BR_NEG(br_op_r); 
    wire br_less   = `INST_BR_LESS(br_op_r);
    wire br_static = `INST_BR_STATIC(br_op_r); 
    
    assign branch_ctl_if_valid = alu_valid_out && alu_ready_out && is_br_op_r;
    assign branch_ctl_if_taken = ((br_less ? is_less_r : is_equal_r) ^ br_neg) | br_static;
    assign branch_ctl_if_wid   = alu_wid;
    assign branch_ctl_if_dest  = br_dest_r;
    
    //MUL-DIV unit
    wire                        mul_valid_in;
    wire                        mul_ready_in;
    wire                        mul_valid_out; 
    wire                        mul_ready_out;
    wire [`UUID_BITS-1 : 0]     mul_uuid;
    wire [`NW_BITS-1 : 0]       mul_wid;
    wire [`NUM_THREADS-1 : 0]   mul_tmask;
    wire [31 : 0]               mul_PC;
    wire [`NR_BITS-1 : 0]       mul_rd;
    wire                        mul_wb;
    
    wire [(`NUM_THREADS*32)-1 : 0] mul_data_1d;
    wire [`INST_MUL_BITS-1:0] mul_op = alu_req_if_op_type[`INST_MUL_BITS-1 : 0];
    
    RV_muldiv muldiv ( 
    
        .clk        (clk),
        .reset      (reset),
        
        // Inputs
        .alu_op     (mul_op),
        .uuid_in    (alu_req_if_uuid),
        .wid_in     (alu_req_if_wid),
        .tmask_in   (alu_req_if_tmask),
        .PC_in      (alu_req_if_PC),
        .rd_in      (alu_req_if_rd),
        .wb_in      (alu_req_if_wb),
        .alu_in1    (alu_req_if_rs1_data), 
        .alu_in2    (alu_req_if_rs2_data),
    
        // Outputs
        .wid_out    (mul_wid),
        .uuid_out   (mul_uuid),
        .tmask_out  (mul_tmask),
        .PC_out     (mul_PC),
        .rd_out     (mul_rd),
        .wb_out     (mul_wb),
        .data_out   (mul_data_1d),
    
        // handshake
        .valid_in   (mul_valid_in),
        .ready_in   (mul_ready_in),
        .valid_out  (mul_valid_out),
        .ready_out  (mul_ready_out)
        
    );
    
    wire is_mul_op = `INST_ALU_IS_MUL(alu_req_if_op_mod);
    
    assign ready_in      = is_mul_op ? mul_ready_in : alu_ready_in;
    assign alu_valid_in  = alu_req_if_valid && ~is_mul_op;
    assign mul_valid_in  = alu_req_if_valid && is_mul_op;
    assign mul_ready_out = alu_commit_if_ready & ~alu_valid_out;
    
    assign alu_commit_if_valid    = alu_valid_out || mul_valid_out;
    assign alu_commit_if_uuid     = alu_valid_out ? alu_uuid  : mul_uuid;
    assign alu_commit_if_wid      = alu_valid_out ? alu_wid   : mul_wid;
    assign alu_commit_if_tmask    = alu_valid_out ? alu_tmask : mul_tmask;
    assign alu_commit_if_PC       = alu_valid_out ? alu_PC    : mul_PC;
    assign alu_commit_if_rd       = alu_valid_out ? alu_rd    : mul_rd;
    assign alu_commit_if_wb       = alu_valid_out ? alu_wb    : mul_wb;
    assign alu_ready_out          = alu_commit_if_ready;
    assign alu_commit_if_data     = alu_valid_out ? alu_data_1d  : mul_data_1d;
    
    assign alu_commit_if_eop = 1'b1;
    assign alu_req_if_ready  = ready_in;
    
     
endmodule
