`timescale 1ns / 1ps

`include "RV_cache_define.vh"


module RV_cache#(

    parameter CACHE_ID                      = 0,
    // Number of Word requests per cycle
    parameter NUM_REQS                      = 1,
    // Size of cache in bytes
    parameter CACHE_SIZE                    = 16384, 
    // Size of line inside a bank in bytes
    parameter CACHE_LINE_SIZE               = 64, 
    // Number of banks
    parameter NUM_BANKS                     = NUM_REQS,
    // Number of ports per banks
    parameter NUM_PORTS                     = 1,
    // Size of a word in bytes
    parameter WORD_SIZE                     = 4, 
    // Core Request Queue Size
    parameter CREQ_SIZE                     = 0,
    // Core Response Queue Size
    parameter CRSQ_SIZE                     = 2,
    // Miss Reserv Queue Knob
    parameter MSHR_SIZE                     = 8, 
    // Memory Response Queue Size
    parameter MRSQ_SIZE                     = 0,
    // Memory Request Queue Size
    parameter MREQ_SIZE                     = 4,
    // Enable cache writeable
    parameter WRITE_ENABLE                  = 1,
    // core request tag size
    parameter CORE_TAG_WIDTH                = $clog2(MSHR_SIZE),
    // size of tag id in core request tag
    parameter CORE_TAG_ID_BITS              = CORE_TAG_WIDTH,
    // Memory request tag size
    parameter MEM_TAG_WIDTH                 = (32 - $clog2(CACHE_LINE_SIZE)),
    // bank offset from beginning of index range
    parameter BANK_ADDR_OFFSET              = 0,
    // enable bypass for non-cacheable addresses
    parameter NC_ENABLE                     = 0,
    parameter WORD_SELECT_BITS              = `UP(`WORD_SELECT_BITS)

)(
    
    input wire clk,
    input wire reset,
    
    input wire [NUM_REQS-1 : 0]                        core_req_valid,
    input wire [NUM_REQS-1 : 0]                        core_req_rw,
    input wire [NUM_REQS*`WORD_ADDR_WIDTH-1 : 0]       core_req_addr,
    input wire [NUM_REQS*WORD_SIZE-1 : 0]              core_req_byteen,
    input wire [NUM_REQS*`WORD_WIDTH-1 : 0]            core_req_data,
    input wire [NUM_REQS*CORE_TAG_WIDTH-1 : 0]         core_req_tag,
    input wire [`CORE_RSP_TAGS-1 : 0]                  core_rsp_ready,
    
    //Memory input signals
    input wire                                         mem_req_ready,
    input wire                                         mem_rsp_valid,
    input wire [`CACHE_LINE_WIDTH-1 : 0]               mem_rsp_data,
    input wire [MEM_TAG_WIDTH-1:0]                     mem_rsp_tag,
    
    output wire [NUM_REQS-1 : 0]                       core_req_ready,
    output wire [`CORE_RSP_TAGS-1 : 0]                 core_rsp_valid,
    output wire [NUM_REQS-1 : 0]                       core_rsp_tmask,
    output wire [NUM_REQS*`WORD_WIDTH-1 : 0]           core_rsp_data,
    output wire [CORE_TAG_WIDTH*`CORE_RSP_TAGS-1 : 0]  core_rsp_tag,
    
    //Memory output signals
    output wire                                        mem_req_valid,
    output wire                                        mem_req_rw,
    output wire [CACHE_LINE_SIZE-1 : 0]                mem_req_byteen,
    output wire [`MEM_ADDR_WIDTH-1 : 0]                mem_req_addr,
    output wire [`CACHE_LINE_WIDTH-1 : 0]              mem_req_data,
    output wire [MEM_TAG_WIDTH-1 : 0]                  mem_req_tag,
    output wire                                        mem_rsp_ready
    
);


    localparam MSHR_ADDR_WIDTH    = $clog2(MSHR_SIZE);
    localparam MEM_TAG_IN_WIDTH   = `BANK_SELECT_BITS + MSHR_ADDR_WIDTH;
    localparam CORE_TAG_X_WIDTH   = CORE_TAG_WIDTH - NC_ENABLE;
    localparam CORE_TAG_ID_X_BITS = (CORE_TAG_ID_BITS != 0) ? (CORE_TAG_ID_BITS - NC_ENABLE) : CORE_TAG_ID_BITS;
    
    //Skid Buffer Signals
    wire                             mem_req_valid_sb;
    wire                             mem_req_rw_sb;
    wire [CACHE_LINE_SIZE-1 : 0]     mem_req_byteen_sb;   
    wire [`MEM_ADDR_WIDTH-1 : 0]     mem_req_addr_sb;
    wire [`CACHE_LINE_WIDTH-1 : 0]   mem_req_data_sb;
    wire [MEM_TAG_WIDTH-1 : 0]       mem_req_tag_sb;
    wire                             mem_req_ready_sb;
    
    RV_skid_buffer #(
    
        .DATAW    (1+CACHE_LINE_SIZE+`MEM_ADDR_WIDTH+`CACHE_LINE_WIDTH+MEM_TAG_WIDTH),  
        .PASSTHRU (1 == NUM_BANKS)  
                                                           
    ) mem_req_sbuf (
    
        .clk       (clk),                     
        .reset     (reset),                  
        .valid_in  (mem_req_valid_sb),        
        .ready_in  (mem_req_ready_sb),        
        .data_in   ({mem_req_rw_sb, mem_req_byteen_sb, mem_req_addr_sb, mem_req_data_sb, mem_req_tag_sb}),   
        .data_out  ({mem_req_rw, mem_req_byteen, mem_req_addr, mem_req_data, mem_req_tag}),                  
        .valid_out (mem_req_valid),           
        .ready_out (mem_req_ready)   
                 
    );
    
    wire [`CORE_RSP_TAGS-1:0]                   core_rsp_valid_sb;
    wire [NUM_REQS-1:0]                         core_rsp_tmask_sb;
    wire [`CORE_RSP_TAGS-1:0]                   core_rsp_ready_sb;
    wire [`WORD_WIDTH-1:0]    core_rsp_data_sb  [NUM_REQS-1:0];
    wire [CORE_TAG_WIDTH-1:0] core_rsp_tag_sb   [`CORE_RSP_TAGS-1:0];
    
    //Flattened versions of data and tag signals
    wire [NUM_REQS*`WORD_WIDTH-1 : 0]          core_rsp_data_sb_1d;
    wire [CORE_TAG_WIDTH*`CORE_RSP_TAGS-1 : 0] core_rsp_tag_sb_1d;
    
    genvar x,y;
    generate
    
        for(x = 0 ; x < NUM_REQS ; x = x + 1)
        begin
        
            assign core_rsp_data_sb[x] = core_rsp_data_sb_1d[(x+1)*(`WORD_WIDTH)-1 : x*`WORD_WIDTH];
        
        end
        
        for(y = 0 ; y < `CORE_RSP_TAGS ; y = y + 1)
        begin
        
            assign core_rsp_tag_sb[y] = core_rsp_tag_sb_1d[(y+1)*(CORE_TAG_WIDTH)-1 : y*CORE_TAG_WIDTH];
        
        end
    
    endgenerate
    
    genvar i;
    generate
    
        if(CORE_TAG_ID_BITS != 0)
        begin
        
            RV_skid_buffer #(
            
                .DATAW    (NUM_REQS + NUM_REQS*`WORD_WIDTH + CORE_TAG_WIDTH),
                .PASSTHRU (1 == NUM_BANKS)
                
            ) core_rsp_sbuf (
            
                .clk       (clk),
                .reset     (reset),
                .valid_in  (core_rsp_valid_sb),        
                .ready_in  (core_rsp_ready_sb),      
                .data_in   ({core_rsp_tmask_sb, core_rsp_data_sb_1d, core_rsp_tag_sb_1d}),
                .data_out  ({core_rsp_tmask, core_rsp_data, core_rsp_tag}),        
                .valid_out (core_rsp_valid),        
                .ready_out (core_rsp_ready)
                
            );   
        
        end
        else begin
        
            for ( i = 0; i < NUM_REQS; i = i + 1) 
            begin
            
                RV_skid_buffer #(
                
                    .DATAW    (1 + `WORD_WIDTH + CORE_TAG_WIDTH),
                    .PASSTHRU (1 == NUM_BANKS)
                    
                ) core_rsp_sbuf (
                
                    .clk       (clk),
                    .reset     (reset),
                    .valid_in  (core_rsp_valid_sb[i]),        
                    .ready_in  (core_rsp_ready_sb[i]),      
                    .data_in   ({core_rsp_tmask_sb[i], core_rsp_data_sb[i], core_rsp_tag_sb[i]}),
                    .data_out  ({core_rsp_tmask[i], core_rsp_data[(i+1)*(`WORD_WIDTH)-1 : i*`WORD_WIDTH], core_rsp_tag[(i+1)*(CORE_TAG_WIDTH)-1 : i*CORE_TAG_WIDTH]}), 
                    .valid_out (core_rsp_valid[i]),        
                    .ready_out (core_rsp_ready[i])
                    
                );
            end
        
        end
    
    endgenerate
    
    wire [WORD_SIZE-1 : 0]       mem_req_byteen_p [NUM_PORTS-1 : 0];
    wire [NUM_PORTS-1 : 0]       mem_req_pmask_p;
    wire [WORD_SELECT_BITS-1:0]  mem_req_wsel_p   [NUM_PORTS-1 : 0];
    wire [`WORD_WIDTH-1 : 0]     mem_req_data_p   [NUM_PORTS-1 : 0];
    wire                         mem_req_rw_p;
    
    //Flattened version of wsel and data signals
    wire [NUM_PORTS*WORD_SELECT_BITS-1 : 0] mem_req_wsel_p_1d;
    wire [NUM_PORTS*`WORD_WIDTH-1 : 0]      mem_req_data_p_1d;
    wire [NUM_PORTS*WORD_SIZE-1 : 0]        mem_req_byteen_p_1d;
    
    genvar m;
    generate
    
        for(m = 0 ; m < NUM_PORTS ; m = m + 1)
        begin
        
            assign mem_req_wsel_p[m] = mem_req_wsel_p_1d[(m+1)*WORD_SELECT_BITS-1 : m*WORD_SELECT_BITS];
        
        end
        
        for(m = 0 ; m < NUM_PORTS ; m = m + 1)
        begin
        
            assign mem_req_data_p[m] = mem_req_data_p_1d[(m+1)*(`WORD_WIDTH)-1 : m*`WORD_WIDTH];
        
        end
        
        for(m = 0 ; m < NUM_PORTS ; m = m + 1)
        begin
        
            assign mem_req_byteen_p[m] = mem_req_byteen_p_1d[(m+1)*WORD_SIZE-1 : m*WORD_SIZE];
        
        end
    
    endgenerate
    
    integer j;
    generate
        
        if(WRITE_ENABLE)
        begin
              
              if(`WORDS_PER_LINE > 1)
              begin
              
                reg [CACHE_LINE_SIZE-1:0]   mem_req_byteen_r;
                reg [`CACHE_LINE_WIDTH-1:0] mem_req_data_r;
                
                always@(*)
                begin
                
                    mem_req_byteen_r = 0;
                    mem_req_data_r   = 0;
                    
                    for(j = 0 ; j < NUM_PORTS ; j = j + 1)
                    begin
                    
                        if((NUM_PORTS == 1) || mem_req_pmask_p[i])
                        begin
                        
                            mem_req_byteen_r[mem_req_wsel_p[j] * WORD_SIZE +: WORD_SIZE]   =  mem_req_byteen_p[j];
                            mem_req_data_r[mem_req_wsel_p[j] * `WORD_WIDTH +: `WORD_WIDTH] =  mem_req_data_p[j];
                        
                        end  
                    
                    end//For Loop
                
                end//always
                
                assign mem_req_rw_sb     = mem_req_rw_p;
                assign mem_req_byteen_sb = mem_req_byteen_r;
                assign mem_req_data_sb   = mem_req_data_r;
              
              end//WORDS_PER_LINE
              else begin
              
                assign mem_req_rw_sb     = mem_req_rw_p; 
                assign mem_req_byteen_sb = mem_req_byteen_p_1d;   
                assign mem_req_data_sb   = mem_req_data_p_1d;    
              
              end
        
        end//WRITE_ENABLE
        else begin
        
            assign mem_req_rw_sb     = 0;
            assign mem_req_byteen_sb = 0;
            assign mem_req_data_sb   = 0;
        
        end
    
    endgenerate
    
    wire [NUM_REQS-1 : 0]                      core_req_valid_c;
    wire [NUM_REQS-1:0]                        core_req_rw_c;
    wire [NUM_REQS*`WORD_ADDR_WIDTH-1:0]       core_req_addr_c;
    wire [NUM_REQS*WORD_SIZE-1:0]              core_req_byteen_c;
    wire [NUM_REQS*`WORD_WIDTH-1:0]            core_req_data_c;
    wire [NUM_REQS*CORE_TAG_X_WIDTH-1:0]       core_req_tag_c;
    wire [NUM_REQS-1:0]                        core_req_ready_c;
    
    wire [`CORE_RSP_TAGS-1:0]                  core_rsp_valid_c;
    wire [NUM_REQS-1:0]                        core_rsp_tmask_c;
    wire [NUM_REQS*`WORD_WIDTH-1:0]            core_rsp_data_c;
    wire [CORE_TAG_X_WIDTH*`CORE_RSP_TAGS-1:0] core_rsp_tag_c;
    wire [`CORE_RSP_TAGS-1:0]                  core_rsp_ready_c;
    
    wire                                       mem_req_valid_c;
    wire                                       mem_req_rw_c;
    wire [`MEM_ADDR_WIDTH-1:0]                 mem_req_addr_c;
    wire [NUM_PORTS-1:0]                       mem_req_pmask_c;
    wire [NUM_PORTS*WORD_SIZE-1:0]             mem_req_byteen_c;
    wire [NUM_PORTS*WORD_SELECT_BITS-1:0]      mem_req_wsel_c;
    wire [NUM_PORTS*`WORD_WIDTH-1:0]           mem_req_data_c;
    wire [MEM_TAG_IN_WIDTH-1:0]                mem_req_tag_c;
    wire                                       mem_req_ready_c;
    
    wire                                       mem_rsp_valid_c;
    wire [`CACHE_LINE_WIDTH-1:0]               mem_rsp_data_c;
    wire [MEM_TAG_IN_WIDTH-1:0]                mem_rsp_tag_c;
    wire                                       mem_rsp_ready_c;
    
    assign core_req_valid_c     = core_req_valid;
    assign core_req_rw_c        = core_req_rw;
    assign core_req_addr_c      = core_req_addr;
    assign core_req_byteen_c    = core_req_byteen;
    assign core_req_data_c      = core_req_data;
    assign core_req_tag_c       = core_req_tag;
    assign core_req_ready       = core_req_ready_c;
    
    assign core_rsp_valid_sb    = core_rsp_valid_c;
    assign core_rsp_tmask_sb    = core_rsp_tmask_c;
    assign core_rsp_data_sb_1d  = core_rsp_data_c;
    assign core_rsp_tag_sb_1d   = core_rsp_tag_c;
    assign core_rsp_ready_c     = core_rsp_ready_sb;

    assign mem_req_valid_sb     = mem_req_valid_c;
    assign mem_req_addr_sb      = mem_req_addr_c;
    assign mem_req_rw_p         = mem_req_rw_c;
    assign mem_req_pmask_p      = mem_req_pmask_c;
    assign mem_req_byteen_p_1d  = mem_req_byteen_c;
    assign mem_req_wsel_p_1d    = mem_req_wsel_c;
    assign mem_req_data_p_1d    = mem_req_data_c;
    assign mem_req_tag_sb       = mem_req_tag_c;
    assign mem_req_ready_c      = mem_req_ready_sb;
    
    assign mem_rsp_valid_c      = mem_rsp_valid;              
    assign mem_rsp_data_c       = mem_rsp_data;               
    assign mem_rsp_tag_c        = mem_rsp_tag;                
    assign mem_rsp_ready        = mem_rsp_ready_c;  
    
    wire [`CACHE_LINE_WIDTH-1:0] mem_rsp_data_qual;
    wire [MEM_TAG_IN_WIDTH-1:0]  mem_rsp_tag_qual;

    wire mrsq_out_valid, mrsq_out_ready;
    
    RV_elastic_buffer #(
    
        .DATAW   (MEM_TAG_IN_WIDTH + `CACHE_LINE_WIDTH), 
        .SIZE    (MRSQ_SIZE),
        .OUT_REG (MRSQ_SIZE > 2)
        
    ) mem_rsp_queue (
    
        .clk        (clk),
        .reset      (reset),
        .ready_in   (mem_rsp_ready_c),
        .valid_in   (mem_rsp_valid_c),
        .data_in    ({mem_rsp_tag_c,   mem_rsp_data_c}),                
        .data_out   ({mem_rsp_tag_qual, mem_rsp_data_qual}),
        .ready_out  (mrsq_out_ready),
        .valid_out  (mrsq_out_valid)
        
    );
    
    wire [`LINE_SELECT_BITS-1:0] flush_addr;
    wire                         flush_enable;
    
    RV_flush_ctrl #( 
    
        .CACHE_SIZE (CACHE_SIZE),
        .CACHE_LINE_SIZE (CACHE_LINE_SIZE),
        .NUM_BANKS  (NUM_BANKS)
        
    ) flush_ctrl (
    
        .clk       (clk),
        .reset     (reset),
        .addr_out  (flush_addr),
        .valid_out (flush_enable)
        
    );
    
    wire [NUM_BANKS-1:0]         per_bank_core_req_valid;
    wire [NUM_PORTS-1:0]         per_bank_core_req_pmask  [NUM_BANKS-1:0];
    wire [WORD_SELECT_BITS-1:0]  per_bank_core_req_wsel   [NUM_BANKS-1:0][NUM_PORTS-1:0];
    wire [WORD_SIZE-1:0]         per_bank_core_req_byteen [NUM_BANKS-1:0][NUM_PORTS-1:0];
    wire [`WORD_WIDTH-1:0]       per_bank_core_req_data   [NUM_BANKS-1:0][NUM_PORTS-1:0];
    wire [`REQS_BITS-1:0]        per_bank_core_req_tid    [NUM_BANKS-1:0][NUM_PORTS-1:0];
    wire [CORE_TAG_X_WIDTH-1:0]  per_bank_core_req_tag    [NUM_BANKS-1:0][NUM_PORTS-1:0];
    wire [NUM_BANKS-1:0]         per_bank_core_req_rw;  
    wire [`LINE_ADDR_WIDTH-1:0]  per_bank_core_req_addr   [NUM_BANKS-1:0];    
    wire [NUM_BANKS-1:0]         per_bank_core_req_ready;
    
    wire [NUM_BANKS-1:0]         per_bank_core_rsp_valid;
    wire [NUM_PORTS-1:0]         per_bank_core_rsp_pmask [NUM_BANKS-1:0];
    wire [`WORD_WIDTH-1:0]       per_bank_core_rsp_data  [NUM_BANKS-1:0][NUM_PORTS-1:0];
    wire [`REQS_BITS-1:0]        per_bank_core_rsp_tid   [NUM_BANKS-1:0][NUM_PORTS-1:0];
    wire [CORE_TAG_X_WIDTH-1:0]  per_bank_core_rsp_tag   [NUM_BANKS-1:0][NUM_PORTS-1:0];    
    wire [NUM_BANKS-1:0]         per_bank_core_rsp_ready;
    
    wire [NUM_BANKS-1:0]         per_bank_mem_req_valid;    
    wire [NUM_BANKS-1:0]         per_bank_mem_req_rw;
    wire [NUM_PORTS-1:0]         per_bank_mem_req_pmask  [NUM_BANKS-1:0];  
    wire [WORD_SIZE-1:0]         per_bank_mem_req_byteen [NUM_PORTS*NUM_BANKS-1:0];
    wire [WORD_SELECT_BITS-1:0]  per_bank_mem_req_wsel   [NUM_PORTS*NUM_BANKS-1:0];
    wire [`MEM_ADDR_WIDTH-1:0]   per_bank_mem_req_addr   [NUM_BANKS-1:0];
    wire [MSHR_ADDR_WIDTH-1:0]   per_bank_mem_req_id     [NUM_BANKS-1:0];
    wire [`WORD_WIDTH-1:0]       per_bank_mem_req_data   [NUM_PORTS*NUM_BANKS-1:0];
    wire [NUM_BANKS-1:0]         per_bank_mem_req_ready;
    wire [NUM_BANKS-1:0]         per_bank_mem_rsp_ready;
    
    //One-demensional version of some signals 
    wire [(NUM_PORTS*NUM_BANKS)-1:0]                  per_bank_core_req_pmask_1d;  
    wire [(WORD_SELECT_BITS*NUM_BANKS*NUM_PORTS)-1:0] per_bank_core_req_wsel_1d;   
    wire [(WORD_SIZE*NUM_BANKS*NUM_PORTS)-1:0]        per_bank_core_req_byteen_1d; 
    wire [(`WORD_WIDTH*NUM_BANKS*NUM_PORTS)-1:0]      per_bank_core_req_data_1d;   
    wire [(`REQS_BITS*NUM_BANKS*NUM_PORTS)-1:0]       per_bank_core_req_tid_1d;    
    wire [(CORE_TAG_X_WIDTH*NUM_BANKS*NUM_PORTS)-1:0] per_bank_core_req_tag_1d;   
    wire [(`LINE_ADDR_WIDTH*NUM_BANKS)-1:0]           per_bank_core_req_addr_1d;   
    wire [(NUM_PORTS*NUM_BANKS)-1:0]                  per_bank_core_rsp_pmask_1d;  
    wire [(`WORD_WIDTH*NUM_BANKS*NUM_PORTS)-1:0]      per_bank_core_rsp_data_1d;   
    wire [(`REQS_BITS*NUM_BANKS*NUM_PORTS)-1:0]       per_bank_core_rsp_tid_1d;    
    wire [(CORE_TAG_X_WIDTH*NUM_BANKS*NUM_PORTS)-1:0] per_bank_core_rsp_tag_1d;   
    
    generate
    
        for(x = 0 ; x < NUM_BANKS ; x = x + 1)
        begin
        
            assign per_bank_core_req_pmask[x] = per_bank_core_req_pmask_1d[(x+1)*NUM_PORTS-1 : x*NUM_PORTS];
            assign per_bank_core_req_addr[x]  = per_bank_core_req_addr_1d[(x+1)*(`LINE_ADDR_WIDTH)-1 : x*`LINE_ADDR_WIDTH];
            
            assign per_bank_core_rsp_pmask_1d[(x+1)*NUM_PORTS-1 : x*NUM_PORTS] =  per_bank_core_rsp_pmask[x];
            
            for(y = 0 ; y < NUM_PORTS ; y = y + 1)
            begin
            
                assign per_bank_core_req_wsel[x][y]    = per_bank_core_req_wsel_1d[(((x * NUM_PORTS) + y + 1) * WORD_SELECT_BITS) - 1 : (((x * NUM_PORTS) + y) * WORD_SELECT_BITS)];
                assign per_bank_core_req_byteen[x][y]  = per_bank_core_req_byteen_1d[(((x * NUM_PORTS) + y + 1) * WORD_SIZE) - 1 : (((x * NUM_PORTS) + y) * WORD_SIZE)];
                assign per_bank_core_req_data[x][y]    = per_bank_core_req_data_1d[(((x * NUM_PORTS) + y + 1) * `WORD_WIDTH) - 1 : (((x * NUM_PORTS) + y) * `WORD_WIDTH)]; 
                assign per_bank_core_req_tag[x][y]     = per_bank_core_req_tag_1d[(((x * NUM_PORTS) + y + 1) * CORE_TAG_X_WIDTH) - 1 : (((x * NUM_PORTS) + y) * CORE_TAG_X_WIDTH)];
                assign per_bank_core_req_tid[x][y]     = per_bank_core_req_tid_1d[(((x * NUM_PORTS) + y + 1) * `REQS_BITS) - 1 : (((x * NUM_PORTS) + y) * `REQS_BITS)];
                
                assign per_bank_core_rsp_data_1d[(((x * NUM_PORTS) + y + 1) * `WORD_WIDTH) - 1 : (((x * NUM_PORTS) + y) * `WORD_WIDTH)]           = per_bank_core_rsp_data[x][y];
                assign per_bank_core_rsp_tid_1d[(((x * NUM_PORTS) + y + 1) * `REQS_BITS) - 1 : (((x * NUM_PORTS) + y) * `REQS_BITS)]              = per_bank_core_rsp_tid[x][y];
                assign per_bank_core_rsp_tag_1d[(((x * NUM_PORTS) + y + 1) * CORE_TAG_X_WIDTH) - 1 : (((x * NUM_PORTS) + y) * CORE_TAG_X_WIDTH)]  = per_bank_core_rsp_tag[x][y];
                
            end
        
        end
    
    endgenerate
    
    if (NUM_BANKS == 1) 
    begin
    
        assign mrsq_out_ready = per_bank_mem_rsp_ready;
        
    end else 
    begin
    
        assign mrsq_out_ready = per_bank_mem_rsp_ready[`MEM_TAG_TO_BANK_ID(mem_rsp_tag_qual)];
        
    end
    
    RV_core_req_bank_sel #(
    
            .CACHE_ID        (CACHE_ID),                         
            .CACHE_LINE_SIZE (CACHE_LINE_SIZE),                  
            .NUM_BANKS       (NUM_BANKS),                        
            .NUM_PORTS       (NUM_PORTS),                        
            .WORD_SIZE       (WORD_SIZE),                        
            .NUM_REQS        (NUM_REQS),                         
            .CORE_TAG_WIDTH  (CORE_TAG_X_WIDTH),                 
            .BANK_ADDR_OFFSET(BANK_ADDR_OFFSET)                  
            
    ) core_req_bank_sel (  
              
            .clk                     (clk),                      
            .reset                   (reset),                    
            // Core request signals    
            .core_req_valid          (core_req_valid_c),                  
            .core_req_rw             (core_req_rw_c),                    
            .core_req_addr           (core_req_addr_c),                   
            .core_req_byteen         (core_req_byteen_c),                 
            .core_req_data           (core_req_data_c),                  
            .core_req_tag            (core_req_tag_c),                    
            .core_req_ready          (core_req_ready_c),                  

            .per_bank_core_req_valid (per_bank_core_req_valid),              
            .per_bank_core_req_pmask (per_bank_core_req_pmask_1d),    
            .per_bank_core_req_rw    (per_bank_core_req_rw),                 
            .per_bank_core_req_addr  (per_bank_core_req_addr_1d),     
            .per_bank_core_req_wsel  (per_bank_core_req_wsel_1d),     
            .per_bank_core_req_byteen(per_bank_core_req_byteen_1d),  
            .per_bank_core_req_data  (per_bank_core_req_data_1d),     
            .per_bank_core_req_tag   (per_bank_core_req_tag_1d),      
            .per_bank_core_req_tid   (per_bank_core_req_tid_1d),      
            .per_bank_core_req_ready (per_bank_core_req_ready)              
        
    );
        
    generate
    
        for(x = 0 ; x < NUM_BANKS ; x = x + 1)
        begin
            
            for(y = 0 ; y < NUM_PORTS ; y = y + 1)
            begin
            
                wire                          curr_bank_core_req_valid;
                wire [NUM_PORTS-1:0]          curr_bank_core_req_pmask; 
                wire                          curr_bank_core_req_rw;
                wire [`LINE_ADDR_WIDTH-1:0]   curr_bank_core_req_addr;
                wire                          curr_bank_core_req_ready; 
                wire                          curr_bank_core_rsp_valid;
                wire [NUM_PORTS-1:0]          curr_bank_core_rsp_pmask;
                wire                          curr_bank_core_rsp_ready;
                wire                          curr_bank_mem_req_valid;
                wire                          curr_bank_mem_req_rw;
                wire [NUM_PORTS-1:0]          curr_bank_mem_req_pmask;
                wire [`LINE_ADDR_WIDTH-1:0]   curr_bank_mem_req_addr;
                wire [MSHR_ADDR_WIDTH-1:0]    curr_bank_mem_req_id;
                wire                          curr_bank_mem_req_ready; 
                wire                          curr_bank_mem_rsp_valid;
                wire [MSHR_ADDR_WIDTH-1:0]    curr_bank_mem_rsp_id;
                wire [`CACHE_LINE_WIDTH-1:0]  curr_bank_mem_rsp_data; 
                wire                          curr_bank_mem_rsp_ready; 
                
                wire [WORD_SELECT_BITS-1:0]   curr_bank_core_req_wsel     [NUM_PORTS-1:0];
                wire [WORD_SIZE-1:0]          curr_bank_core_req_byteen   [NUM_PORTS-1:0];
                wire [`WORD_WIDTH-1:0]        curr_bank_core_req_data     [NUM_PORTS-1:0]; 
                wire [CORE_TAG_X_WIDTH-1:0]   curr_bank_core_req_tag      [NUM_PORTS-1:0]; 
                wire [`REQS_BITS-1:0]         curr_bank_core_req_tid      [NUM_PORTS-1:0];
                wire [`WORD_WIDTH-1:0]        curr_bank_core_rsp_data     [NUM_PORTS-1:0];
                wire [CORE_TAG_X_WIDTH-1:0]   curr_bank_core_rsp_tag      [NUM_PORTS-1:0]; 
                wire [`REQS_BITS-1:0]         curr_bank_core_rsp_tid      [NUM_PORTS-1:0];
                wire [WORD_SIZE-1:0]          curr_bank_mem_req_byteen    [NUM_PORTS-1:0]; 
                wire [WORD_SELECT_BITS-1:0]   curr_bank_mem_req_wsel      [NUM_PORTS-1:0];
                wire [`WORD_WIDTH-1:0]        curr_bank_mem_req_data      [NUM_PORTS-1:0];
                
                //Flatened versions of some signalsso they can used as output and input ports as verilog doesnot support multi-demensional ports
                wire [(WORD_SELECT_BITS*NUM_PORTS)-1:0]   curr_bank_core_req_wsel_1d;
                wire [(WORD_SIZE*NUM_PORTS)-1:0]          curr_bank_core_req_byteen_1d;
                wire [(`WORD_WIDTH*NUM_PORTS)-1:0]        curr_bank_core_req_data_1d;
                wire [(CORE_TAG_X_WIDTH*NUM_PORTS)-1:0]   curr_bank_core_req_tag_1d;
                wire [(`REQS_BITS*NUM_PORTS)-1:0]         curr_bank_core_req_tid_1d;
                
                wire [(`REQS_BITS*NUM_PORTS)-1:0]         curr_bank_core_rsp_tid_1d;
                wire [(CORE_TAG_X_WIDTH*NUM_PORTS)-1:0]   curr_bank_core_rsp_tag_1d;
                wire [(`WORD_WIDTH*NUM_PORTS)-1:0]        curr_bank_core_rsp_data_1d;
                wire [(WORD_SIZE*NUM_PORTS)-1:0]          curr_bank_mem_req_byteen_1d;
                wire [(WORD_SELECT_BITS*NUM_PORTS)-1:0]   curr_bank_mem_req_wsel_1d;
                wire [(`WORD_WIDTH*NUM_PORTS)-1:0]        curr_bank_mem_req_data_1d;
                
                assign curr_bank_core_req_valid        = per_bank_core_req_valid[x];     
                assign curr_bank_core_req_pmask        = per_bank_core_req_pmask[x];     
                assign curr_bank_core_req_addr         = per_bank_core_req_addr[x];     
                assign curr_bank_core_req_rw           = per_bank_core_req_rw[x]; 
                assign per_bank_core_req_ready[x]      = curr_bank_core_req_ready;
                assign curr_bank_core_rsp_ready        = per_bank_core_rsp_ready [x];
                assign per_bank_core_rsp_valid[x]      = curr_bank_core_rsp_valid;
                assign per_bank_core_rsp_pmask[x]      = curr_bank_core_rsp_pmask;
                assign per_bank_mem_req_valid[x]       = curr_bank_mem_req_valid;         
                assign per_bank_mem_req_rw[x]          = curr_bank_mem_req_rw;             
                assign per_bank_mem_req_pmask[x]       = curr_bank_mem_req_pmask;    
                assign per_bank_mem_req_id[x]          = curr_bank_mem_req_id; 
                assign curr_bank_mem_req_ready         = per_bank_mem_req_ready[x];
                assign per_bank_mem_rsp_ready[x]       = curr_bank_mem_rsp_ready;
            
                assign curr_bank_core_req_byteen_1d[((y+1)*WORD_SIZE)-1 : y*WORD_SIZE]             = curr_bank_core_req_byteen[y];
                assign curr_bank_core_req_wsel_1d[((y+1)*WORD_SELECT_BITS)-1 : y*WORD_SELECT_BITS] = curr_bank_core_req_wsel[y];
                assign curr_bank_core_req_data_1d[((y+1)*`WORD_WIDTH)-1 : y*`WORD_WIDTH]           = curr_bank_core_req_data[y];
                assign curr_bank_core_req_tag_1d[((y+1)*CORE_TAG_X_WIDTH)-1 : y*CORE_TAG_X_WIDTH]  = curr_bank_core_req_tag[y];
                assign curr_bank_core_req_tid_1d[((y+1)*`REQS_BITS)-1 : y*`REQS_BITS]              = curr_bank_core_req_tid[y];
                
                assign   curr_bank_core_rsp_tid  [y] = curr_bank_core_rsp_tid_1d[((y+1)*`REQS_BITS)-1 : y*`REQS_BITS];
                assign   curr_bank_core_rsp_tag  [y] = curr_bank_core_rsp_tag_1d[((y+1)*CORE_TAG_X_WIDTH)-1 : y*CORE_TAG_X_WIDTH];
                assign   curr_bank_core_rsp_data [y] = curr_bank_core_rsp_data_1d[((y+1)*`WORD_WIDTH)-1 : y*`WORD_WIDTH];
                assign   curr_bank_mem_req_byteen[y] = curr_bank_mem_req_byteen_1d[((y+1)*WORD_SIZE)-1 : y*WORD_SIZE];
                assign   curr_bank_mem_req_data  [y] = curr_bank_mem_req_data_1d[((y+1)*`WORD_WIDTH)-1 : y*`WORD_WIDTH];
                assign   curr_bank_mem_req_wsel  [y] = curr_bank_mem_req_wsel_1d[((y+1)*WORD_SELECT_BITS)-1 : y*WORD_SELECT_BITS];
                
                assign curr_bank_core_req_wsel[y]    = per_bank_core_req_wsel[x][y];  
                assign curr_bank_core_req_byteen[y]  = per_bank_core_req_byteen[x][y];  
                assign curr_bank_core_req_data[y]    = per_bank_core_req_data[x][y];  
                assign curr_bank_core_req_tag[y]     = per_bank_core_req_tag[x][y];  
                assign curr_bank_core_req_tid[y]     = per_bank_core_req_tid[x][y];
                
                assign per_bank_core_rsp_tid[x][y]   = curr_bank_core_rsp_tid[y]; 
                assign per_bank_core_rsp_tag[x][y]   = curr_bank_core_rsp_tag[y]; 
                assign per_bank_core_rsp_data[x][y]  = curr_bank_core_rsp_data[y];
                
                assign per_bank_mem_req_wsel[x][((y+1)*WORD_SELECT_BITS)-1 : y*WORD_SELECT_BITS] = curr_bank_mem_req_wsel[y];
                assign per_bank_mem_req_byteen[x][((y+1)*WORD_SIZE)-1 : y*WORD_SIZE]             = curr_bank_mem_req_byteen[y];
                assign per_bank_mem_req_data[x][((y+1)*`WORD_WIDTH)-1 : y*`WORD_WIDTH]           = curr_bank_mem_req_data[y]; 
                
                if (NUM_BANKS == 1) 
                begin 
                 
                    assign per_bank_mem_req_addr[x] = curr_bank_mem_req_addr;
                    
                end 
                else begin
                
                    assign per_bank_mem_req_addr[x] = `LINE_TO_MEM_ADDR(curr_bank_mem_req_addr , x);
                                    
                end
                
                // Memory response
                if (NUM_BANKS == 1) 
                begin
                
                    assign curr_bank_mem_rsp_valid = mrsq_out_valid;
                            
                end 
                else begin
                
                    assign curr_bank_mem_rsp_valid = mrsq_out_valid && (`MEM_TAG_TO_BANK_ID(mem_rsp_tag_qual) == x);
                
                end
                
                assign curr_bank_mem_rsp_id      = `MEM_TAG_TO_REQ_ID(mem_rsp_tag_qual);
                assign curr_bank_mem_rsp_data    = mem_rsp_data_qual;
                
                RV_bank #(        
                    
                    .BANK_ID            (x),                   
                    .CACHE_ID           (CACHE_ID),            
                    .CACHE_SIZE         (CACHE_SIZE),          
                    .CACHE_LINE_SIZE    (CACHE_LINE_SIZE),     
                    .NUM_BANKS          (NUM_BANKS),           
                    .NUM_PORTS          (NUM_PORTS),           
                    .WORD_SIZE          (WORD_SIZE),           
                    .NUM_REQS           (NUM_REQS),            
                    .CREQ_SIZE          (CREQ_SIZE),           
                    .CRSQ_SIZE          (CRSQ_SIZE),           
                    .MSHR_SIZE          (MSHR_SIZE),          
                    .MREQ_SIZE          (MREQ_SIZE),          
                    .WRITE_ENABLE       (WRITE_ENABLE),        
                    .CORE_TAG_WIDTH     (CORE_TAG_X_WIDTH),    
                    .BANK_ADDR_OFFSET   (BANK_ADDR_OFFSET)     
                    
                ) bank (
                    
                    .clk                (clk),                   
                    .reset              (reset),           
    
                               
                    // Core request
                    .core_req_valid     (curr_bank_core_req_valid),               
                    .core_req_pmask     (curr_bank_core_req_pmask),               
                    .core_req_rw        (curr_bank_core_req_rw),                  
                    .core_req_byteen    (curr_bank_core_req_byteen_1d),                 
                    .core_req_addr      (curr_bank_core_req_addr),                
                    .core_req_wsel      (curr_bank_core_req_wsel_1d),      
                    .core_req_data      (curr_bank_core_req_data_1d),      
                    .core_req_tag       (curr_bank_core_req_tag_1d),       
                    .core_req_tid       (curr_bank_core_req_tid_1d),       
                    .core_req_ready     (curr_bank_core_req_ready),               
        
                    // Core response                
                    .core_rsp_valid     (curr_bank_core_rsp_valid),             
                    .core_rsp_pmask     (curr_bank_core_rsp_pmask),             
                    .core_rsp_tid       (curr_bank_core_rsp_tid_1d),     
                    .core_rsp_data      (curr_bank_core_rsp_data_1d),    
                    .core_rsp_tag       (curr_bank_core_rsp_tag_1d),     
                    .core_rsp_ready     (curr_bank_core_rsp_ready),             
        
                    // Memory request
                    .mem_req_valid      (curr_bank_mem_req_valid),              
                    .mem_req_rw         (curr_bank_mem_req_rw),                 
                    .mem_req_pmask      (curr_bank_mem_req_pmask),              
                    .mem_req_byteen     (curr_bank_mem_req_byteen_1d),   
                    .mem_req_wsel       (curr_bank_mem_req_wsel_1d),     
                    .mem_req_addr       (curr_bank_mem_req_addr),               
                    .mem_req_id         (curr_bank_mem_req_id),                 
                    .mem_req_data       (curr_bank_mem_req_data_1d),     
                    .mem_req_ready      (curr_bank_mem_req_ready),              
                    
                    // Memory response
                    .mem_rsp_valid      (curr_bank_mem_rsp_valid),       
                    .mem_rsp_id         (curr_bank_mem_rsp_id),              
                    .mem_rsp_data       (curr_bank_mem_rsp_data),       
                    .mem_rsp_ready      (curr_bank_mem_rsp_ready),     
        
                    // flush    
                    .flush_enable       (flush_enable),                  
                    .flush_addr         (flush_addr)                    
                    
                );
                
                
            end//For Loop
           
        end//For Loop
    
    endgenerate 
    
    RV_core_rsp_merge #(
    
        .CACHE_ID           (CACHE_ID),                      
        .NUM_BANKS          (NUM_BANKS),                     
        .NUM_PORTS          (NUM_PORTS),                    
        .WORD_SIZE          (WORD_SIZE),                     
        .NUM_REQS           (NUM_REQS),                      
        .CORE_TAG_WIDTH     (CORE_TAG_X_WIDTH),                    
        .CORE_TAG_ID_BITS   (CORE_TAG_ID_X_BITS)             
        
    ) core_rsp_merge (
    
        .clk                     (clk),                                   
        .reset                   (reset),                                  
        .per_bank_core_rsp_valid (per_bank_core_rsp_valid),               
        .per_bank_core_rsp_pmask (per_bank_core_rsp_pmask_1d),      
        .per_bank_core_rsp_data  (per_bank_core_rsp_data_1d),       
        .per_bank_core_rsp_tag   (per_bank_core_rsp_tag_1d),        
        .per_bank_core_rsp_tid   (per_bank_core_rsp_tid_1d),        
        .per_bank_core_rsp_ready (per_bank_core_rsp_ready),                
        .core_rsp_valid          (core_rsp_valid_c),                       
        .core_rsp_tmask          (core_rsp_tmask_c),                       
        .core_rsp_tag            (core_rsp_tag_c),                         
        .core_rsp_data           (core_rsp_data_c),                        
        .core_rsp_ready          (core_rsp_ready_c)                       
    
    ); 
    
    wire [((`MEM_ADDR_WIDTH + MSHR_ADDR_WIDTH + 1 + NUM_PORTS * (1 + WORD_SIZE + WORD_SELECT_BITS + `WORD_WIDTH))*NUM_BANKS)-1:0] data_in_1d;
    wire [(`MEM_ADDR_WIDTH + MSHR_ADDR_WIDTH + 1 + NUM_PORTS * (1 + WORD_SIZE + WORD_SELECT_BITS + `WORD_WIDTH))-1:0] data_in [NUM_BANKS-1:0];
    
    generate
    
        for(i = 0 ; i < NUM_BANKS ; i = i + 1)
        begin
        
            assign data_in[i] = {per_bank_mem_req_addr[i], per_bank_mem_req_id[i], per_bank_mem_req_rw[i], per_bank_mem_req_pmask[i], per_bank_mem_req_byteen[i], per_bank_mem_req_wsel[i], per_bank_mem_req_data[i]};
        
        end
    
    endgenerate
    
    generate
    
        for(i = 0 ; i < NUM_BANKS ; i = i + 1)
        begin
        
            assign  data_in_1d[((i+1) *(`MEM_ADDR_WIDTH + MSHR_ADDR_WIDTH + 1 + NUM_PORTS * (1 + WORD_SIZE + WORD_SELECT_BITS + `WORD_WIDTH))) - 1:i *  (`MEM_ADDR_WIDTH + MSHR_ADDR_WIDTH + 1 + NUM_PORTS * (1 + WORD_SIZE + WORD_SELECT_BITS + `WORD_WIDTH))] = data_in[i];
        
        end
        
    endgenerate
    
    wire [MSHR_ADDR_WIDTH-1:0] mem_req_id;
    
    RV_stream_arbiter #(
    
        .NUM_REQS (NUM_BANKS),
        .DATAW    (`MEM_ADDR_WIDTH + MSHR_ADDR_WIDTH + 1 + NUM_PORTS * (1 + WORD_SIZE + WORD_SELECT_BITS + `WORD_WIDTH)),
        .TYPE     ("R")
        
    ) mem_req_arb (
    
        .clk       (clk),
        .reset     (reset),
        .valid_in  (per_bank_mem_req_valid),
        .data_in   (data_in_1d),
        .ready_in  (per_bank_mem_req_ready),   
        .valid_out (mem_req_valid_c),   
        .data_out  ({mem_req_addr_c, mem_req_id, mem_req_rw_c, mem_req_pmask_c, mem_req_byteen_c, mem_req_wsel_c, mem_req_data_c}),
        .ready_out (mem_req_ready_c)
        
    );
    
    if(NUM_BANKS == 1)
    begin
    
        assign mem_req_tag_c = mem_req_id;
    
    end
    else begin
    
        assign mem_req_tag_c = {`MEM_ADDR_TO_BANK_ID(mem_req_addr_c), mem_req_id};
    
    end

endmodule
