`timescale 1ns / 1ps

`include "RV_define.vh"


module RV_dispatch(
    
    input  wire clk,
    input  wire reset,
    
    input  wire                             ibuffer_if_valid,
    input  wire [`UUID_BITS-1 : 0]          ibuffer_if_uuid,
    input  wire [`NW_BITS-1 : 0]            ibuffer_if_wid,
    input  wire [`NUM_THREADS-1 : 0]        ibuffer_if_tmask,
    input  wire [31 : 0]                    ibuffer_if_PC,
    input  wire [`EX_BITS-1 : 0]            ibuffer_if_ex_type,
    input  wire [`INST_OP_BITS-1 : 0]       ibuffer_if_op_type,
    input  wire [`INST_MOD_BITS-1 : 0]      ibuffer_if_op_mod,
    input  wire                             ibuffer_if_wb,
    input  wire                             ibuffer_if_use_PC,
    input  wire                             ibuffer_if_use_imm,
    input  wire [31 : 0]                    ibuffer_if_imm,
    input  wire [`NR_BITS-1 : 0]            ibuffer_if_rd,
    input  wire [`NR_BITS-1 : 0]            ibuffer_if_rs1,
    input  wire [`NR_BITS-1 : 0]            ibuffer_if_rs2,
    input  wire [`NR_BITS-1 : 0]            ibuffer_if_rs3,
    input  wire [`NR_BITS-1 : 0]            ibuffer_if_rd_n,
    input  wire [`NR_BITS-1 : 0]            ibuffer_if_rs1_n,
    input  wire [`NR_BITS-1 : 0]            ibuffer_if_rs2_n,
    input  wire [`NR_BITS-1 : 0]            ibuffer_if_rs3_n,
    input  wire [`NW_BITS-1 : 0]            ibuffer_if_wid_n,
    input  wire [(`NUM_THREADS*32)-1 : 0]   gpr_rsp_if_rs1_data,
    input  wire [(`NUM_THREADS*32)-1 : 0]   gpr_rsp_if_rs2_data,
    input  wire [(`NUM_THREADS*32)-1 : 0]   gpr_rsp_if_rs3_data,
    //Input ready signals of different units
    input  wire                             alu_req_if_ready,
    input  wire                             lsu_req_if_ready,
    input  wire                             csr_req_if_ready,
    input  wire                             fpu_req_if_ready,
    input  wire                             gpu_req_if_ready,
    
    output wire                             ibuffer_if_ready,
    //ALU output signals
    output wire                             alu_req_if_valid,
    output wire [`UUID_BITS-1 : 0]          alu_req_if_uuid ,
    output wire [`NW_BITS-1 : 0]            alu_req_if_wid,
    output wire [`NUM_THREADS-1 : 0]        alu_req_if_tmask,
    output wire [31 : 0]                    alu_req_if_PC,
    output wire [31 : 0]                    alu_req_if_next_PC,
    output wire [`INST_ALU_BITS-1 : 0]      alu_req_if_op_type,
    output wire [`INST_MOD_BITS-1 : 0]      alu_req_if_op_mod,
    output wire                             alu_req_if_use_PC,
    output wire                             alu_req_if_use_imm,
    output wire [31 : 0]                    alu_req_if_imm,
    output wire [`NT_BITS-1 : 0]            alu_req_if_tid,
    output wire [(`NUM_THREADS*32)-1 : 0]   alu_req_if_rs1_data,
    output wire [(`NUM_THREADS*32)-1 : 0]   alu_req_if_rs2_data,
    output wire [`NR_BITS-1 : 0]            alu_req_if_rd,
    output wire                             alu_req_if_wb,
    
    //LSU output signals
    output wire                             lsu_req_if_valid,
    output wire [`UUID_BITS-1 : 0]          lsu_req_if_uuid ,
    output wire [`NW_BITS-1 : 0]            lsu_req_if_wid,
    output wire [`NUM_THREADS-1 : 0]        lsu_req_if_tmask,
    output wire [31 : 0]                    lsu_req_if_PC,
    output wire [`INST_LSU_BITS-1 : 0]      lsu_req_if_op_type,
    output wire                             lsu_req_if_is_fence,
    output wire [(`NUM_THREADS*32)-1 : 0]   lsu_req_if_store_data,
    output wire [(`NUM_THREADS*32)-1 : 0]   lsu_req_if_base_addr,
    output wire [31 : 0]                    lsu_req_if_offset,
    output wire [`NR_BITS-1 : 0]            lsu_req_if_rd,
    output wire                             lsu_req_if_wb,
    output wire                             lsu_req_if_is_prefetch,
    
    //CSR output signals
    output wire                             csr_req_if_valid,
    output wire [`UUID_BITS-1 : 0]          csr_req_if_uuid ,
    output wire [`NW_BITS-1 : 0]            csr_req_if_wid,
    output wire [`NUM_THREADS-1 : 0]        csr_req_if_tmask,
    output wire [31 : 0]                    csr_req_if_PC,
    output wire [`INST_CSR_BITS-1 : 0]      csr_req_if_op_type,
    output wire [`CSR_ADDR_BITS-1 : 0]      csr_req_if_addr,
    output wire [31 : 0]                    csr_req_if_rs1_data,
    output wire                             csr_req_if_use_imm,
    output wire [`NRI_BITS-1 : 0]           csr_req_if_imm,
    output wire [`NR_BITS-1 : 0]            csr_req_if_rd,
    output wire                             csr_req_if_wb,
    
    //FPU output signals
    output wire                             fpu_req_if_valid,
    output wire [`UUID_BITS-1 : 0]          fpu_req_if_uuid ,
    output wire [`NW_BITS-1 : 0]            fpu_req_if_wid,
    output wire [`NUM_THREADS-1 : 0]        fpu_req_if_tmask,
    output wire [31 : 0]                    fpu_req_if_PC,
    output wire [`INST_FPU_BITS-1 : 0]      fpu_req_if_op_type,
    output wire [`INST_MOD_BITS-1 : 0]      fpu_req_if_op_mod,
    output wire [(`NUM_THREADS*32)-1 : 0]   fpu_req_if_rs1_data,
    output wire [(`NUM_THREADS*32)-1 : 0]   fpu_req_if_rs2_data,
    output wire [(`NUM_THREADS*32)-1 : 0]   fpu_req_if_rs3_data,
    output wire [`NR_BITS-1 : 0]            fpu_req_if_rd,
    output wire                             fpu_req_if_wb,
    
    //GPU output signals
    output wire                             gpu_req_if_valid,
    output wire [`UUID_BITS-1 : 0]          gpu_req_if_uuid ,
    output wire [`NW_BITS-1 : 0]            gpu_req_if_wid,
    output wire [`NUM_THREADS-1 : 0]        gpu_req_if_tmask,
    output wire [31 : 0]                    gpu_req_if_PC,
    output wire [31 : 0]                    gpu_req_if_next_PC,
    output wire [`INST_GPU_BITS-1 : 0]      gpu_req_if_op_type,
    output wire [`INST_MOD_BITS-1 : 0]      gpu_req_if_op_mod,
    output wire [`NT_BITS-1 : 0]            gpu_req_if_tid,
    output wire [(`NUM_THREADS*32)-1 : 0]   gpu_req_if_rs1_data,
    output wire [(`NUM_THREADS*32)-1 : 0]   gpu_req_if_rs2_data,
    output wire [(`NUM_THREADS*32)-1 : 0]   gpu_req_if_rs3_data,
    output wire [`NR_BITS-1 : 0]            gpu_req_if_rd,
    output wire                    			gpu_req_if_wb

);


    wire [`NT_BITS-1 : 0] tid;
    wire alu_req_ready;
    wire lsu_req_ready;
    wire csr_req_ready;  
    wire fpu_req_ready;
    wire gpu_req_ready;
    
    //Selection of the next available thread to be executed
    RV_lzc #(
    
        .N (`NUM_THREADS)
        
    ) tid_select (
    
        .in_i    (ibuffer_if_tmask),
        .cnt_o   (tid),
        .valid_o ()
        
    );
    
    wire [31:0] next_PC = ibuffer_if_PC + 4;
    
    //ALU unit output setup
    wire alu_req_valid = ibuffer_if_valid && (ibuffer_if_ex_type == `EX_ALU);
    
    wire [`INST_ALU_BITS-1 : 0] alu_op_type = (ibuffer_if_op_type);
    
    RV_skid_buffer #(
    
        .DATAW   (`UUID_BITS + `NW_BITS + `NUM_THREADS + 32 + 32 + `INST_ALU_BITS + `INST_MOD_BITS + 32 + 1 + 1 + `NR_BITS + 1 + `NT_BITS + (2 * `NUM_THREADS * 32)),
        .OUT_REG (1)
        
    ) alu_buffer (
    
        .clk       (clk),
        .reset     (reset),
        .valid_in  (alu_req_valid),
        .ready_in  (alu_req_ready),
        .data_in   ({ibuffer_if_uuid, ibuffer_if_wid, ibuffer_if_tmask, ibuffer_if_PC, next_PC,            alu_op_type,        ibuffer_if_op_mod, ibuffer_if_imm, ibuffer_if_use_PC, ibuffer_if_use_imm, ibuffer_if_rd, ibuffer_if_wb, tid,            gpr_rsp_if_rs1_data, gpr_rsp_if_rs2_data}),
        .data_out  ({alu_req_if_uuid, alu_req_if_wid, alu_req_if_tmask, alu_req_if_PC, alu_req_if_next_PC, alu_req_if_op_type, alu_req_if_op_mod, alu_req_if_imm, alu_req_if_use_PC, alu_req_if_use_imm, alu_req_if_rd, alu_req_if_wb, alu_req_if_tid, alu_req_if_rs1_data, alu_req_if_rs2_data}),
        .valid_out (alu_req_if_valid),
        .ready_out (alu_req_if_ready)
        
    );

    
    //LSU unit output setup
    wire lsu_req_valid = ibuffer_if_valid && (ibuffer_if_ex_type == `EX_LSU);
    
    wire [`INST_LSU_BITS-1 : 0] lsu_op_type = (ibuffer_if_op_type);
    
    wire lsu_is_fence    = (ibuffer_if_op_mod == 3'h1);
    wire lsu_is_prefetch = (ibuffer_if_op_mod == 3'h2);
    
    RV_skid_buffer #(
    
        .DATAW   (`UUID_BITS + `NW_BITS + `NUM_THREADS + 32 + `INST_LSU_BITS + 1 + 32 + `NR_BITS + 1 + (2 * `NUM_THREADS * 32) + 1),
        .OUT_REG (1)
        
    ) lsu_buffer (
    
        .clk       (clk),
        .reset     (reset),
        .valid_in  (lsu_req_valid),
        .ready_in  (lsu_req_ready),
        .data_in   ({ibuffer_if_uuid, ibuffer_if_wid, ibuffer_if_tmask, ibuffer_if_PC, lsu_op_type,        lsu_is_fence,        ibuffer_if_imm,    ibuffer_if_rd, ibuffer_if_wb, gpr_rsp_if_rs1_data,  gpr_rsp_if_rs2_data, lsu_is_prefetch}),
        .data_out  ({lsu_req_if_uuid, lsu_req_if_wid, lsu_req_if_tmask, lsu_req_if_PC, lsu_req_if_op_type, lsu_req_if_is_fence, lsu_req_if_offset, lsu_req_if_rd, lsu_req_if_wb, lsu_req_if_base_addr, lsu_req_if_store_data, lsu_req_if_is_prefetch}),
        .valid_out (lsu_req_if_valid),
        .ready_out (lsu_req_if_ready)
        
    );
    
    //CSR unit output setup
    wire csr_req_valid = ibuffer_if_valid && (ibuffer_if_ex_type == `EX_CSR);
    
    wire [`INST_CSR_BITS-1 : 0] csr_op_type = (ibuffer_if_op_type[`INST_CSR_BITS-1 : 0]);
    wire [`CSR_ADDR_BITS-1 : 0] csr_addr    = ibuffer_if_imm[`CSR_ADDR_BITS-1 : 0];
    wire [`NRI_BITS-1 : 0] csr_imm          = ibuffer_if_imm[`CSR_ADDR_BITS  +:  `NRI_BITS];
    wire [31 : 0] csr_rs1_data              = gpr_rsp_if_rs1_data[tid*32 +: 32];
    

    RV_skid_buffer #(
        
        .DATAW   (`UUID_BITS + `NW_BITS + `NUM_THREADS + 32 + `INST_CSR_BITS + `CSR_ADDR_BITS + `NR_BITS + 1 + 1 + `NRI_BITS + 32),
        .OUT_REG (1)
            
    ) csr_buffer (
        
        .clk       (clk),
        .reset     (reset),
        .valid_in  (csr_req_valid),
        .ready_in  (csr_req_ready),
        .data_in   ({ibuffer_if_uuid, ibuffer_if_wid, ibuffer_if_tmask, ibuffer_if_PC, csr_op_type,        csr_addr,        ibuffer_if_rd, ibuffer_if_wb, ibuffer_if_use_imm, csr_imm,        csr_rs1_data}),
        .data_out  ({csr_req_if_uuid, csr_req_if_wid, csr_req_if_tmask, csr_req_if_PC, csr_req_if_op_type, csr_req_if_addr, csr_req_if_rd, csr_req_if_wb, csr_req_if_use_imm, csr_req_if_imm, csr_req_if_rs1_data}),
        .valid_out (csr_req_if_valid),
        .ready_out (csr_req_if_ready)
            
    );
        
    //FPU unit output setup  
    wire fpu_req_valid = ibuffer_if_valid && (ibuffer_if_ex_type == `EX_FPU);
    wire [`INST_FPU_BITS-1 : 0] fpu_op_type = (ibuffer_if_op_type);
    
    RV_skid_buffer #(
    
        .DATAW   (`UUID_BITS + `NW_BITS + `NUM_THREADS + 32 + `INST_FPU_BITS + `INST_MOD_BITS + `NR_BITS + 1 + (3 * `NUM_THREADS * 32)),
        .OUT_REG (1)
        
    ) fpu_buffer (
    
        .clk       (clk),
        .reset     (reset),
        .valid_in  (fpu_req_valid),
        .ready_in  (fpu_req_ready),
        .data_in   ({ibuffer_if_uuid, ibuffer_if_wid, ibuffer_if_tmask, ibuffer_if_PC, fpu_op_type,        ibuffer_if_op_mod, ibuffer_if_rd, ibuffer_if_wb, gpr_rsp_if_rs1_data, gpr_rsp_if_rs2_data, gpr_rsp_if_rs3_data}),
        .data_out  ({fpu_req_if_uuid, fpu_req_if_wid, fpu_req_if_tmask, fpu_req_if_PC, fpu_req_if_op_type, fpu_req_if_op_mod, fpu_req_if_rd, fpu_req_if_wb, fpu_req_if_rs1_data, fpu_req_if_rs2_data, fpu_req_if_rs3_data}),
        .valid_out (fpu_req_if_valid),
        .ready_out (fpu_req_if_ready)
        
    );
    
    //GPU unit output setup 
    wire gpu_req_valid = ibuffer_if_valid && (ibuffer_if_ex_type == `EX_GPU);
    wire [`INST_GPU_BITS-1 : 0] gpu_op_type = (ibuffer_if_op_type);
    
    RV_skid_buffer #(
    
        .DATAW   (`UUID_BITS + `NW_BITS + `NUM_THREADS + 32 + 32 + `INST_GPU_BITS + `INST_MOD_BITS + `NR_BITS + 1 + `NT_BITS  + (3 * `NUM_THREADS * 32)),
        .OUT_REG (1)
        
    ) gpu_buffer (
    
        .clk       (clk),
        .reset     (reset),
        .valid_in  (gpu_req_valid),
        .ready_in  (gpu_req_ready),
        .data_in   ({ibuffer_if_uuid, ibuffer_if_wid, ibuffer_if_tmask, ibuffer_if_PC, next_PC,            gpu_op_type,        ibuffer_if_op_mod, ibuffer_if_rd, ibuffer_if_wb, tid,            gpr_rsp_if_rs1_data, gpr_rsp_if_rs2_data, gpr_rsp_if_rs3_data}),
        .data_out  ({gpu_req_if_uuid, gpu_req_if_wid, gpu_req_if_tmask, gpu_req_if_PC, gpu_req_if_next_PC, gpu_req_if_op_type, gpu_req_if_op_mod, gpu_req_if_rd, gpu_req_if_wb, gpu_req_if_tid, gpu_req_if_rs1_data, gpu_req_if_rs2_data, gpu_req_if_rs3_data}),
        .valid_out (gpu_req_if_valid),
        .ready_out (gpu_req_if_ready)
        
    ); 
    
    reg ready_r;
    always@(*)
    begin
    
        case(ibuffer_if_ex_type)
            
            `EX_ALU : ready_r = alu_req_ready;
            `EX_LSU : ready_r = lsu_req_ready;
            `EX_CSR : ready_r = csr_req_ready;
            `EX_FPU : ready_r = fpu_req_ready;
            `EX_GPU : ready_r = gpu_req_ready;
            default : ready_r = 1'b1;
        
        endcase
    
    end
    
    assign ibuffer_if_ready = ready_r;
    
endmodule
