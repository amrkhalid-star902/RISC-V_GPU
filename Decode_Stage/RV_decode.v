`timescale 1ns / 1ps

`include "RV_define.vh"

module RV_decode#(

    parameter CORE_ID = 0

)(

    input wire clk,
    input wire reset,
    
    //Input data from the fetch unit
    input  wire                          ifetch_rsp_if_valid_i,
    input  wire [`UUID_BITS-1 : 0]       ifetch_rsp_if_uuid_i,
    input  wire [`NUM_THREADS-1 : 0]     ifetch_rsp_if_tmask_i,
    input  wire [`NW_BITS-1 : 0]         ifetch_rsp_if_wid_i,
    input  wire [31 : 0]                 ifetch_rsp_if_PC_i,
    input  wire [31 : 0]                 ifetch_rsp_if_data_i,
    input  wire                          decode_if_ready_i,
    
    output wire                          ifetch_rsp_if_ready_o,
    output wire                          decode_if_valid_o,
    output wire [`UUID_BITS-1 : 0]       decode_if_uuid_o,
    output wire [`NW_BITS-1 : 0]         decode_if_wid_o,
    output wire [`NUM_THREADS-1 : 0]     decode_if_tmask_o,
    output wire [31 : 0]                 decode_if_PC_o,
    output wire [`EX_BITS-1 : 0]         decode_if_ex_type_o,
    output wire [`INST_OP_BITS-1 : 0]    decode_if_op_type_o,
    output wire [`INST_MOD_BITS-1 : 0]   decode_if_op_mod_o,
    output wire                          decode_if_wb_o,
    output wire                          decode_if_use_PC_o,
    output wire                          decode_if_use_imm_o,
    output wire [31 : 0]                 decode_if_imm_o,
    output wire [`NR_BITS-1 : 0]         decode_if_rd_o,
    output wire [`NR_BITS-1 : 0]         decode_if_rs1_o,
    output wire [`NR_BITS-1 : 0]         decode_if_rs2_o,
    output wire [`NR_BITS-1 : 0]         decode_if_rs3_o,
    output wire                          wstall_if_valid_o,
    output wire [`NW_BITS-1 : 0]         wstall_if_wid_o,
    output wire                          wstall_if_stalled_o,
    output wire                          join_if_valid_o,
    output wire [`NW_BITS-1 : 0]         join_if_wid_o
    
);
    //Determine the type of the used execution unit
    // 0 -----> No operation
    // 1 -----> ALU unit
    // 2 -----> LSU unit
    // 3 -----> CSR unit
    // 4 -----> FPU unit
    // 5 -----> GPU extension unit
    reg [`EX_BITS-1 : 0] ex_type;
    
    reg [`INST_OP_BITS-1 : 0]  op_type;
    reg [`INST_MOD_BITS-1 : 0] op_mod;
    
    //There are types of registers
    // 1) 32 integer registers
    // 2) 32 float registers
    //To have a flexible mechanism to detect whether
    //the register is integer of float register, an additional
    //bit is concatenated with the register if the bit is zero
    //then the register is integer one, else the register is float one
    reg [`NR_BITS-1 : 0] rd_r, rs1_r, rs2_r, rs3_r;
    
    reg [31 : 0] imm;
    reg use_rd , use_PC , use_imm;
    reg is_join , is_wstall;
    
    //Extracting the fields of instruction
    wire [31 : 0] instr = ifetch_rsp_if_data_i;
    wire [6 : 0] opcode = instr[6 : 0];
    wire [1 : 0] func2  = instr[26 : 25];
    wire [2 : 0] func3  = instr[14 : 12];
    wire [6 : 0] func7  = instr[31 : 25];
    //Extracting immediate field of I-instruction
    wire [11 : 0] u_12  = instr[31 : 20];
    
    wire [4 : 0] rd  = instr[11 : 7];
    wire [4 : 0] rs1 = instr[19 : 15];
    wire [4 : 0] rs2 = instr[24 : 20];
    wire [4 : 0] rs3 = instr[31 : 27];
    
    wire [19 : 0] upper_imm = {func7, rs2, rs1, func3};
    wire [11 : 0] alu_imm   = (func3[0] && ~func3[1]) ? {{7{1'b0}}, rs2} : u_12;
    wire [11 : 0] s_imm     = {func7, rd};
    wire [12 : 0] b_imm     = {instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
    wire [20 : 0] jal_imm   = {instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
    
    always@(*)
    begin
    
        ex_type   = 0;
        op_type   = `INST_OP_BITS'hx;
        op_mod    = 0;
        rd_r      = 0;
        rs1_r     = 0;
        rs2_r     = 0;
        rs3_r     = 0;
        imm       = 32'hx;
        use_imm   = 0;
        use_PC    = 0;
        use_rd    = 0;
        is_join   = 0;
        is_wstall = 0;
        
        case(opcode)
            
            `INST_I: begin
                
                ex_type = `EX_ALU;
                case(func3)
                    
                    3'h0: op_type = `INST_ALU_ADD;
                    3'h1: op_type = `INST_ALU_SLL;
                    3'h2: op_type = `INST_ALU_SLT;
                    3'h3: op_type = `INST_ALU_SLTU;
                    3'h4: op_type = `INST_ALU_XOR;
                    3'h5: op_type = func7[5] ? `INST_ALU_SRA : `INST_ALU_SRL;
                    3'h6: op_type = `INST_ALU_OR;
                    3'h7: op_type = `INST_ALU_AND;
                    default: begin end
                
                endcase//func3
                
                use_rd  = 1;
                use_imm = 1;
                imm     = {{20{alu_imm[11]}}, alu_imm};
                rd_r    = {1'b0 , rd};
                rs1_r   = {1'b0 , rs1};
            
            end//INST_I
            
            `INST_R: begin
            
                ex_type = `EX_ALU;
                if(func7[0])
                begin
                    
                    case(func3)
                   
                        3'h0: op_type = {1'b0 , `INST_MUL_MUL};
                        3'h1: op_type = {1'b0 , `INST_MUL_MULH};
                        3'h2: op_type = {1'b0 , `INST_MUL_MULHSU};
                        3'h3: op_type = {1'b0 , `INST_MUL_MULHU};
                        3'h4: op_type = {1'b0 , `INST_MUL_DIV};
                        3'h5: op_type = {1'b0 , `INST_MUL_DIVU};
                        3'h6: op_type = {1'b0 , `INST_MUL_REM};
                        3'h7: op_type = {1'b0 , `INST_MUL_REMU};
                        default: begin end
                   
                    endcase//func3
                    
                    op_mod = 2;
                    
                end//func7
                else begin
                
                    case(func3)
                    
                        3'h0: op_type = func7[5] ? `INST_ALU_SUB : `INST_ALU_ADD;
                        3'h1: op_type = `INST_ALU_SLL;
                        3'h2: op_type = `INST_ALU_SLT;
                        3'h3: op_type = `INST_ALU_SLTU;
                        3'h4: op_type = `INST_ALU_XOR;
                        3'h5: op_type = func7[5] ? `INST_ALU_SRA : `INST_ALU_SRL;
                        3'h6: op_type = `INST_ALU_OR;
                        3'h7: op_type = `INST_ALU_AND;
                        default: begin end
                    
                    endcase
                
                end//else
                
                use_rd = 1;
                rd_r    = {1'b0 , rd};
                rs1_r   = {1'b0 , rs1};
                rs2_r   = {1'b0 , rs2};
            
            end//`INST_R
            
            `INST_LUI: begin
            
                ex_type = `EX_ALU;
                op_type = `INST_ALU_LUI;
                use_rd  = 1;
                use_imm = 1;
                imm     = {upper_imm, 12'h0};
                rd_r    = {1'b0 , rd};
                rs1_r   = 0;
            
            end//INST_LUI
            
            `INST_AUIPC: begin
            
                ex_type = `EX_ALU;
                op_type = `INST_ALU_AUIPC;
                use_rd  = 1;
                use_imm = 1;
                use_PC  = 1;
                imm     = {upper_imm , 12'h0};
                rd_r    = {1'b0 , rd};
            
            end//`INST_AUIPC
            
            `INST_JAL: begin
                
                ex_type     = `EX_ALU;
                op_type     = `INST_BR_JAL;
                op_mod      = 1;
                use_rd      = 1;
                use_imm     = 1;
                use_PC      = 1;
                is_wstall   = 1;
                imm         = {{11{jal_imm[20]}} , jal_imm};
                rd_r    = {1'b0 , rd};
            
            end//`INST_JAL
            
            `INST_JALR: begin
                
                ex_type     = `EX_ALU;
                op_type     = `INST_BR_JALR;      
                op_mod      = 1;
                use_rd      = 1;
                use_imm     = 1;
                is_wstall   = 1;      
                imm     = {{20{u_12[11]}} , u_12};
                rd_r    = {1'b0 , rd};
                rs1_r   = {1'b0 , rs1};
            
            end//`INST_JALR
            
            `INST_B: begin
            
                ex_type     = `EX_ALU;
                case(func3)
                
                    3'h0: op_type = `INST_BR_EQ;
                    3'h1: op_type = `INST_BR_NE;
                    3'h4: op_type = `INST_BR_LT;
                    3'h5: op_type = `INST_BR_GE;
                    3'h6: op_type = `INST_BR_LTU;
                    3'h7: op_type = `INST_BR_GEU;
                    default: begin end
                
                endcase
                
                op_mod    = 1;
                use_imm   = 1;
                use_PC    = 1;
                is_wstall = 1;
                imm       = {{19{b_imm[12]}}, b_imm};
                rs1_r     = {1'b0 , rs1};
                rs2_r     = {1'b0 , rs2};
            
            end//`INST_B
            
            `INST_FENCE: begin
            
                ex_type = `EX_LSU;
                op_mod  = 1;
            
            end//`INST_FENCE
            
            `INST_SYS: begin
            
                if(func3[1 : 0] != 0)
                begin
                
                    ex_type = `EX_CSR;
                    op_type = {2'b0 , (func3[1:0])};
                    use_rd  = 1;
                    use_imm = func3[2];
                    rd_r    = {1'b0 , rd};
                    imm[`CSR_ADDR_BITS-1 : 0] = u_12; 
                    
                    if(func3[2])
                    begin
                        
                        imm[`CSR_ADDR_BITS +: `NRI_BITS] = rs1;
                    
                    end
                    else begin
                    
                        rs1_r = {1'b0 , rs1};
                    
                    end
                
                end//func3
                else begin
                
                   ex_type = `EX_ALU; 
                    case (u_12)
                    
                       12'h000: op_type = `INST_BR_ECALL;
                       12'h001: op_type = `INST_BR_EBREAK;             
                       12'h002: op_type = `INST_BR_URET;                        
                       12'h102: op_type = `INST_BR_SRET;                        
                       12'h302: op_type = `INST_BR_MRET;
                       default: begin end
                       
                   endcase
                   
                   op_mod    = 1;
                   use_rd    = 1;
                   use_imm   = 1;
                   use_PC    = 1;
                   is_wstall = 1;
                   imm       = 32'd4;
                   rd_r      = {1'b0 , rd};
                
                end
            
            end//`INST_SYS
            
            `INST_FL , 
            `INST_L: begin
                
                ex_type = `EX_LSU;
                op_type = {1'b0 , func3};
                use_rd  = 1;
                imm     = {{20{u_12[11]}} , u_12}; 
                if(opcode[2])
                begin
                    rd_r = {1'b1 , rd};
                end
                else begin
                   rd_r = {1'b0 , rd}; 
                end
                
                rs1_r = {1'b0 , rs1}; 
                    
            end//`INST_FL,`INST_L 
            
            `INST_FS,
            `INST_S: begin
            
                ex_type = `EX_LSU;
                op_type = {1'b1 , func3};
                imm     = {{20{s_imm[11]}} , s_imm}; 
                rs1_r   = {1'b0 , rs1};
                if(opcode[2])
                begin
                    rs2_r   = {1'b1 , rs2};
                end
                else begin
                    rs2_r   = {1'b0 , rs2};
                end
                
            end//`INST_FS , `INST_S
            
            `INST_FMADD,
            `INST_FMSUB,
            `INST_FNMSUB,
            `INST_FNMADD: begin
            
                ex_type = `EX_FPU;
                op_type = opcode[3 : 0];
                op_mod  = func3;
                use_rd  = 1;
                
                rd_r    = {1'b1 , rd};
                rs1_r   = {1'b1 , rs1};
                rs2_r   = {1'b1 , rs2};
                rs3_r   = {1'b1 , rs3};
            
            end//`INST_FNMADD , `INST_FMADD
            
            `INST_FCI: begin
                
                ex_type = `EX_FPU;
                op_mod  = func3;
                use_rd  = 1;
                case(func7)
                
                    7'h00,
                    7'h04,
                    7'h08,
                    7'h0C: begin
                    
                        op_type = func7[3 : 0];
                        rd_r    = {1'b1 , rd};
                        rs1_r   = {1'b1 , rs1};
                        rs2_r   = {1'b1 , rs2};
                    
                    end
                    
                    7'h2C: begin
                    
                        op_type = `INST_FPU_SQRT;
                        rd_r    = {1'b1 , rd};
                        rs1_r   = {1'b1 , rs1};
                    
                    end
                    
                    7'h50: begin
                    
                        op_type = `INST_FPU_CMP;
                        rd_r    = {1'b1 , rd};
                        rs1_r   = {1'b1 , rs1};
                        rs2_r   = {1'b1 , rs2};
                    
                    end
                
                    7'h60: begin
                    
                        op_type = instr[20] ? `INST_FPU_CVTWUS : `INST_FPU_CVTWS;
                        rd_r    = {1'b1 , rd};
                        rs1_r   = {1'b1 , rs1};
                    
                    end
                    
                    7'h68: begin
                    
                        op_type = instr[20] ? `INST_FPU_CVTSWU : `INST_FPU_CVTSW;
                        rd_r    = {1'b1 , rd};
                        rs1_r   = {1'b1 , rs1};
                    
                    end
                    
                    7'h10: begin
                        
                        op_type = `INST_FPU_MISC;
                        op_mod  = {1'b0, func3[1:0]};
                        rd_r    = {1'b1 , rd};
                        rs1_r   = {1'b1 , rs1};
                        rs2_r   = {1'b1 , rs2};
                    
                    end
                    
                    7'h14: begin
                    
                        op_type = `INST_FPU_MISC;
                        op_mod  = func3[0] ? 4 : 3;
                        rd_r    = {1'b1 , rd};
                        rs1_r   = {1'b1 , rs1};
                        rs2_r   = {1'b1 , rs2};
                    
                    end
                    
                    7'h70: begin
                    
                        if(func3[0])
                        begin
                        
                            op_type = `INST_FPU_CLASS;  
                        
                        end
                        else begin
                            
                            op_type = `INST_FPU_MISC;
                            op_mod  = 5;
                        
                        end
                        
                        rd_r    = {1'b1 , rd};
                        rs1_r   = {1'b1 , rs1};
                    
                    end
                    
                    7'h78: begin
                    
                       op_type = `INST_FPU_MISC;
                       op_mod  = 6;
                       rd_r    = {1'b1 , rd};
                       rs1_r   = {1'b1 , rs1}; 
                    
                    end
                    
                    default: begin end
                    
                endcase//funct7
            
            end//`INST_FCI
            
            `INST_GPGPU: begin
            
                ex_type = `EX_GPU;
                case(func3)
                
                    3'h0: begin
                    
                        op_type   = rs2[0] ? `INST_GPU_PRED : `INST_GPU_TMC;
                        is_wstall = 1;
                        rs1_r     = {1'b0 , rs1}; 
                    
                    end
                    
                    3'h1: begin
                    
                        op_type   = `INST_GPU_WSPAWN;
                        rs1_r     = {1'b0 , rs1}; 
                        rs2_r     = {1'b0 , rs2}; 
                    
                    end
                    
                    3'h2: begin
                    
                        op_type   = `INST_GPU_SPLIT;
                        is_wstall = 1;
                        rs1_r     = {1'b0 , rs1};
                    
                    end
                    
                    3'h3: begin
                    
                       op_type = `INST_GPU_JOIN; 
                       is_join = 1;
                    
                    end
                    
                    3'h4: begin
                    
                       op_type   = `INST_GPU_BAR; 
                       is_wstall = 1;
                       rs1_r     = {1'b0 , rs1}; 
                       rs2_r     = {1'b0 , rs2}; 
                    
                    end
                    
                    3'h5: begin
                    
                        ex_type = `EX_LSU;
                        op_mod  = 2;
                        rs1_r   = {1'b0 , rs1};
                    
                    end
                    
                    default: begin  end
                    
                endcase
            
            end//`INST_GPGPU
            
            default: begin  end
                    
        endcase//opcode
        
    end
    
    // disable write to integer register r0
    wire wb = use_rd && (| rd_r);

    assign decode_if_valid_o     = ifetch_rsp_if_valid_i;
    assign decode_if_uuid_o      = ifetch_rsp_if_uuid_i;
    assign decode_if_wid_o       = ifetch_rsp_if_wid_i;
    assign decode_if_tmask_o     = ifetch_rsp_if_tmask_i;
    assign decode_if_PC_o        = ifetch_rsp_if_PC_i;
    assign decode_if_ex_type_o   = ex_type;
    assign decode_if_op_type_o   = op_type;
    assign decode_if_op_mod_o    = op_mod;
    assign decode_if_wb_o        = wb;
    assign decode_if_rd_o        = rd_r;
    assign decode_if_rs1_o       = rs1_r;
    assign decode_if_rs2_o       = rs2_r;
    assign decode_if_rs3_o       = rs3_r;
    assign decode_if_imm_o       = imm;
    assign decode_if_use_PC_o    = use_PC;
    assign decode_if_use_imm_o   = use_imm;

    ///////////////////////////////////////////////////////////////////////////

    wire ifetch_rsp_fire = ifetch_rsp_if_valid_i && ifetch_rsp_if_ready_o;

    assign join_if_valid_o = ifetch_rsp_fire && is_join;
    assign join_if_wid_o = ifetch_rsp_if_wid_i;

    assign wstall_if_valid_o = ifetch_rsp_fire;
    assign wstall_if_wid_o = ifetch_rsp_if_wid_i;
    assign wstall_if_stalled_o = is_wstall;

    assign ifetch_rsp_if_ready_o = decode_if_ready_i;

endmodule

