`timescale 1ns / 1ps

`include "RV_define.vh"


module RV_csr_data#(

    parameter CORE_ID = 0

)(
    
    input  wire clk,
    input  wire reset,
    
    input  wire                                    cmt_to_csr_if_valid,
    input  wire [$clog2(6*`NUM_THREADS+1)-1 : 0]   cmt_to_csr_if_commit_size,
    input  wire [(`NUM_WARPS*`NUM_THREADS)-1 : 0]  fetch_to_csr_if_thread_masks,
    
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
    
    input  wire                                    read_enable,
    input  wire [`UUID_BITS-1 : 0]                 read_uuid,
    input  wire [`CSR_ADDR_BITS-1 : 0]             read_addr,
    input  wire [`NW_BITS-1 : 0]                   read_wid,
    input  wire                                    write_enable, 
    input  wire [`UUID_BITS-1 : 0]                 write_uuid,
    input  wire [`CSR_ADDR_BITS-1 : 0]             write_addr,
    input  wire [`NW_BITS-1 : 0]                   write_wid,
    input  wire [31 : 0]                           write_data, 
    input  wire                                    busy,
    
    output wire [`INST_FRM_BITS-1 : 0]             fpu_to_csr_if_read_frm,
    output wire [31 : 0]                           read_data
        
);
    
    localparam FFLAGS_BITS = 5;
    
    wire [`NUM_THREADS-1 : 0] fetch_to_csr_if_thread_masks_2d [`NUM_WARPS-1 : 0];
    
    genvar m;
    generate
    
        for(m = 0 ; m < `NUM_WARPS ; m = m+1)
        begin
        
            assign fetch_to_csr_if_thread_masks_2d[m] = fetch_to_csr_if_thread_masks[`NUM_THREADS*(m+1)-1:`NUM_THREADS*m];
        
        end
    
    endgenerate
    
    wire [4 : 0] fpu_to_csr_if_write_fflags;
    assign fpu_to_csr_if_write_fflags = {fpu_to_csr_if_write_fflags_NV, fpu_to_csr_if_write_fflags_DZ, fpu_to_csr_if_write_fflags_OF, fpu_to_csr_if_write_fflags_UF, fpu_to_csr_if_write_fflags_NX};
    
    //CSR Registers
    reg [`CSR_WIDTH-1 : 0] csr_satp;
    reg [`CSR_WIDTH-1 : 0] csr_mstatus;
    reg [`CSR_WIDTH-1 : 0] csr_medeleg;
    reg [`CSR_WIDTH-1 : 0] csr_mideleg;
    reg [`CSR_WIDTH-1 : 0] csr_mie;
    reg [`CSR_WIDTH-1 : 0] csr_mtvec;
    reg [`CSR_WIDTH-1 : 0] csr_mepc;    
    reg [`CSR_WIDTH-1 : 0] csr_pmpcfg;
    reg [`CSR_WIDTH-1 : 0] csr_pmpaddr;
    reg [63 : 0] csr_cycle;
    reg [63 : 0] csr_instret;
    
    reg [`INST_FRM_BITS+FFLAGS_BITS-1 : 0] fcsr [`NUM_WARPS-1 : 0];
    
    integer j;
    always@(posedge clk)
    begin
    
        if(reset)
        begin
                
            for(j = 0; j < `NUM_WARPS; j = j + 1)
            begin
           
                fcsr[j] <= {(`INST_FRM_BITS+FFLAGS_BITS){1'b0}};
           
            end//for
        
        end//reset
        else begin
        
            if(fpu_to_csr_if_write_enable) begin
            
                fcsr[fpu_to_csr_if_write_wid][FFLAGS_BITS-1:0] <= fcsr[fpu_to_csr_if_write_wid][FFLAGS_BITS-1:0]
                                                                 | fpu_to_csr_if_write_fflags;            
            end
            
            if(write_enable)
            begin
            
                case(write_addr)
                
                    `CSR_FFLAGS:   fcsr[write_wid][FFLAGS_BITS-1:0] <= write_data[FFLAGS_BITS-1:0];
                    `CSR_FRM:      fcsr[write_wid][`INST_FRM_BITS+FFLAGS_BITS-1:FFLAGS_BITS] <= write_data[`INST_FRM_BITS-1:0];
                    `CSR_FCSR:     fcsr[write_wid] <= write_data[FFLAGS_BITS+`INST_FRM_BITS-1:0];
                    `CSR_SATP:     csr_satp       <= write_data[`CSR_WIDTH-1:0];
                    `CSR_MSTATUS:  csr_mstatus    <= write_data[`CSR_WIDTH-1:0];
                    `CSR_MEDELEG:  csr_medeleg    <= write_data[`CSR_WIDTH-1:0];
                    `CSR_MIDELEG:  csr_mideleg    <= write_data[`CSR_WIDTH-1:0];
                    `CSR_MIE:      csr_mie        <= write_data[`CSR_WIDTH-1:0];
                    `CSR_MTVEC:    csr_mtvec      <= write_data[`CSR_WIDTH-1:0];
                    `CSR_MEPC:     csr_mepc       <= write_data[`CSR_WIDTH-1:0];
                    `CSR_PMPCFG0:  csr_pmpcfg     <= write_data[`CSR_WIDTH-1:0];
                    `CSR_PMPADDR0: csr_pmpaddr    <= write_data[`CSR_WIDTH-1:0];                   
                    default: begin end
                    
                endcase
            
            end//write_enable            
        
        end//else
    
    end//always
    
    always@(posedge clk)
    begin
    
        if(reset)
        begin
            
            csr_cycle   <= 0;
            csr_instret <= 0;
        
        end
        else begin
        
            if(busy)
            begin
            
                csr_cycle <= csr_cycle + 1;
            
            end
            else begin
            
                csr_instret <= csr_instret + cmt_to_csr_if_commit_size;
            
            end
            
        end
    
    end
    
    reg [31:0] read_data_r;
    reg read_addr_valid_r;    
    
    always@(*)
    begin
    
        read_data_r       = 0;
        read_addr_valid_r = 1;
        
        case(read_addr)
        
            `CSR_FFLAGS     : read_data_r = fcsr[read_wid][FFLAGS_BITS-1:0];
            `CSR_FRM        : read_data_r = fcsr[read_wid][`INST_FRM_BITS+FFLAGS_BITS-1:FFLAGS_BITS];
            `CSR_FCSR       : read_data_r = fcsr[read_wid];         
            `CSR_WTID       ,            
            `CSR_LTID       ,
            `CSR_LWID       : read_data_r = read_wid; 
            `CSR_GTID       ,
            `CSR_GWID       : read_data_r = CORE_ID * `NUM_WARPS + read_wid;
            `CSR_GCID       : read_data_r = CORE_ID;          
            `CSR_TMASK      : read_data_r = fetch_to_csr_if_thread_masks_2d[read_wid];
            `CSR_NT         : read_data_r = `NUM_THREADS;
            `CSR_NW         : read_data_r = `NUM_WARPS;
            `CSR_NC         : read_data_r = `NUM_CORES * `NUM_CLUSTERS;
            `CSR_MCYCLE     : read_data_r = csr_cycle[31:0];
            `CSR_MCYCLE_H   : read_data_r = csr_cycle[`PERF_CTR_BITS-1:32];
            `CSR_MINSTRET   : read_data_r = csr_instret[31:0];
            `CSR_MINSTRET_H : read_data_r = csr_instret[`PERF_CTR_BITS-1:32];
            `CSR_SATP      : read_data_r = csr_satp;
            `CSR_MSTATUS   : read_data_r = csr_mstatus;
            `CSR_MISA      : read_data_r = `ISA_CODE;
            `CSR_MEDELEG   : read_data_r = csr_medeleg;
            `CSR_MIDELEG   : read_data_r = csr_mideleg;
            `CSR_MIE       : read_data_r = csr_mie;
            `CSR_MTVEC     : read_data_r = csr_mtvec;
            `CSR_MEPC      : read_data_r = csr_mepc;
            `CSR_PMPCFG0   : read_data_r = csr_pmpcfg;
            `CSR_PMPADDR0  : read_data_r = csr_pmpaddr;
            `CSR_MVENDORID : read_data_r = `VENDOR_ID;
            `CSR_MARCHID   : read_data_r = `ARCHITECTURE_ID;
            `CSR_MIMPID    : read_data_r = `IMPLEMENTATION_ID;
            default: begin
                
                if ((read_addr >= `CSR_MPM_BASE && read_addr < (`CSR_MPM_BASE + 32))
                || (read_addr >= `CSR_MPM_BASE_H && read_addr < (`CSR_MPM_BASE_H + 32))) begin
                    read_addr_valid_r = 1;  
                end
                else begin
                
                    read_addr_valid_r = 0;
                
                end  
                
            end
            
        endcase
    
    end
    
    assign read_data = read_data_r;
    assign fpu_to_csr_if_read_frm = fcsr[fpu_to_csr_if_read_wid][`INST_FRM_BITS+FFLAGS_BITS-1:FFLAGS_BITS];
    


endmodule
