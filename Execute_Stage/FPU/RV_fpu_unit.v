`timescale 1ns / 1ps

`include "RV_define.vh"

module RV_fpu_unit#(
    
    parameter CORE_ID = 0

)(
    
    input wire clk,
    input wire reset,
      
    input wire                             fpu_req_if_valid,
    input wire [`UUID_BITS-1 : 0]          fpu_req_if_uuid,
    input wire [`NW_BITS-1 : 0]            fpu_req_if_wid,     //The ID of requested warp
    input wire [`NUM_THREADS-1 : 0]        fpu_req_if_tmask,   //Thread Mask
    input wire [31 : 0]                    fpu_req_if_PC,
    input wire [`INST_FPU_BITS-1 : 0]      fpu_req_if_op_type,
    input wire [`INST_MOD_BITS-1 : 0]      fpu_req_if_op_mod,
    input wire [(`NUM_THREADS*32)-1 : 0]   fpu_req_if_rs1_data,
    input wire [(`NUM_THREADS*32)-1 : 0]   fpu_req_if_rs2_data,
    input wire [(`NUM_THREADS*32)-1 : 0]   fpu_req_if_rs3_data,
    input wire [`NR_BITS-1 : 0]            fpu_req_if_rd,
    input wire                             fpu_req_if_wb,
    input wire [`INST_FRM_BITS-1 : 0]      fpu_to_csr_if_read_frm,
    input wire                             fpu_commit_if_ready,
    input wire [`NUM_WARPS-1 : 0]          csr_pending,
    
    output wire                            fpu_req_if_ready,
    output wire                            fpu_to_csr_if_write_enable,
    output wire [`NW_BITS-1 : 0]           fpu_to_csr_if_write_wid,
    output wire                            fpu_to_csr_if_write_fflags_NV,
    output wire                            fpu_to_csr_if_write_fflags_DZ,
    output wire                            fpu_to_csr_if_write_fflags_OF,
    output wire                            fpu_to_csr_if_write_fflags_UF,
    output wire                            fpu_to_csr_if_write_fflags_NX,
    output wire [`NW_BITS-1 : 0]           fpu_to_csr_if_read_wid,
    output wire                            fpu_commit_if_valid,
    output wire [`UUID_BITS-1 : 0]         fpu_commit_if_uuid,
    output wire [`NW_BITS-1 : 0]           fpu_commit_if_wid,
    output wire [`NUM_THREADS-1 : 0]       fpu_commit_if_tmask,
    output wire [31 : 0]                   fpu_commit_if_PC,
    output wire [(`NUM_THREADS*32)-1 : 0]  fpu_commit_if_data,
    output wire [`NR_BITS-1 : 0]           fpu_commit_if_rd,
    output wire                            fpu_commit_if_wb,
    output wire                            fpu_commit_if_eop,
    output wire [`NUM_WARPS-1 : 0]         pending
    
);

    `UNUSED_PARAM(CORE_ID)
    
    //Instruction Queue Depth
    localparam FPUQ_BITS = (`FPUQ_SIZE > 1) ? $clog2(`FPUQ_SIZE) : 1;
    
    //Some signals related to fpu core
    wire ready_in;
    wire valid_out;
    wire ready_out;
    
    //Meta Data that indentify each request
    wire [`UUID_BITS-1 : 0]    rsp_uuid;
    wire [`NW_BITS-1 : 0]      rsp_wid; //warp id
    wire [`NUM_THREADS-1 : 0]  rsp_tmask;
    wire [31 : 0]              rsp_PC;
    wire [`NR_BITS-1 : 0]      rsp_rd;
    wire                       rsp_wb;
    
    wire                       has_fflags;
    
    //Status Flags for each thread
    
    wire    [`NUM_THREADS-1:0]  fflags_NV;  // 4-Invalid
    wire    [`NUM_THREADS-1:0]  fflags_DZ;  // 3-Divide by zero
    wire    [`NUM_THREADS-1:0]  fflags_OF;  // 2-Overflow
    wire    [`NUM_THREADS-1:0]  fflags_UF;  // 1-Underflow
    wire    [`NUM_THREADS-1:0]  fflags_NX;  // 0-Inexact
    
    
    //Result of FPU Operation.
    wire [(`NUM_THREADS*32) - 1:0] result;
    
    //Tags are used to keep track of each request
    wire [FPUQ_BITS-1:0] tag_in, tag_out; 
    wire fpuq_full;
    
    wire fpuq_push = fpu_req_if_valid && fpu_req_if_ready;
    wire fpuq_pop  = valid_out && ready_out;
    
    //The index buffer is used to keep track of the meta data 
    //associated with each request , so the requests can be easily tracked
    RV_index_buffer #(
    
        .DATAW   (`UUID_BITS + `NW_BITS + `NUM_THREADS + 32 + `NR_BITS + 1),    //  Size of Metadata
        .SIZE    (`FPUQ_SIZE)   
        
    ) req_metadata  (
    
        .clk          (clk),        
        .reset        (reset),      
        .acquire_slot (fpuq_push),       
        .write_addr   (tag_in),                
        .read_addr    (tag_out),    
        .release_addr (tag_out),    
        .write_data   ({fpu_req_if_uuid, fpu_req_if_wid, fpu_req_if_tmask, fpu_req_if_PC, fpu_req_if_rd, fpu_req_if_wb}),  
        .read_data    ({rsp_uuid,        rsp_wid,        rsp_tmask,        rsp_PC,        rsp_rd,        rsp_wb}),          
        .release_slot (fpuq_pop),   
        .full         (fpuq_full),  
        .empty()         
        
    );
    
    //In order for FPU unit to receieve a new request 
    //the following conditions must be met:
    //1. The core is ready to recieve data.
    //2. The request queue mustnot be full.
    //3. The current request is not waiting,
    //to finish updating the control status register (CSR).
    assign fpu_req_if_ready = ready_in && ~fpuq_full && !csr_pending[fpu_req_if_wid];
    
    wire valid_in = fpu_req_if_valid && ~fpuq_full && !csr_pending[fpu_req_if_wid];
    
    //The ID of the current warp writing to CSR
    assign fpu_to_csr_if_read_wid = fpu_req_if_wid;
    
    
    //The rounding mode has two options : static and dynamic rounding modes
    //If the mode is dynamic the core gets the rounding type from CSR according
    //to RISCV specifications
    //The dymaic mode happens when FRM is set to 111(INST_FRM_DYN)
    wire [`INST_FRM_BITS-1:0] fpu_frm = (fpu_req_if_op_mod == `INST_FRM_DYN) ? fpu_to_csr_if_read_frm : fpu_req_if_op_mod;
    
    
    RV_fpu_fpga #(
    
        .TAGW (FPUQ_BITS)       // Tag Width.
        
    ) fpu_fpga (
    
        .clk        (clk),      //  Clock.
        .reset      (reset),    //  Reset.

        .valid_in   (valid_in), //  Incoming Data is Valid.
        .ready_in   (ready_in), //  FPU DPI is ready for operation.       

        .tag_in     (tag_in),   //  Tag of incoming operation.
        
        .op_type    (fpu_req_if_op_type),   //  OPCode.
        .frm        (fpu_frm),              //  Rounding Mode.

        .dataa      (fpu_req_if_rs1_data),  //  Operand 1.
        .datab      (fpu_req_if_rs2_data),  //  Operand 2.
        .datac      (fpu_req_if_rs3_data),  //  Operand 3.
        .result     (result),               //  Result.

        .has_fflags (has_fflags),           //  Flag indicating whether operation generates Status Flags.
        
        .fflags_NV  (fflags_NV),            //  Output Status Flags.
        .fflags_DZ  (fflags_DZ),            //  Output Status Flags.
        .fflags_OF  (fflags_OF),            //  Output Status Flags.
        .fflags_UF  (fflags_UF),            //  Output Status Flags.
        .fflags_NX  (fflags_NX),            //  Output Status Flags.

        .tag_out    (tag_out),              //  Tag of completed operation.

        .ready_out  (ready_out),            //  Is Commit Ready for Result.
        .valid_out  (valid_out)             //  Validity of Output Result.
        
    );
    
    
    wire  has_fflags_r;
    wire [4 : 0] fflags_r;
    wire [4 : 0] rsp_fflags;
    
    reg     rsp_fflags_NV;  
    reg     rsp_fflags_DZ;  
    reg     rsp_fflags_OF;  
    reg     rsp_fflags_UF;  
    reg     rsp_fflags_NX;  
    
    assign rsp_fflags = {rsp_fflags_NV, rsp_fflags_DZ, rsp_fflags_OF, rsp_fflags_UF, rsp_fflags_NX};
    
    integer i;
    
    always @(*) 
    begin

        //  Default value of 0.
        rsp_fflags_NX = 0;
        rsp_fflags_UF = 0;
        rsp_fflags_OF = 0;
        rsp_fflags_DZ = 0;    
        rsp_fflags_NV = 0;

        //  Flag is set if any active thread produces that flag.
        for (i = 0; i < `NUM_THREADS; i = i + 1) begin
            if (rsp_tmask[i]) begin
                
                rsp_fflags_NV = rsp_fflags_NV | fflags_NV[i];
                rsp_fflags_DZ = rsp_fflags_DZ | fflags_DZ[i];
                rsp_fflags_OF = rsp_fflags_OF | fflags_OF[i];
                rsp_fflags_UF = rsp_fflags_UF | fflags_UF[i];
                rsp_fflags_NX = rsp_fflags_NV | fflags_NX[i];
                
            end
            
        end
        
    end 
    
    wire stall_out = ~fpu_commit_if_ready && fpu_commit_if_valid;
    
    RV_pipe_register #(

        .DATAW  (1 + `UUID_BITS + `NW_BITS + `NUM_THREADS + 32 + `NR_BITS + 1 + (`NUM_THREADS * 32) + 1 + 5),
        .RESETW (1)
        
    ) pipe_reg (
    
        .clk      (clk),    
        .reset    (reset),  
        .enable   (!stall_out), 
        .data_in  ({valid_out,           rsp_uuid,           rsp_wid,           rsp_tmask,           rsp_PC,           rsp_rd,           rsp_wb,           result,             has_fflags,   rsp_fflags}),
        .data_out ({fpu_commit_if_valid, fpu_commit_if_uuid, fpu_commit_if_wid, fpu_commit_if_tmask, fpu_commit_if_PC, fpu_commit_if_rd, fpu_commit_if_wb, fpu_commit_if_data, has_fflags_r, fflags_r})
        
    );
    
    assign fpu_commit_if_eop = 1'b1;
    assign ready_out = ~stall_out;
    
    assign fpu_to_csr_if_write_enable = fpu_commit_if_valid && fpu_commit_if_ready && has_fflags_r;
    assign fpu_to_csr_if_write_wid    = fpu_commit_if_wid;    
    
    //Flags to be wrtten into CSR register
    assign {fpu_to_csr_if_write_fflags_NV, fpu_to_csr_if_write_fflags_DZ, 
            fpu_to_csr_if_write_fflags_OF, fpu_to_csr_if_write_fflags_UF, fpu_to_csr_if_write_fflags_NX} = fflags_r;
    
    
    //Determining whether the current warp is finished excution or not
    reg [`NUM_WARPS-1:0] pending_r; //  Registered Pending Request.   
    always @(posedge clk) 
    begin
        //Reset Pending Request.
        if (reset) 
        begin
        
            pending_r <= 0;
            
        end else begin
            //  When a Warp is popped from the Queue, it is no longer Pending.
            if (fpu_commit_if_valid && fpu_commit_if_ready) 
            begin
            
                pending_r[fpu_commit_if_wid] <= 0;
                
            end         
        
            //  When a Warp is pushed onto the Queue, it is Pending.
            if (fpu_req_if_valid && fpu_req_if_ready) 
            begin
            
                pending_r[fpu_req_if_wid] <= 1;
                         
            end
            
        end
        
    end
    
    assign pending = pending_r; //  Assign Pending Request.
    
    
endmodule