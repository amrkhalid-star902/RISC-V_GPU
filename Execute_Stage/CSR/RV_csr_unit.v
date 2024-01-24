`timescale 1ns / 1ps

`include "RV_define.vh"


module RV_csr_unit#(

    parameter CORE_ID = 0

)(

    input  wire clk,
    input  wire reset,

    input  wire                                    cmt_to_csr_if_valid,
    input  wire [$clog2(6*`NUM_THREADS+1)-1 : 0]   cmt_to_csr_if_commit_size,
    input  wire [(`NUM_WARPS*`NUM_THREADS)-1 : 0]  fetch_to_csr_if_thread_masks,
    input  wire                                    csr_req_if_valid,
    input  wire [`UUID_BITS-1 : 0]                 csr_req_if_uuid,
    input  wire [`NW_BITS-1 : 0]                   csr_req_if_wid,
    input  wire [`NUM_THREADS-1 : 0]               csr_req_if_tmask,
    input  wire [31 : 0]                           csr_req_if_PC,
    input  wire [`INST_CSR_BITS-1 : 0]             csr_req_if_op_type,
    input  wire [`CSR_ADDR_BITS-1 : 0]             csr_req_if_addr,
    input  wire [31 : 0]                           csr_req_if_rs1_data,
    input  wire                                    csr_req_if_use_imm,
    input  wire [`NRI_BITS-1 : 0]                  csr_req_if_imm,
    input  wire [`NR_BITS-1 : 0]                   csr_req_if_rd,
    input  wire                                    csr_req_if_wb,  
    input  wire                                    csr_commit_if_ready,

    //FPU CSR interface
    input  wire                                    fpu_to_csr_if_write_enable,
    input  wire [`NW_BITS-1 : 0]                   fpu_to_csr_if_write_wid,
    input  wire                                    fpu_to_csr_if_write_fflags_NV, // 4-Invalid
    input  wire                                    fpu_to_csr_if_write_fflags_DZ, // 3-Divide by zero
    input  wire                                    fpu_to_csr_if_write_fflags_OF, // 2-Overflow
    input  wire                                    fpu_to_csr_if_write_fflags_UF, // 1-Underflow
    input  wire                                    fpu_to_csr_if_write_fflags_NX, // 0-Inexact
    input  wire [`NW_BITS-1 : 0]                   fpu_to_csr_if_read_wid,
    input  wire [`NUM_WARPS-1 : 0]                 fpu_pending,
    input wire                                     busy,
    
    output wire                                    csr_req_if_ready,
    output wire                                    csr_commit_if_valid,
    output wire [`UUID_BITS-1 : 0]                 csr_commit_if_uuid,
    output wire [`NW_BITS-1 : 0]                   csr_commit_if_wid,
    output wire [`NUM_THREADS-1 : 0]               csr_commit_if_tmask,    
    output wire [31 : 0]                           csr_commit_if_PC,
    output wire [(`NUM_THREADS*32)-1 : 0]          csr_commit_if_data,
    output wire [`NR_BITS-1 : 0]                   csr_commit_if_rd,
    output wire                                    csr_commit_if_wb,
    output wire                                    csr_commit_if_eop,
    output wire [`INST_FRM_BITS-1 : 0]             fpu_to_csr_if_read_frm,
    output wire [`NUM_WARPS-1 : 0]                 pending


);

    wire [`NUM_THREADS-1 : 0] fetch_to_csr_if_thread_masks_2d [`NUM_WARPS-1 : 0];

    genvar m;
    generate
    
        for(m = 0 ; m < `NUM_WARPS ; m = m+1)
        begin
        
            assign fetch_to_csr_if_thread_masks_2d[m] = fetch_to_csr_if_thread_masks[`NUM_THREADS*(m+1)-1:`NUM_THREADS*m];
        
        end
    
    endgenerate
    
    wire csr_we_s1;
    wire [`CSR_ADDR_BITS-1 : 0] csr_addr_s1;    
    wire [31 : 0] csr_read_data;
    wire [31 : 0] csr_read_data_s1;
    wire [31 : 0] csr_updated_data_s1;  
    
    wire write_enable = csr_commit_if_valid && csr_we_s1;
    
    wire [31:0] csr_req_data = csr_req_if_use_imm ? {27'b0,csr_req_if_imm} : csr_req_if_rs1_data;
    
    RV_csr_data #(
    
        .CORE_ID(CORE_ID)
        
    ) csr_data (
        
        .clk            (clk),
        .reset          (reset),
        .cmt_to_csr_if_valid(cmt_to_csr_if_valid), 
        .cmt_to_csr_if_commit_size(cmt_to_csr_if_commit_size),
        .fetch_to_csr_if_thread_masks(fetch_to_csr_if_thread_masks),
        .fpu_to_csr_if_write_enable(fpu_to_csr_if_write_enable),
        .fpu_to_csr_if_write_wid(fpu_to_csr_if_write_wid),
        .fpu_to_csr_if_write_fflags_NV(fpu_to_csr_if_write_fflags_NV), // 4-Invalid
        .fpu_to_csr_if_write_fflags_DZ(fpu_to_csr_if_write_fflags_DZ), // 3-Divide by zero
        .fpu_to_csr_if_write_fflags_OF(fpu_to_csr_if_write_fflags_OF), // 2-Overflow
        .fpu_to_csr_if_write_fflags_UF(fpu_to_csr_if_write_fflags_UF), // 1-Underflow
        .fpu_to_csr_if_write_fflags_NX(fpu_to_csr_if_write_fflags_NX), // 0-Inexact
        .fpu_to_csr_if_read_wid(fpu_to_csr_if_read_wid),
        .fpu_to_csr_if_read_frm(fpu_to_csr_if_read_frm),
        .fpu_pending(fpu_pending),
        .read_enable    (csr_req_if_valid),
        .read_uuid      (csr_req_if_uuid),
        .read_addr      (csr_req_if_addr),
        .read_wid       (csr_req_if_wid),      
        .read_data      (csr_read_data),
        .write_enable   (write_enable),        
        .write_uuid     (csr_commit_if_uuid),
        .write_addr     (csr_addr_s1), 
        .write_wid      (csr_commit_if_wid),
        .write_data     (csr_updated_data_s1),
        .busy           (busy)
        
    );    
    
    wire write_hazard = (csr_addr_s1 == csr_req_if_addr)
                     && (csr_commit_if_wid == csr_req_if_wid) 
                     &&  csr_commit_if_valid;
    
    wire [31:0] csr_read_data_qual = write_hazard ? csr_updated_data_s1 : csr_read_data; 
                     
    reg [31 : 0] csr_updated_data;
    reg csr_we_s0_unqual; 
    
    
    /*
    
        *The CSRRW (Atomic Read/Write CSR) instruction atomically swaps values in the CSRs and integer registers. CSRRW reads the old value of the CSR, zero-extends the value to XLEN bits, then writes it to integer register rd. The initial value in rs1 is written to the CSR. 
        *If rd=x0, then the instruction shall not read the CSR and shall not cause any of the side effects that might occur on a CSR read.
    
    */
    
    
    /*
        *The CSRRS (Atomic Read and Set Bits in CSR) instruction reads the value of the CSR, zero-extends the value to XLEN bits, 
        *and writes it to integer register rd. The initial value in integer register rs1 is treated as a bit mask that specifies bit positions to be set in the CSR. 
        *Any bit that is high in rs1 will cause the corresponding bit to be set in the CSR, if that CSR bit is writable. Other bits in the CSR are not explicitly written.
    
    */
    
    /*
    
        *The CSRRC (Atomic Read and Clear Bits in CSR) instruction reads the value of the CSR, zero-extends the value to XLEN bits,
        *and writes it to integer register rd. The initial value in integer register rs1 is treated as a bit mask that specifies bit positions to be cleared in the CSR. 
        *Any bit that is high in rs1 will cause the corresponding bit to be cleared in the CSR, if that CSR bit is writable. 
        *Other bits in the CSR are not explicitly written.
    
    */
    

    always @(*) 
    begin 
           
        csr_we_s0_unqual = (csr_req_data != 0);
        case (csr_req_if_op_type)
            `INST_CSR_RW: begin
                csr_updated_data = csr_req_data;
                csr_we_s0_unqual = 1;
            end
            `INST_CSR_RS: begin
                csr_updated_data = csr_read_data_qual | csr_req_data;
            end
            //`INST_CSR_RC
            default: begin
                csr_updated_data = csr_read_data_qual & ~csr_req_data;
            end
        endcase
        
    end
    
    wire stall_in = fpu_pending[csr_req_if_wid];
    
    wire csr_req_valid = csr_req_if_valid && !stall_in;  

    wire stall_out = ~csr_commit_if_ready && csr_commit_if_valid;

    RV_pipe_register #(
    
        .DATAW  (1 + `UUID_BITS + `NW_BITS + `NUM_THREADS + 32 + `NR_BITS + 1 + 1 + `CSR_ADDR_BITS + 32 + 32),
        .RESETW (1)
        
    ) pipe_reg (
    
        .clk      (clk),
        .reset    (reset),
        .enable   (!stall_out),
        .data_in  ({csr_req_valid,       csr_req_if_uuid,    csr_req_if_wid,    csr_req_if_tmask,    csr_req_if_PC,    csr_req_if_rd,    csr_req_if_wb,    csr_we_s0_unqual, csr_req_if_addr, csr_read_data_qual, csr_updated_data}),
        .data_out ({csr_commit_if_valid, csr_commit_if_uuid, csr_commit_if_wid, csr_commit_if_tmask, csr_commit_if_PC, csr_commit_if_rd, csr_commit_if_wb, csr_we_s1,        csr_addr_s1,     csr_read_data_s1,   csr_updated_data_s1})
    
    );
    
    genvar i;
    generate
    
        for (i = 0 ; i < `NUM_THREADS ; i = i + 1)
        begin
        
            assign csr_commit_if_data[((i+1)*32)-1 : i*32] = (csr_addr_s1 == `CSR_WTID) ? i : (csr_addr_s1 == `CSR_LTID || csr_addr_s1 == `CSR_GTID) ?
                                                             (csr_read_data_s1 * `NUM_THREADS + i) : csr_read_data_s1;
        
        end
    
    endgenerate
    
    assign csr_commit_if_eop = 1'b1;

    // can accept new request?
    assign csr_req_if_ready = ~(stall_out || stall_in);
    
    reg [`NUM_WARPS-1:0] pending_r;
    always @(posedge clk) 
    begin
    
        if (reset) 
        begin
            pending_r <= 0;
        end else begin
        
            if (csr_commit_if_valid && csr_commit_if_ready) 
            begin
                 pending_r[csr_commit_if_wid] <= 0;
            end          
            if (csr_req_if_valid && csr_req_if_ready) 
            begin
                 pending_r[csr_req_if_wid] <= 1;
            end
            
        end
        
    end
    assign pending = pending_r;
    
    
endmodule
