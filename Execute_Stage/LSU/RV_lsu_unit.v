`timescale 1ns / 1ps

`include "RV_define.vh"
`include "RV_cache_define.vh"


module RV_lsu_unit#(

    parameter CORE_ID   = 0,
    parameter NUM_REQS  = `NUM_THREADS,
    parameter WORD_SIZE = 1,
    parameter TAG_WIDTH = `DCACHE_CORE_TAG_WIDTH

)(

    input  wire clk,
    input  wire reset,
    
    //D-cache Interface
    input  wire [NUM_REQS-1 : 0]                        dc_req_ready,
    input  wire                                         dc_res_valid,
    input  wire [NUM_REQS-1 : 0]                        dc_res_tmask,
    input  wire [(`WORD_WIDTH*NUM_REQS)-1 : 0]          dc_res_data,
    input  wire [TAG_WIDTH-1 : 0]                       dc_res_tag,
    
    //LSU request interface
    input  wire                                         lsu_req_valid,
    input  wire [`UUID_BITS-1 : 0]                      lsu_req_uuid,
    input  wire [`NW_BITS-1 : 0]                        lsu_req_wid,
    input  wire [NUM_REQS-1 : 0]                        lsu_req_tmask,
    input  wire [31 : 0]                                lsu_req_PC,
    input  wire [`INST_LSU_BITS-1 : 0]                  lsu_req_op_type,
    input  wire                                         lsu_req_is_fence,
    input  wire [(NUM_REQS*32)-1 : 0]                   lsu_req_store_data,
    input  wire [(NUM_REQS*32)-1 : 0]                   lsu_req_base_addr,
    input  wire [31 : 0]                                lsu_req_offset,
    input  wire [`NR_BITS-1 : 0]                        lsu_req_rd,
    input  wire                                         lsu_req_wb,
    input  wire                                         lsu_req_is_prefetch,
    input  wire                                         ld_commit_ready,
    input  wire                                         str_commit_ready,
    
    //D-cache output interface
    output wire [NUM_REQS-1 : 0]                        dc_req_valid,
    output wire [NUM_REQS-1 : 0]                        dc_req_rw,
    output wire [(NUM_REQS*4)-1 : 0]                    dc_req_byteen,
    output wire [(NUM_REQS*`WORD_ADDR_WIDTH)-1 : 0]     dc_req_addr,
    output wire [(NUM_REQS*`WORD_WIDTH)-1 : 0]          dc_req_data,
    output wire [(NUM_REQS*TAG_WIDTH)-1 : 0]            dc_req_tag,
    output wire                                         dc_res_ready,
    output wire                                         lsu_req_ready,

    //load commit interface
    output wire                                         ld_commit_valid,
    output wire [`UUID_BITS-1 : 0]                      ld_commit_uuid,
    output wire [`NW_BITS-1 : 0]                        ld_commit_wid,
    output wire [NUM_REQS-1 : 0]                        ld_commit_tmask,
    output wire [31 : 0]                                ld_commit_PC,
    output wire [(NUM_REQS*32)-1 : 0]                   ld_commit_data,
    output wire [`NR_BITS-1 : 0]                        ld_commit_rd,
    output wire                                         ld_commit_wb,
    output wire                                         ld_commit_eop,
    
    //store commit interface
    output  wire                                        str_commit_valid,
    output  wire [`UUID_BITS-1 : 0]                     str_commit_uuid,
    output  wire [`NW_BITS-1 : 0]                       str_commit_wid,
    output  wire [NUM_REQS-1 : 0]                       str_commit_tmask,
    output  wire [31 : 0]                               str_commit_PC,
    output  wire [(NUM_REQS*32)-1 : 0]                  str_commit_data,
    output  wire [`NR_BITS-1 : 0]                       str_commit_rd,
    output  wire                                        str_commit_wb,
    output  wire                                        str_commit_eop
    
);

    localparam MEM_ASHIFT = $clog2(`MEM_BLOCK_SIZE);    
    localparam MEM_ADDRW  = 32 - MEM_ASHIFT;
    localparam REQ_ASHIFT = $clog2(`DCACHE_WORD_SIZE);  
    
    wire [31 : 0] lsu_req_base_addr_2d [NUM_REQS-1 : 0]; 

    genvar m;
    generate
        
        for(m = 0 ; m < NUM_REQS ; m = m + 1)
        begin
        
            assign lsu_req_base_addr_2d[m] = lsu_req_base_addr[((m+1)*32)-1 : m*32];
        
        end
        
    endgenerate
    
    wire                            req_valid;
    wire [`UUID_BITS-1 : 0]         req_uuid;
    wire [`NUM_THREADS-1 : 0]       req_tmask;
    wire [(`NUM_THREADS*32)-1 : 0]  req_addr;
    wire [`INST_LSU_BITS-1 : 0]     req_type;
    wire [(`NUM_THREADS*32)-1 : 0]  req_data;
    wire [`NR_BITS-1 : 0]           req_rd;
    wire                            req_wb;
    wire [`NW_BITS-1 : 0]           req_wid;
    wire [31 : 0]                   req_pc;
    wire                            req_is_dup;
    wire                            req_is_prefetch;
    wire                            memory_buf_empty;
    
    wire [`CACHE_ADDR_TYPE_BITS-1 : 0] lsu_addr_type [`NUM_THREADS-1 : 0];
    
    wire [31 : 0] full_addr [`NUM_THREADS-1 : 0];
    
    //1D version of some signals 
    wire [(`NUM_THREADS*32)-1 : 0]                      full_addr_1d;
    wire [(`CACHE_ADDR_TYPE_BITS*`NUM_THREADS)-1 : 0]   lsu_addr_type_1d;
    wire [(`CACHE_ADDR_TYPE_BITS*`NUM_THREADS)-1 : 0]   req_addr_type;
    
    generate
    
        for(m = 0 ; m < `NUM_THREADS ; m = m + 1)
        begin
        
            assign full_addr_1d[((m+1)*32)-1 : m*32]                                           = full_addr[m];
            assign lsu_addr_type_1d[((m+1)*`CACHE_ADDR_TYPE_BITS)-1 : m*`CACHE_ADDR_TYPE_BITS] = lsu_addr_type[m];
        
        end   
    
    endgenerate
    
    
    
    genvar i;
    generate
    
        for(i = 0 ; i < `NUM_THREADS ; i = i + 1)
        begin
        
            assign full_addr[i] = lsu_req_base_addr_2d[i] + lsu_req_offset;
        
        end
    
    endgenerate
    
    //Duplicate Address Detection
    wire [`NUM_THREADS-2 : 0] addr_matches;
    
    generate
    
        for(i = 0 ; i < `NUM_THREADS-1 ; i = i + 1)
        begin
            
            assign addr_matches[i] = (lsu_req_base_addr_2d[i+1] == lsu_req_base_addr_2d[0]) || ~lsu_req_tmask[i+1];
        
        end
    
    endgenerate
    
    wire lsu_is_dup = lsu_req_tmask[0] && (& addr_matches);
    
    generate
    
        for(i = 0 ; i < `NUM_THREADS ; i = i + 1)
        begin
            
            //Non-Cacheable addresses detection
            wire is_addr_nc = full_addr[i][MEM_ASHIFT +: MEM_ADDRW] >= (`IO_BASE_ADDR >> MEM_ASHIFT);
            
            //Shared memory addresses detection
            if(`SM_ENABLE)
            begin
            
                wire is_addr_sm = (full_addr[i][MEM_ASHIFT +: MEM_ADDRW] >= ((`SMEM_BASE_ADDR - `SMEM_SIZE) >> MEM_ASHIFT))
                                & (full_addr[i][MEM_ASHIFT +: MEM_ADDRW] <  (`SMEM_BASE_ADDR >> MEM_ASHIFT));
                                
                assign lsu_addr_type[i] = {is_addr_nc, is_addr_sm};
                
            end
            else begin
            
                assign lsu_addr_type[i] = is_addr_nc;
            
            end
        
        end
    
    endgenerate
    
    // fence stalls the pipeline until all pending requests are sent
    wire fence_wait = lsu_req_is_fence && (req_valid || !memory_buf_empty);
    
    wire ready_in;
    wire stall_in = ~ready_in && req_valid; 
    
    wire lsu_valid = lsu_req_valid && ~fence_wait;
    wire lsu_wb = lsu_req_wb | lsu_req_is_prefetch;
    
    RV_pipe_register #(
    
        .DATAW  (1 + 1 + 1 + `UUID_BITS + `NW_BITS + `NUM_THREADS + 32 + (`NUM_THREADS * 32) + (`NUM_THREADS * `CACHE_ADDR_TYPE_BITS) + `INST_LSU_BITS + `NR_BITS + 1 + (`NUM_THREADS * 32)),
        .RESETW (1)
        
    ) req_pipe_reg (
    
        .clk      (clk),
        .reset    (reset),
        .enable   (!stall_in),
        .data_in  ({lsu_valid, lsu_is_dup, lsu_req_is_prefetch, lsu_req_uuid, lsu_req_wid, lsu_req_tmask, lsu_req_PC, full_addr_1d, lsu_addr_type_1d, lsu_req_op_type, lsu_req_rd, lsu_wb, lsu_req_store_data}),
        .data_out ({req_valid, req_is_dup, req_is_prefetch,     req_uuid,     req_wid,     req_tmask,     req_pc,     req_addr,     req_addr_type,    req_type,        req_rd,     req_wb, req_data})
        
    );
    
    assign lsu_req_ready = ~stall_in && ~fence_wait;
    
    wire [`UUID_BITS-1 : 0]     rsp_uuid;
    wire [`NW_BITS-1 : 0]       rsp_wid;
    wire [31 : 0]               rsp_pc;
    wire [`NR_BITS-1 : 0]       rsp_rd;
    wire                        rsp_wb;
    wire [`INST_LSU_BITS-1 : 0] rsp_type;
    wire                        rsp_is_dup;
    wire                        rsp_is_prefetch;
    
    reg  [`NUM_THREADS-1 : 0] rsp_rem_mask [`LSUQ_SIZE-1 : 0];
    wire [`NUM_THREADS-1 : 0] rsp_rem_mask_n;
    wire [`NUM_THREADS-1 : 0] rsp_tmask;
    
    reg  [`NUM_THREADS-1 : 0] req_sent_mask;
    reg                       is_req_start;
    
    wire [`LSUQ_ADDR_BITS-1 : 0] mbuf_waddr, mbuf_raddr;    
    wire                         memory_buf_full;
    
    wire [REQ_ASHIFT-1 : 0] req_offset [`NUM_THREADS-1 : 0];
    
    wire [(`NUM_THREADS*REQ_ASHIFT)-1 : 0] req_offset_1d;
    wire [(`NUM_THREADS*REQ_ASHIFT)-1 : 0] rsp_offset;
    
    wire [31 : 0] req_addr_2d [`NUM_THREADS-1 : 0];
    
    generate
    
        for(m = 0 ; m < `NUM_THREADS ; m = m + 1)
        begin
        
            assign req_offset_1d[((m+1)*REQ_ASHIFT)-1 : m*REQ_ASHIFT] = req_offset[m];
        
        end   
    
    endgenerate
    
    generate
        
        for(m = 0 ; m < `NUM_THREADS ; m = m + 1)
        begin
        
            assign req_addr_2d[m] = req_addr[((m+1)*32)-1 : m*32];
        
        end
        
    endgenerate
    
    generate
    
        for(i = 0 ; i < `NUM_THREADS ; i = i + 1)
        begin
        
            assign req_offset[i] = req_addr_2d[i][1:0];
        
        end
    
    endgenerate
    
    wire [`NUM_THREADS-1:0] dcache_req_fire = dc_req_valid & dc_req_ready;
    
    wire dcache_rsp_fire = dc_res_valid && dc_res_ready;
    
    wire [`NUM_THREADS-1:0] req_tmask_dup = req_tmask & {{(`NUM_THREADS-1){~req_is_dup}} , 1'b1};
    
    wire mbuf_push = ~memory_buf_full
                   && (| ({`NUM_THREADS{req_valid}} & req_tmask_dup & dc_req_ready))
                   && is_req_start   
                   && req_wb;        
    
    
    wire mbuf_pop = dcache_rsp_fire && (0 == rsp_rem_mask_n);
    
    assign mbuf_raddr = dc_res_tag[`CACHE_ADDR_TYPE_BITS +: `LSUQ_ADDR_BITS];
    
    // do not writeback from software prefetch
    wire req_wb2 = req_wb && ~req_is_prefetch;
    
    RV_index_buffer #(
    
        .DATAW (`UUID_BITS + `NW_BITS + 32 + `NUM_THREADS + `NR_BITS + 1 + `INST_LSU_BITS + (`NUM_THREADS * REQ_ASHIFT) + 1 + 1),
        .SIZE  (`LSUQ_SIZE)
        
    ) req_metadata (
    
        .clk          (clk),
        .reset        (reset),
        .write_addr   (mbuf_waddr),  
        .acquire_slot (mbuf_push),       
        .read_addr    (mbuf_raddr),
        .write_data   ({req_uuid, req_wid, req_pc, req_tmask, req_rd, req_wb2, req_type, req_offset_1d, req_is_dup, req_is_prefetch}),                    
        .read_data    ({rsp_uuid, rsp_wid, rsp_pc, rsp_tmask, rsp_rd, rsp_wb,  rsp_type, rsp_offset,    rsp_is_dup, rsp_is_prefetch}),
        .release_addr (mbuf_raddr),
        .release_slot (mbuf_pop),     
        .full         (memory_buf_full),
        .empty        (memory_buf_empty)
        
    ); 
    
    wire dcache_req_ready = &(dc_req_ready | req_sent_mask | ~req_tmask_dup);
    
    wire [`NUM_THREADS-1:0] req_sent_mask_n = req_sent_mask | dcache_req_fire;
    
    always @(posedge clk) 
    begin
    
        if (reset) 
        begin
            req_sent_mask <= 0;
            is_req_start  <= 1;
        end else begin
            if (dcache_req_ready) 
            begin
                req_sent_mask <= 0;
                is_req_start  <= 1;
            end else begin
                req_sent_mask <= req_sent_mask_n;
                is_req_start  <= (0 == req_sent_mask_n);
            end
        end
        
    end
    
    reg [`LSUQ_ADDR_BITS-1:0] req_tag_hold;
    
    wire [`LSUQ_ADDR_BITS-1:0] req_tag = is_req_start ? mbuf_waddr : req_tag_hold;
    
    always @(posedge clk) 
    begin
    
        if (mbuf_push) 
        begin            
            req_tag_hold <= mbuf_waddr;
        end
        
    end 
    
    assign rsp_rem_mask_n = rsp_rem_mask[mbuf_raddr] & ~dc_res_tmask;
    
    always @(posedge clk) 
    begin
    
        if (mbuf_push)  
        begin
            rsp_rem_mask[mbuf_waddr] <= req_tmask_dup;
        end    
        if (dcache_rsp_fire) 
        begin
            rsp_rem_mask[mbuf_raddr] <= rsp_rem_mask_n;
        end
        
    end
    
    // ensure all dependencies for the requests are resolved
    wire req_dep_ready = (req_wb && ~(memory_buf_full && is_req_start))
                      || (~req_wb && str_commit_ready);    
    
    
    wire [31 : 0]          req_data_2d   [`NUM_THREADS-1 : 0];
    wire [REQ_ASHIFT-1:0]  rsp_offset_2d [`NUM_THREADS-1 : 0];
    
    generate
        
        for(m = 0 ; m < `NUM_THREADS ; m = m + 1)
        begin
        
            assign req_data_2d[m]   = req_data[((m+1)*32)-1 : m*32];
            assign rsp_offset_2d[m] = rsp_offset[((m+1)*REQ_ASHIFT)-1 : m*REQ_ASHIFT];
            
        end
        
    endgenerate
    
    
    generate
    
        for(i = 0 ; i < `NUM_THREADS ; i = i + 1)
        begin
        
            reg [3 : 0]  mem_req_byteen;  
            reg [31 : 0] mem_req_data;
            
            always@(*)
            begin
            
                mem_req_byteen = {4{req_wb}};
                case(`INST_LSU_WSIZE(req_type))
                
                    0: mem_req_byteen[req_offset[i]] = 1;
                    1: begin
                    
                        mem_req_byteen[req_offset[i]] = 1;
                        mem_req_byteen[{req_offset[i][1], 1'b1}] = 1;
                    
                    end
                    
                    default: mem_req_byteen = {4{1'b1}};
                
                endcase
            
            end
            
            always @(*) 
            begin
            
                mem_req_data = req_data_2d[i];
                case (req_offset[i])
                    1: mem_req_data[31:8]  = req_data_2d[i][23:0];
                    2: mem_req_data[31:16] = req_data_2d[i][15:0];
                    3: mem_req_data[31:24] = req_data_2d[i][7:0];
                    default: begin end
                endcase
                
            end
            
            assign dc_req_valid[i]  = req_valid && req_dep_ready && req_tmask_dup[i] && !req_sent_mask[i];
            assign dc_req_rw[i]     = ~req_wb;
            assign dc_req_addr[((i+1)*`WORD_ADDR_WIDTH)-1 : i*`WORD_ADDR_WIDTH]   = req_addr_2d[i][31:2];
            assign dc_req_byteen[((i+1)*4)-1 : i*4]                               = mem_req_byteen;
            assign dc_req_data[((i+1)*`WORD_WIDTH)-1 : i*`WORD_WIDTH]             = mem_req_data;
            assign dc_req_tag[((i+1)*TAG_WIDTH)-1 : i*TAG_WIDTH]                  = {req_uuid, req_tag, req_addr_type[i]};
        
        end
    
    endgenerate
    
    assign ready_in = req_dep_ready && dcache_req_ready;
    
    wire is_store_rsp = req_valid && ~req_wb && dcache_req_ready;

    assign str_commit_valid = is_store_rsp;
    assign str_commit_uuid  = req_uuid;
    assign str_commit_wid   = req_wid;
    assign str_commit_tmask = req_tmask;
    assign str_commit_PC    = req_pc;
    assign str_commit_rd    = 0;
    assign str_commit_wb    = 0;
    assign str_commit_eop   = 1'b1;
    assign str_commit_data  = 0;
    
    
    reg  [31:0] rsp_data[`NUM_THREADS-1:0];
    wire [`NUM_THREADS-1:0] rsp_tmask_qual;
    
    
    
    generate
    
        for(i = 0 ; i < `NUM_THREADS ; i = i + 1)
        begin
            
            wire [31 : 0] rsp_data32 = (i == 0 || rsp_is_dup) ? dc_res_data[`WORD_WIDTH-1 : 0] : dc_res_data[((i+1)*`WORD_WIDTH)-1 : i*`WORD_WIDTH];
            wire [15:0] rsp_data16   = rsp_offset_2d[i][1] ? rsp_data32[31:16] : rsp_data32[15:0];
            wire [7:0]  rsp_data8    = rsp_offset_2d[i][0] ? rsp_data16[15:8] : rsp_data16[7:0];
            
            always@(*)
            begin
            
                case (`INST_LSU_FMT(rsp_type))
                
                     `INST_FMT_B:  rsp_data[i] = $signed(rsp_data8);
                     `INST_FMT_H:  rsp_data[i] = $signed(rsp_data16);
                     `INST_FMT_BU: rsp_data[i] = $unsigned(rsp_data8);
                     `INST_FMT_HU: rsp_data[i] = $unsigned(rsp_data16);
                     default: rsp_data[i] = rsp_data32;
                     
                endcase
            
            end
            
        end
    
    endgenerate
    
    assign rsp_tmask_qual = rsp_is_dup ? rsp_tmask : dc_res_tmask;
    wire load_rsp_stall = ~ld_commit_ready && ld_commit_valid;
    
    wire [(`NUM_THREADS*32)-1 : 0] rsp_data_1d;
    
    generate
    
        for(m = 0 ; m < `NUM_THREADS ; m = m + 1)
        begin
        
            assign rsp_data_1d[((m+1)*32)-1 : m*32] = rsp_data[m];
        
        end   
    
    endgenerate
    
    RV_pipe_register #(
    
        .DATAW  (1 + `UUID_BITS + `NW_BITS + `NUM_THREADS + 32 + `NR_BITS + 1 + (`NUM_THREADS * 32) + 1),
        .RESETW (1)
        
    ) rsp_pipe_reg (
        .clk      (clk),
        .reset    (reset),
        .enable   (!load_rsp_stall),
        .data_in  ({dc_res_valid,    rsp_uuid,       rsp_wid,       rsp_tmask_qual,  rsp_pc,       rsp_rd,       rsp_wb,       rsp_data_1d,    mbuf_pop}),
        .data_out ({ld_commit_valid, ld_commit_uuid, ld_commit_wid, ld_commit_tmask, ld_commit_PC, ld_commit_rd, ld_commit_wb, ld_commit_data, ld_commit_eop})
    );
    
    assign dc_res_ready = ~load_rsp_stall;
        
endmodule
