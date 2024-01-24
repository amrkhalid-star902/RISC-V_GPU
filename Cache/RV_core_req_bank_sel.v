`timescale 1ns / 1ps

`include "RV_cache_define.vh"

module RV_core_req_bank_sel#(

    parameter CACHE_ID          = 0,
    parameter CACHE_LINE_SIZE   = 64, 
    parameter WORD_SIZE         = 4,
    parameter NUM_BANKS         = 1,
    parameter NUM_PORTS         = 1,
    parameter NUM_REQS          = 1,
    parameter CORE_TAG_WIDTH    = 3,
    parameter BANK_ADDR_OFFSET  = 0

)(

    input wire clk,
    input wire reset,
    
    input wire [NUM_REQS-1 : 0]                       core_req_valid,
    input wire [NUM_REQS-1 : 0]                       core_req_rw,
    input wire [(NUM_REQS*`WORD_ADDR_WIDTH)-1 : 0]    core_req_addr,
    input wire [(NUM_REQS*WORD_SIZE)-1 : 0]           core_req_byteen,
    input wire [(NUM_REQS*`WORD_WIDTH)-1 : 0]         core_req_data,
    input wire [(NUM_REQS*CORE_TAG_WIDTH)-1 : 0]      core_req_tag,
    input wire [NUM_BANKS-1 : 0]                      per_bank_core_req_ready,
    
    output wire [NUM_REQS-1 : 0]                      core_req_ready,
    output wire [NUM_BANKS-1:0]                       per_bank_core_req_valid,
    output wire [(NUM_BANKS*NUM_PORTS)-1 : 0]         per_bank_core_req_pmask,
    output wire [NUM_BANKS-1:0]                       per_bank_core_req_rw,
    output wire [(NUM_BANKS*`LINE_ADDR_WIDTH)-1 : 0]  per_bank_core_req_addr,
    
    output wire [(NUM_BANKS*NUM_PORTS*`UP(`WORD_SELECT_BITS))-1 : 0] per_bank_core_req_wsel,
    output wire [(NUM_BANKS*NUM_PORTS*WORD_SIZE)-1 : 0]              per_bank_core_req_byteen,
    output wire [(NUM_BANKS*NUM_PORTS*`WORD_WIDTH)-1 : 0]            per_bank_core_req_data,
    output wire [(NUM_BANKS*NUM_PORTS*`REQS_BITS)-1 : 0]             per_bank_core_req_tid,
    output wire [(NUM_BANKS*NUM_PORTS*CORE_TAG_WIDTH)-1 : 0]         per_bank_core_req_tag

);

    wire [`LINE_ADDR_WIDTH-1:0] core_req_line_addr  [NUM_REQS-1:0];
    wire [`UP(`WORD_SELECT_BITS)-1:0] core_req_wsel [NUM_REQS-1:0];
    wire [`UP(`BANK_SELECT_BITS)-1:0] core_req_bid  [NUM_REQS-1:0];
    
    wire [`WORD_ADDR_WIDTH-1:0] core_req_addr_arr    [NUM_REQS-1:0];
    wire [WORD_SIZE-1:0]        core_req_byteen_arr  [NUM_REQS-1:0];
    wire [`WORD_WIDTH-1:0]      core_req_data_arr    [NUM_REQS-1:0];
    wire [CORE_TAG_WIDTH-1:0]   core_req_tag_arr     [NUM_REQS-1:0];
    
    genvar i;
    generate
    
        for(i = 0 ; i < NUM_REQS ; i = i + 1)
        begin
        
            assign core_req_addr_arr[i]   = core_req_addr[(i+1)*(`WORD_ADDR_WIDTH)-1 : i*(`WORD_ADDR_WIDTH)];
            assign core_req_byteen_arr[i] = core_req_byteen[(i+1)*(WORD_SIZE)-1 : i*(WORD_SIZE)];
            assign core_req_data_arr[i]   = core_req_data[(i+1)*(`WORD_WIDTH)-1 : i*(`WORD_WIDTH)];
            assign core_req_tag_arr[i]    = core_req_tag[(i+1)*CORE_TAG_WIDTH-1 : i*(CORE_TAG_WIDTH)];
        
        end
    
    endgenerate
    
    
    
    generate
    
        for(i = 0 ; i < NUM_REQS ; i = i + 1)
        begin
        
            if (BANK_ADDR_OFFSET == 0) 
            begin
            
                assign core_req_line_addr[i] = `SELECT_LINE_ADDR0(core_req_addr_arr[i]);
                
            
            end
            else begin
            
                assign core_req_line_addr[i] = `SELECT_LINE_ADDRX(core_req_addr_arr[i]);
            
            end
            
            assign core_req_wsel[i] = core_req_addr_arr[i][`UP(`WORD_SELECT_BITS)-1:0];
        
        end
    
    endgenerate
    
    generate
    
        for(i = 0 ; i < NUM_REQS ; i = i + 1)
        begin
            
            if(NUM_BANKS > 1)
            begin
            
                assign core_req_bid[i] = `SELECT_BANK_ID(core_req_addr_arr[i]);
            
            end
            else begin
            
                assign core_req_bid[i] = 0;
            
            end
        
        end
    
    endgenerate
    
    reg [NUM_BANKS-1:0]              per_bank_core_req_valid_r;
    reg [NUM_PORTS-1 : 0]            per_bank_core_req_pmask_r  [NUM_BANKS-1 : 0];
    reg [`UP(`WORD_SELECT_BITS)-1:0] per_bank_core_req_wsel_r   [NUM_BANKS-1:0][NUM_PORTS-1:0];
    reg [WORD_SIZE-1:0]              per_bank_core_req_byteen_r [NUM_BANKS-1:0][NUM_PORTS-1:0];
    reg [`WORD_WIDTH-1:0]            per_bank_core_req_data_r   [NUM_BANKS-1:0][NUM_PORTS-1:0];
    reg [`REQS_BITS-1:0]             per_bank_core_req_tid_r    [NUM_BANKS-1:0][NUM_PORTS-1:0];
    reg [CORE_TAG_WIDTH-1:0]         per_bank_core_req_tag_r    [NUM_BANKS-1:0][NUM_PORTS-1:0];
    reg [NUM_BANKS-1:0]              per_bank_core_req_rw_r;
    reg [`LINE_ADDR_WIDTH-1:0]       per_bank_core_req_addr_r   [NUM_BANKS-1:0];
    reg [NUM_REQS-1:0]               core_req_ready_r;
    
    integer j , k , n;
    genvar  m;
    
    if(NUM_REQS > 1)
    begin
    
        if(NUM_PORTS > 1)
        begin
        
            reg  [`LINE_ADDR_WIDTH-1:0] per_bank_line_addr_r [NUM_BANKS-1:0];
            reg  [NUM_BANKS-1:0] per_bank_rw_r;
            wire [NUM_REQS-1:0] core_req_line_match;
            
            always@(*)
            begin
                
                for(j = 0 ; j < NUM_REQS ; j = j + 1)
                begin
                    
                    if(core_req_valid[j])
                    begin
                    
                        per_bank_line_addr_r[core_req_bid[j]] = core_req_line_addr[j];
                        per_bank_rw_r[core_req_bid[j]]        = core_req_rw[j];
                    
                    end
                
                end//For Loop
            
            end//always
            
            for(m = 0 ; m < NUM_REQS ; m = m + 1)
            begin
            
                assign core_req_line_match[m] = (core_req_line_addr[m] == per_bank_line_addr_r[core_req_bid[m]]) 
                                             && (core_req_rw[m] == per_bank_rw_r[core_req_bid[m]]);
            
            end//For Loop
            
            if(NUM_PORTS < NUM_REQS)
            begin
                
                reg [NUM_REQS-1:0] req_select_table_r [NUM_BANKS-1:0][NUM_PORTS-1:0];
                
                always@(*)
                begin
                
                    for (k = 0; k < NUM_BANKS; k = k + 1)
                    begin
                    
                        per_bank_core_req_pmask_r[k] = 0;
                        per_bank_core_req_addr_r[k]  = 0;
                        
                        for(n = 0 ; n < NUM_PORTS ; n = n + 1)
                        begin
                        
                            per_bank_core_req_wsel_r[k][n]   = 0;
                            per_bank_core_req_byteen_r[k][n] = 0;
                            per_bank_core_req_data_r[k][n]   = 0;
                            per_bank_core_req_tid_r[k][n]    = 0;
                            per_bank_core_req_tag_r[k][n]    = 0;
                            req_select_table_r[k][n] = 0;  
                        
                        end//For Loop
                    
                    end//For Loop
                    
                    per_bank_core_req_valid_r = 0; 
                    per_bank_core_req_rw_r    = 0;
                    
                    for(k = NUM_REQS-1 ; k >= 0 ; k = k - 1)
                    begin
                        
                        if(core_req_valid[k])
                        begin
                       
                            per_bank_core_req_valid_r[core_req_bid[k]]                 = 1;
                            per_bank_core_req_pmask_r[core_req_bid[k]][k % NUM_PORTS]  = core_req_line_match[k];
                            per_bank_core_req_wsel_r[core_req_bid[k]][k % NUM_PORTS]   = core_req_wsel[k];
                            per_bank_core_req_byteen_r[core_req_bid[k]][k % NUM_PORTS] = core_req_byteen_arr[k];
                            per_bank_core_req_data_r[core_req_bid[k]][k % NUM_PORTS]   = core_req_data_arr[k];
                            per_bank_core_req_tid_r[core_req_bid[k]][k % NUM_PORTS]    = k[`REQS_BITS-1:0];
                            per_bank_core_req_tag_r[core_req_bid[k]][k % NUM_PORTS]    = core_req_tag_arr[k];
                            per_bank_core_req_rw_r[core_req_bid[k]]                    = core_req_rw[k];
                            per_bank_core_req_addr_r[core_req_bid[k]]                  = core_req_line_addr[k];
                            req_select_table_r[core_req_bid[k]][k % NUM_PORTS]         = (1 << k);
                       
                        end 
                    
                    end//For Loop

                    for (k = 0; k < NUM_REQS; k = k + 1)
                    begin
                    
                        core_req_ready_r[k] = per_bank_core_req_ready[core_req_bid[k]]
                                           && core_req_line_match[k]
                                           && req_select_table_r[core_req_bid[k]][k % NUM_PORTS][k];    
                    
                    end
                
                end//always 
            
            end//NUM_PORTS < NUM_REQS
            else begin
                
                always@(*)
                begin
                
                    for (k = 0; k < NUM_BANKS; k = k + 1)
                    begin
                    
                        per_bank_core_req_pmask_r[k] = 0;
                        per_bank_core_req_addr_r[k]  = 0;
                        
                        for(n = 0 ; n < NUM_PORTS ; n = n + 1)
                        begin
                        
                            per_bank_core_req_wsel_r[k][n]   = 0;
                            per_bank_core_req_byteen_r[k][n] = 0;
                            per_bank_core_req_data_r[k][n]   = 0;
                            per_bank_core_req_tid_r[k][n]    = 0;
                            per_bank_core_req_tag_r[k][n]    = 0;
                            
                        
                        end//For Loop
                    
                    end//For Loop
                    
                    per_bank_core_req_valid_r = 0; 
                    per_bank_core_req_rw_r    = 0;
                    
                    for(k = NUM_REQS-1 ; k >= 0 ; k = k - 1)
                    begin
                        
                        if(core_req_valid[k])
                        begin
                       
                            per_bank_core_req_valid_r[core_req_bid[k]]                 = 1;
                            per_bank_core_req_pmask_r[core_req_bid[k]][k % NUM_PORTS]  = core_req_line_match[k];
                            per_bank_core_req_wsel_r[core_req_bid[k]][k % NUM_PORTS]   = core_req_wsel[k];
                            per_bank_core_req_byteen_r[core_req_bid[k]][k % NUM_PORTS] = core_req_byteen_arr[k];
                            per_bank_core_req_data_r[core_req_bid[k]][k % NUM_PORTS]   = core_req_data_arr[k];
                            per_bank_core_req_tid_r[core_req_bid[k]][k % NUM_PORTS]    = k[`REQS_BITS-1:0];
                            per_bank_core_req_tag_r[core_req_bid[k]][k % NUM_PORTS]    = core_req_tag_arr[k];
                            per_bank_core_req_rw_r[core_req_bid[k]]                    = core_req_rw[k];
                            per_bank_core_req_addr_r[core_req_bid[k]]                  = core_req_line_addr[k];
                            
                       
                        end 
                    
                    end//For Loop
                    
                    for (k = 0; k < NUM_REQS; k = k + 1)
                    begin
                    
                        core_req_ready_r[k] = per_bank_core_req_ready[core_req_bid[k]]
                                           && core_req_line_match[k];
   
                    
                    end
                
                end//always 
            
            end
        
        end//NUM_PORTS
        else begin
            
            always@(*)
            begin
            
                for (k = 0; k < NUM_BANKS; k = k + 1)
                begin
                
                    per_bank_core_req_addr_r[k]  = 0;
                    
                    for(n = 0 ; n < NUM_PORTS ; n = n + 1)
                    begin
                    
                        per_bank_core_req_wsel_r[k][n]   = 0;
                        per_bank_core_req_byteen_r[k][n] = 0;
                        per_bank_core_req_data_r[k][n]   = 0;
                        per_bank_core_req_tid_r[k][n]    = 0;
                        per_bank_core_req_tag_r[k][n]    = 0;
                        
                    
                    end//For Loop
                
                end//For Loop   
                
                per_bank_core_req_valid_r = 0;
                per_bank_core_req_rw_r    = 0;
                core_req_ready_r          = 0;
                
                for(k = NUM_REQS - 1 ; k >= 0 ; k = k - 1)
                begin
                
                    if(core_req_valid[k])
                    begin
                    
                        per_bank_core_req_valid_r[core_req_bid[k]]    = 1;
                        per_bank_core_req_rw_r[core_req_bid[k]]       = core_req_rw[k];
                        per_bank_core_req_addr_r[core_req_bid[k]]     = core_req_line_addr[k];
                        per_bank_core_req_wsel_r[core_req_bid[k]][0]  = core_req_wsel[k];
                        per_bank_core_req_byteen_r[core_req_bid[k]][0]= core_req_byteen_arr[k];
                        per_bank_core_req_data_r[core_req_bid[k]][0]  = core_req_data_arr[k];
                        per_bank_core_req_tag_r[core_req_bid[k]][0]   = core_req_tag_arr[k];
                        per_bank_core_req_tid_r[core_req_bid[k]][0]   = k[`REQS_BITS-1:0];    
                        
                    end
                
                end//For Loop
                
                for(n = 0 ; n < NUM_BANKS ; n = n + 1)
                begin
                    
                    per_bank_core_req_pmask_r[n][0] = per_bank_core_req_valid_r[n];
                
                end
                
                if(NUM_BANKS > 1)
                begin
                    
                    for(k = 0 ; k < NUM_BANKS ; k = k + 1)
                    begin
                    
                        if(per_bank_core_req_valid_r[k])
                        begin
                        
                            core_req_ready_r[per_bank_core_req_tid_r[k][0]] = per_bank_core_req_ready[k];
                        
                        end
                    
                    end//For Loop  
                
                end
                else begin
                
                    core_req_ready_r[per_bank_core_req_tid_r[0][0]] = per_bank_core_req_ready;
                
                end
                
            end//always
        
        end//else
    
    end//NUM_REQS
    else begin
    
        if(NUM_BANKS > 1)
        begin
        
            always@(*)
            begin
            
                for(k = 0 ; k < NUM_BANKS ; k = k + 1)
                begin
                
                    per_bank_core_req_addr_r[k] = 0;
                    for(n = 0 ; n < NUM_PORTS ; n = n + 1)
                    begin
                    
                        per_bank_core_req_wsel_r[k][n]   = 0;
                        per_bank_core_req_byteen_r[k][n] = 0;
                        per_bank_core_req_data_r[k][n]   = 0;
                        per_bank_core_req_tid_r[k][n]    = 0;
                        per_bank_core_req_tag_r[k][n]    = 0;
                        
                    end
                
                end//For Loop
                
                per_bank_core_req_valid_r = 0;
                per_bank_core_req_rw_r    = 0;
                
                per_bank_core_req_valid_r[core_req_bid[0]]     = core_req_valid;
                per_bank_core_req_rw_r[core_req_bid[0]]        = core_req_rw;
                per_bank_core_req_addr_r[core_req_bid[0]]      = core_req_line_addr[0];
                per_bank_core_req_wsel_r[core_req_bid[0]][0]   = core_req_wsel[0];
                per_bank_core_req_byteen_r[core_req_bid[0]][0] = core_req_byteen_arr[0];
                per_bank_core_req_data_r[core_req_bid[0]][0]   = core_req_data_arr[0];
                per_bank_core_req_tag_r[core_req_bid[0]][0]    = core_req_tag_arr[0];
                per_bank_core_req_tid_r[core_req_bid[0]][0]    = 0;
                core_req_ready_r = per_bank_core_req_ready[core_req_bid[0]];
                
                for (n = 0; n < NUM_BANKS; n = n + 1) 
                begin
                
                    per_bank_core_req_pmask_r[n][0] = per_bank_core_req_valid_r[n];
                    
                end
                
            end//always
        
        end//NUM_BANKS
        else begin
        
            always @(*) 
            begin
            
                per_bank_core_req_valid_r  = core_req_valid;
                per_bank_core_req_rw_r     = core_req_rw;
                per_bank_core_req_addr_r[0]   = core_req_line_addr[0];
                per_bank_core_req_wsel_r[0][0]   = core_req_wsel[0];
                per_bank_core_req_byteen_r[0][0] = core_req_byteen_arr[0];
                per_bank_core_req_data_r[0][0]   = core_req_data_arr[0];
                per_bank_core_req_tag_r[0][0]    = core_req_tag_arr[0];
                per_bank_core_req_tid_r[0][0]    = 0;
                core_req_ready_r = per_bank_core_req_ready;
    
                per_bank_core_req_pmask_r[0][0]  = per_bank_core_req_valid_r[0];
                
            end//always
        
        end
    
    end

    
    wire [(NUM_BANKS * NUM_PORTS)-1:0]  per_bank_core_req_pmask_r_flattened;
    wire [(NUM_BANKS* NUM_PORTS * `UP(`WORD_SELECT_BITS))-1:0] per_bank_core_req_wsel_r_flattened;
    wire [(NUM_BANKS * NUM_PORTS * WORD_SIZE)-1:0]   per_bank_core_req_byteen_r_flattened;
    wire [(NUM_BANKS * NUM_PORTS * `WORD_WIDTH)-1:0] per_bank_core_req_data_r_flattened;
    wire [(NUM_BANKS * NUM_PORTS * `REQS_BITS)-1:0]  per_bank_core_req_tid_r_flattened;
    wire [(NUM_BANKS * NUM_PORTS * CORE_TAG_WIDTH)-1:0] per_bank_core_req_tag_r_flattened;
    wire [(NUM_BANKS * `LINE_ADDR_WIDTH)-1:0] per_bank_core_req_addr_r_flattened;
    
    genvar p;
    generate
    
        for (i = 0; i < NUM_BANKS; i = i + 1) 
        begin
        
            assign   per_bank_core_req_pmask_r_flattened[((i+1) * NUM_PORTS) - 1:i * NUM_PORTS] = per_bank_core_req_pmask_r[i];
            assign   per_bank_core_req_addr_r_flattened[((i+1) * `LINE_ADDR_WIDTH) - 1:i * `LINE_ADDR_WIDTH] = per_bank_core_req_addr_r[i];
    
            for (p = 0; p < NUM_PORTS; p = p + 1) 
            begin
            
                assign per_bank_core_req_wsel_r_flattened[(((i * NUM_PORTS) + p + 1) * `UP(`WORD_SELECT_BITS)) - 1 : (((i * NUM_PORTS) + p) * `UP(`WORD_SELECT_BITS))] = per_bank_core_req_wsel_r[i][p];
                assign per_bank_core_req_byteen_r_flattened[(((i * NUM_PORTS) + p + 1) * WORD_SIZE) - 1 : (((i * NUM_PORTS) + p) * WORD_SIZE)] = per_bank_core_req_byteen_r[i][p];
                assign per_bank_core_req_data_r_flattened[(((i * NUM_PORTS) + p + 1) * `WORD_WIDTH) - 1 : (((i * NUM_PORTS) + p) * `WORD_WIDTH)] = per_bank_core_req_data_r[i][p];
                assign per_bank_core_req_tid_r_flattened[(((i * NUM_PORTS) + p + 1) * `REQS_BITS) - 1 : (((i * NUM_PORTS) + p) * `REQS_BITS)] = per_bank_core_req_tid_r[i][p];
                assign per_bank_core_req_tag_r_flattened[(((i * NUM_PORTS) + p + 1) * CORE_TAG_WIDTH) - 1 : (((i * NUM_PORTS) + p) * CORE_TAG_WIDTH)] = per_bank_core_req_tag_r[i][p];
            
            end
            
        end
        
    endgenerate
    
    assign per_bank_core_req_valid  = per_bank_core_req_valid_r;
    assign per_bank_core_req_pmask  = per_bank_core_req_pmask_r_flattened;
    assign per_bank_core_req_rw     = per_bank_core_req_rw_r;
    assign per_bank_core_req_addr   = per_bank_core_req_addr_r_flattened;
    assign per_bank_core_req_wsel   = per_bank_core_req_wsel_r_flattened;
    assign per_bank_core_req_byteen = per_bank_core_req_byteen_r_flattened;
    assign per_bank_core_req_data   = per_bank_core_req_data_r_flattened;
    assign per_bank_core_req_tag    = per_bank_core_req_tag_r_flattened;
    assign per_bank_core_req_tid    = per_bank_core_req_tid_r_flattened;
    assign core_req_ready           = core_req_ready_r;
    
endmodule
