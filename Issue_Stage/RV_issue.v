`timescale 1ns / 1ps

`include "RV_define.vh"


module RV_issue#(

    parameter CORE_ID = 0

)(
    
    input  wire clk,
    input  wire reset,
    
    input  wire                             decode_if_valid,
    input  wire [`UUID_BITS-1 : 0]          decode_if_uuid,
    input  wire [`NW_BITS-1 : 0]            decode_if_wid,
    input  wire [`NUM_THREADS-1 : 0]        decode_if_tmask,
    input  wire [31 : 0]                    decode_if_PC,
    input  wire [`EX_BITS-1 : 0]            decode_if_ex_type,
    input  wire [`INST_OP_BITS-1 : 0]       decode_if_op_type,
    input  wire [`INST_MOD_BITS-1 : 0]      decode_if_op_mod,
    input  wire                             decode_if_wb,
    input  wire                             decode_if_use_PC,
    input  wire                             decode_if_use_imm,
    input  wire [31 : 0]                    decode_if_imm,
    input  wire [`NR_BITS-1 : 0]            decode_if_rd,
    input  wire [`NR_BITS-1 : 0]            decode_if_rs1,
    input  wire [`NR_BITS-1 : 0]            decode_if_rs2,
    input  wire [`NR_BITS-1 : 0]            decode_if_rs3,
    input  wire                             writeback_if_valid,
    input  wire [`UUID_BITS-1 : 0]          writeback_if_uuid,
    input  wire [`NUM_THREADS-1 : 0]        writeback_if_tmask,
    input  wire [`NW_BITS-1 : 0]            writeback_if_wid,
    input  wire [31 : 0]                    writeback_if_PC,
    input  wire [`NR_BITS-1 : 0]            writeback_if_rd,
    input  wire [(`NUM_THREADS*32)-1 : 0]   writeback_if_data,
    input  wire                             writeback_if_eop,
    //Input ready signals of different units
    input  wire                             alu_req_if_ready,
    input  wire                             lsu_req_if_ready,
    input  wire                             csr_req_if_ready,
    input  wire                             fpu_req_if_ready,
    input  wire                             gpu_req_if_ready,
    
    output wire                             decode_if_ready,
    output wire                             writeback_if_ready,
    
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
    output wire                             gpu_req_if_wb

);
    
    //ibuffer signals
    wire                    		ibuffer_if_valid;    
    wire [`UUID_BITS-1 : 0]   		ibuffer_if_uuid;
    wire [`NW_BITS-1:0]     		ibuffer_if_wid;
    wire [`NUM_THREADS-1 : 0] 		ibuffer_if_tmask;
    wire [31 : 0]             		ibuffer_if_PC;
    wire [`EX_BITS-1 : 0]     		ibuffer_if_ex_type;    
    wire [`INST_OP_BITS-1 : 0] 		ibuffer_if_op_type; 
    wire [`INST_MOD_BITS-1 : 0]     ibuffer_if_op_mod;    
    wire                    		ibuffer_if_wb;
    wire                    		ibuffer_if_use_PC;
    wire                    		ibuffer_if_use_imm;
    wire [31 : 0]             		ibuffer_if_imm;
    wire [`NR_BITS-1 : 0]     		ibuffer_if_rd;
    wire [`NR_BITS-1 : 0]     		ibuffer_if_rs1;
    wire [`NR_BITS-1 : 0]     		ibuffer_if_rs2;
    wire [`NR_BITS-1 : 0]     		ibuffer_if_rs3;
    wire [`NR_BITS-1 : 0]     		ibuffer_if_rd_n;
    wire [`NR_BITS-1 : 0]     		ibuffer_if_rs1_n;
    wire [`NR_BITS-1 : 0]     		ibuffer_if_rs2_n;
    wire [`NR_BITS-1 : 0]     		ibuffer_if_rs3_n;
    wire [`NW_BITS-1 : 0]     		ibuffer_if_wid_n;
    wire                    		ibuffer_if_ready;
    
    //GPR request signals
	wire [`NW_BITS-1 : 0] 			gpr_req_if_wid;
    wire [`NR_BITS-1 : 0]           gpr_req_if_rs1;
    wire [`NR_BITS-1 : 0]           gpr_req_if_rs2;  
    wire [`NR_BITS-1 : 0]           gpr_req_if_rs3;
    
    //GPR request signals
    wire [(`NUM_THREADS*32)-1 : 0]  gpr_rsp_if_rs1_data;
    wire [(`NUM_THREADS*32)-1 : 0]  gpr_rsp_if_rs2_data;
    wire [(`NUM_THREADS*32)-1 : 0]  gpr_rsp_if_rs3_data;
    
    //Scoreboarding writeback signals
    wire 							sboard_wb_if_valid;
    wire [`UUID_BITS-1 : 0] 	    sboard_wb_if_uuid;
    wire [`NUM_THREADS-1 : 0]       sboard_wb_if_tmask;
    
    wire [`NW_BITS-1 : 0]           sboard_wb_if_wid; 
    wire [31 : 0]                   sboard_wb_if_PC;
    wire [`NR_BITS-1 : 0]           sboard_wb_if_rd;
    wire                            sboard_wb_if_eop; 
    wire                            sboard_wb_if_ready;
    
    //ibuffer --> scoreboard signals
    wire                    		scoreboard_if_valid;    
    wire [`UUID_BITS-1 : 0]   		scoreboard_if_uuid;
    wire [`NW_BITS- 1 :0]           scoreboard_if_wid;
    wire [`NUM_THREADS-1 : 0] 		scoreboard_if_tmask;
    wire [31 : 0]             		scoreboard_if_PC;
    wire [`EX_BITS-1 : 0]     		scoreboard_if_ex_type;    
    wire [`INST_OP_BITS-1 : 0]      scoreboard_if_op_type; 
    wire [`INST_MOD_BITS-1 : 0]     scoreboard_if_op_mod;
    wire                    		scoreboard_if_wb;
    wire                    		scoreboard_if_use_PC;
    wire                    		scoreboard_if_use_imm;
    wire [31 : 0]            	    scoreboard_if_imm;
    wire [`NR_BITS-1 : 0]     		scoreboard_if_rd;
    wire [`NR_BITS-1 : 0]     		scoreboard_if_rs1;
    wire [`NR_BITS-1 : 0]           scoreboard_if_rs2;
    wire [`NR_BITS-1 : 0]           scoreboard_if_rs3;
    wire [`NR_BITS-1 : 0]     		scoreboard_if_rd_n;
    wire [`NR_BITS-1 : 0]           scoreboard_if_rs1_n;
    wire [`NR_BITS-1 : 0]           scoreboard_if_rs2_n;
    wire [`NR_BITS-1 : 0]           scoreboard_if_rs3_n;
    wire [`NW_BITS-1 : 0]           scoreboard_if_wid_n;
    wire                    		scoreboard_if_ready;
    
    wire [(`NUM_THREADS * 32) - 1 : 0] sboard_wb_if_data;
    
    //dispatch unit signals
    wire                    		dispatch_if_valid;    
    wire [`UUID_BITS-1 : 0]         dispatch_if_uuid;
    wire [`NW_BITS-1 : 0]           dispatch_if_wid;
    wire [`NUM_THREADS-1 : 0]       dispatch_if_tmask;
    wire [31:0]                     dispatch_if_PC;
    wire [`EX_BITS-1 : 0]           dispatch_if_ex_type;    
    wire [`INST_OP_BITS-1 : 0]      dispatch_if_op_type; 
    wire [`INST_MOD_BITS-1 : 0]     dispatch_if_op_mod;    
    wire                            dispatch_if_wb;
    wire                            dispatch_if_use_PC;
    wire                            dispatch_if_use_imm;
    wire [31 : 0]                   dispatch_if_imm;
    wire [`NR_BITS-1 : 0]           dispatch_if_rd;
    wire [`NR_BITS-1 : 0]           dispatch_if_rs1;
    wire [`NR_BITS-1 : 0]     		dispatch_if_rs2;
    wire [`NR_BITS-1 : 0]           dispatch_if_rs3;   
    wire [`NR_BITS-1 : 0]           dispatch_if_rd_n;
    wire [`NR_BITS-1 : 0]           dispatch_if_rs1_n;
    wire [`NR_BITS-1 : 0]           dispatch_if_rs2_n;
    wire [`NR_BITS-1 : 0]           dispatch_if_rs3_n;
    wire [`NW_BITS-1 : 0]           dispatch_if_wid_n;
    wire                    		dispatch_if_ready;
    
    
    assign gpr_req_if_wid       = ibuffer_if_wid;
    assign gpr_req_if_rs1       = ibuffer_if_rs1;
    assign gpr_req_if_rs2       = ibuffer_if_rs2;
    assign gpr_req_if_rs3       = ibuffer_if_rs3;
    
    assign sboard_wb_if_valid   = writeback_if_valid;
    assign sboard_wb_if_uuid    = writeback_if_uuid;
    assign sboard_wb_if_wid     = writeback_if_wid;
    assign sboard_wb_if_PC      = writeback_if_PC;
    assign sboard_wb_if_rd      = writeback_if_rd;
    assign sboard_wb_if_eop     = writeback_if_eop;
    
    assign scoreboard_if_valid  = ibuffer_if_valid && dispatch_if_ready;
    assign scoreboard_if_uuid   = ibuffer_if_uuid;
    assign scoreboard_if_wid    = ibuffer_if_wid;
    assign scoreboard_if_PC     = ibuffer_if_PC;   
    assign scoreboard_if_wb     = ibuffer_if_wb;      
    assign scoreboard_if_rd     = ibuffer_if_rd;
    assign scoreboard_if_rd_n   = ibuffer_if_rd_n;        
    assign scoreboard_if_rs1_n  = ibuffer_if_rs1_n;        
    assign scoreboard_if_rs2_n  = ibuffer_if_rs2_n;        
    assign scoreboard_if_rs3_n  = ibuffer_if_rs3_n;        
    assign scoreboard_if_wid_n  = ibuffer_if_wid_n;
    
    assign dispatch_if_valid    = ibuffer_if_valid && scoreboard_if_ready;
    assign dispatch_if_uuid     = ibuffer_if_uuid;
    assign dispatch_if_wid      = ibuffer_if_wid;
    assign dispatch_if_tmask    = ibuffer_if_tmask;
    assign dispatch_if_PC       = ibuffer_if_PC;
    assign dispatch_if_ex_type  = ibuffer_if_ex_type;    
    assign dispatch_if_op_type  = ibuffer_if_op_type; 
    assign dispatch_if_op_mod   = ibuffer_if_op_mod;    
    assign dispatch_if_wb       = ibuffer_if_wb;
    assign dispatch_if_rd       = ibuffer_if_rd;
    assign dispatch_if_rs1      = ibuffer_if_rs1;
    assign dispatch_if_imm      = ibuffer_if_imm;        
    assign dispatch_if_use_PC   = ibuffer_if_use_PC;
    assign dispatch_if_use_imm  = ibuffer_if_use_imm;
    
    assign ibuffer_if_ready = scoreboard_if_ready && dispatch_if_ready;

    
    RV_ibuffer #(
        
        .CORE_ID(CORE_ID)
        
    ) ibuffer (
        .clk   (clk),
        .reset (reset),
    
        .decode_if_valid(decode_if_valid),    
        .decode_if_uuid(decode_if_uuid),
        .decode_if_wid(decode_if_wid),
        .decode_if_tmask(decode_if_tmask),
        .decode_if_PC(decode_if_PC),
        .decode_if_ex_type(decode_if_ex_type),    
        .decode_if_op_type(decode_if_op_type),
        .decode_if_op_mod(decode_if_op_mod),    
        .decode_if_wb(decode_if_wb),
        .decode_if_use_PC(decode_if_use_PC),
        .decode_if_use_imm(decode_if_use_imm),
        .decode_if_imm(decode_if_imm),
        .decode_if_rd(decode_if_rd),
        .decode_if_rs1(decode_if_rs1),
        .decode_if_rs2(decode_if_rs2),
        .decode_if_rs3(decode_if_rs3),
        .decode_if_ready(decode_if_ready),
        
        .ibuffer_if_valid(ibuffer_if_valid),    
        .ibuffer_if_uuid(ibuffer_if_uuid),
        .ibuffer_if_wid(ibuffer_if_wid),
        .ibuffer_if_tmask(ibuffer_if_tmask),
        .ibuffer_if_PC(ibuffer_if_PC),
        .ibuffer_if_ex_type(ibuffer_if_ex_type),
        .ibuffer_if_op_type(ibuffer_if_op_type), 
        .ibuffer_if_op_mod(ibuffer_if_op_mod),    
        .ibuffer_if_wb(ibuffer_if_wb),
        .ibuffer_if_use_PC(ibuffer_if_use_PC),
        .ibuffer_if_use_imm(ibuffer_if_use_imm),
        .ibuffer_if_imm(ibuffer_if_imm),
        .ibuffer_if_rd(ibuffer_if_rd),
        .ibuffer_if_rs1(ibuffer_if_rs1),
        .ibuffer_if_rs2(ibuffer_if_rs2),
        .ibuffer_if_rs3(ibuffer_if_rs3),
        
        .ibuffer_if_rd_n(ibuffer_if_rd_n),
        .ibuffer_if_rs1_n(ibuffer_if_rs1_n),
        .ibuffer_if_rs2_n(ibuffer_if_rs2_n),
        .ibuffer_if_rs3_n(ibuffer_if_rs3_n),
        .ibuffer_if_wid_n(ibuffer_if_wid_n),
    
        .ibuffer_if_ready(ibuffer_if_ready)
        
    );    
    

    RV_scoreboard  #(
    
        .CORE_ID(CORE_ID)   
        
    ) scoreboard (
    
        .clk   (clk),
        .reset (reset),
    
        .ibuffer_if_valid (scoreboard_if_valid),   
        .ibuffer_if_uuid (scoreboard_if_uuid),
        .ibuffer_if_wid (scoreboard_if_wid),
        .ibuffer_if_tmask (scoreboard_if_tmask),
        .ibuffer_if_PC (scoreboard_if_PC),
        .ibuffer_if_ex_type (scoreboard_if_ex_type),    
        .ibuffer_if_op_type (scoreboard_if_op_type),
        .ibuffer_if_op_mod (scoreboard_if_op_mod),    
        .ibuffer_if_wb (scoreboard_if_wb),
        .ibuffer_if_use_PC (scoreboard_if_use_PC),
        .ibuffer_if_use_imm (scoreboard_if_use_imm),
        .ibuffer_if_imm (scoreboard_if_imm),
        .ibuffer_if_rd (scoreboard_if_rd),
        .ibuffer_if_rs1 (scoreboard_if_rs1),
        .ibuffer_if_rs2 (scoreboard_if_rs2),
        .ibuffer_if_rs3 (scoreboard_if_rs3),
        
        .ibuffer_if_rd_n (scoreboard_if_rd_n),
        .ibuffer_if_rs1_n (scoreboard_if_rs1_n),
        .ibuffer_if_rs2_n (scoreboard_if_rs2_n),
        .ibuffer_if_rs3_n (scoreboard_if_rs3_n),
        .ibuffer_if_wid_n (scoreboard_if_wid_n),
    
        .ibuffer_if_ready (scoreboard_if_ready),
    
        .writeback_if_valid (sboard_wb_if_valid),
        .writeback_if_uuid (sboard_wb_if_uuid),
        .writeback_if_tmask (sboard_wb_if_tmask),
        .writeback_if_wid (sboard_wb_if_wid), 
        .writeback_if_PC (sboard_wb_if_PC),
        .writeback_if_rd (sboard_wb_if_rd),
        .writeback_if_data (sboard_wb_if_data),
        .writeback_if_eop (sboard_wb_if_eop),  
        .writeback_if_ready (sboard_wb_if_ready)

    );
    
    
    RV_gpr_stage #(
    
        .CORE_ID(CORE_ID)
        
    ) gpr_stage (
    
        .clk   (clk),      
        .reset (reset),
    
        .writeback_if_valid(writeback_if_valid),
        .writeback_if_uuid(writeback_if_uuid),
        .writeback_if_tmask(writeback_if_tmask),
        .writeback_if_wid(writeback_if_wid), 
        .writeback_if_PC(writeback_if_PC),
        .writeback_if_rd(writeback_if_rd),
        .writeback_if_data(writeback_if_data),
        .writeback_if_eop(writeback_if_eop),    
        .writeback_if_ready(writeback_if_ready),
      
        .gpr_req_if_wid(gpr_req_if_wid),
        .gpr_req_if_rs1(gpr_req_if_rs1),
        .gpr_req_if_rs2(gpr_req_if_rs2),  
        .gpr_req_if_rs3(gpr_req_if_rs3),
    
        .gpr_rsp_if_rs1_data(gpr_rsp_if_rs1_data),
        .gpr_rsp_if_rs2_data(gpr_rsp_if_rs2_data),
        .gpr_rsp_if_rs3_data(gpr_rsp_if_rs3_data)
    
    );
    
    
    RV_dispatch dispatch (
    
        .clk   (clk),
        .reset (reset),
    
        .ibuffer_if_valid  (dispatch_if_valid),    
        .ibuffer_if_uuid  (dispatch_if_uuid),
        .ibuffer_if_wid  (dispatch_if_wid),
        .ibuffer_if_tmask  (dispatch_if_tmask),
        .ibuffer_if_PC  (dispatch_if_PC),
        .ibuffer_if_ex_type (dispatch_if_ex_type),    
        .ibuffer_if_op_type  (dispatch_if_op_type), 
        .ibuffer_if_op_mod  (dispatch_if_op_mod),    
        .ibuffer_if_wb  (dispatch_if_wb),
        .ibuffer_if_use_PC  (dispatch_if_use_PC),
        .ibuffer_if_use_imm  (dispatch_if_use_imm),
        .ibuffer_if_imm  (dispatch_if_imm),
        .ibuffer_if_rd  (dispatch_if_rd),
        .ibuffer_if_rs1  (dispatch_if_rs1),
        .ibuffer_if_rs2  (dispatch_if_rs2),
        .ibuffer_if_rs3  (dispatch_if_rs3),
        
        .ibuffer_if_rd_n  (dispatch_if_rd_n),
        .ibuffer_if_rs1_n  (dispatch_if_rs1_n),
        .ibuffer_if_rs2_n  (dispatch_if_rs2_n),
        .ibuffer_if_rs3_n  (dispatch_if_rs3_n),
        .ibuffer_if_wid_n  (dispatch_if_wid_n),
    
        .ibuffer_if_ready  (dispatch_if_ready),
    
        .gpr_rsp_if_rs1_data(gpr_rsp_if_rs1_data),
        .gpr_rsp_if_rs2_data(gpr_rsp_if_rs2_data),
        .gpr_rsp_if_rs3_data(gpr_rsp_if_rs3_data),
    
        .alu_req_if_valid(alu_req_if_valid),  
        .alu_req_if_uuid(alu_req_if_uuid), 
        .alu_req_if_wid(alu_req_if_wid),
        .alu_req_if_tmask(alu_req_if_tmask),
        .alu_req_if_PC(alu_req_if_PC),
        .alu_req_if_next_PC(alu_req_if_next_PC),
        .alu_req_if_op_type(alu_req_if_op_type),
        .alu_req_if_op_mod(alu_req_if_op_mod),
        .alu_req_if_use_PC(alu_req_if_use_PC),
        .alu_req_if_use_imm(alu_req_if_use_imm),
        .alu_req_if_imm(alu_req_if_imm),
        .alu_req_if_tid(alu_req_if_tid),
        .alu_req_if_rs1_data(alu_req_if_rs1_data),
        .alu_req_if_rs2_data(alu_req_if_rs2_data),
        .alu_req_if_rd(alu_req_if_rd),
        .alu_req_if_wb(alu_req_if_wb),    
        .alu_req_if_ready(alu_req_if_ready),
    
        .lsu_req_if_valid(lsu_req_if_valid),
        .lsu_req_if_uuid(lsu_req_if_uuid), 
        .lsu_req_if_wid(lsu_req_if_wid),
        .lsu_req_if_tmask(lsu_req_if_tmask),
        .lsu_req_if_PC(lsu_req_if_PC),
        .lsu_req_if_op_type(lsu_req_if_op_type),
        .lsu_req_if_is_fence(lsu_req_if_is_fence),
        .lsu_req_if_store_data(lsu_req_if_store_data),
        .lsu_req_if_base_addr(lsu_req_if_base_addr),    
        .lsu_req_if_offset(lsu_req_if_offset),
        .lsu_req_if_rd(lsu_req_if_rd),
        .lsu_req_if_wb(lsu_req_if_wb),
        .lsu_req_if_is_prefetch(lsu_req_if_is_prefetch),
        .lsu_req_if_ready(lsu_req_if_ready),
    
        .csr_req_if_valid(csr_req_if_valid),
        .csr_req_if_uuid(csr_req_if_uuid),
        .csr_req_if_wid(csr_req_if_wid),
        .csr_req_if_tmask(csr_req_if_tmask),
        .csr_req_if_PC(csr_req_if_PC),
        .csr_req_if_op_type(csr_req_if_op_type),
        .csr_req_if_addr(csr_req_if_addr),
        .csr_req_if_rs1_data(csr_req_if_rs1_data),
        .csr_req_if_use_imm(csr_req_if_use_imm),
        .csr_req_if_imm(csr_req_if_imm),
        .csr_req_if_rd(csr_req_if_rd),
        .csr_req_if_wb(csr_req_if_wb),    
        .csr_req_if_ready(csr_req_if_ready),
    
        .fpu_req_if_valid(fpu_req_if_valid),
        .fpu_req_if_uuid(fpu_req_if_uuid),
        .fpu_req_if_wid(fpu_req_if_wid),
        .fpu_req_if_tmask(fpu_req_if_tmask),
        .fpu_req_if_PC(fpu_req_if_PC),
        .fpu_req_if_op_type(fpu_req_if_op_type),
        .fpu_req_if_op_mod(fpu_req_if_op_mod),
        .fpu_req_if_rs1_data(fpu_req_if_rs1_data),
        .fpu_req_if_rs2_data(fpu_req_if_rs2_data),
        .fpu_req_if_rs3_data(fpu_req_if_rs3_data),
        .fpu_req_if_rd(fpu_req_if_rd),
        .fpu_req_if_wb(fpu_req_if_wb),        
        .fpu_req_if_ready(fpu_req_if_ready),
    

        .gpu_req_if_valid(gpu_req_if_valid),
        .gpu_req_if_uuid(gpu_req_if_uuid),
        .gpu_req_if_wid(gpu_req_if_wid),
        .gpu_req_if_tmask(gpu_req_if_tmask),
        .gpu_req_if_PC(gpu_req_if_PC),
        .gpu_req_if_next_PC(gpu_req_if_next_PC),
        .gpu_req_if_op_type(gpu_req_if_op_type),
        .gpu_req_if_op_mod(gpu_req_if_op_mod),
        .gpu_req_if_tid(gpu_req_if_tid),
        .gpu_req_if_rs1_data(gpu_req_if_rs1_data),
        .gpu_req_if_rs2_data(gpu_req_if_rs2_data),
        .gpu_req_if_rs3_data(gpu_req_if_rs3_data),
        .gpu_req_if_rd(gpu_req_if_rd),
        .gpu_req_if_wb(gpu_req_if_wb),
        .gpu_req_if_ready(gpu_req_if_ready)
        
    );

    
endmodule
