`timescale 1ns / 1ps

`include "RV_cache_define.vh"

module RV_core_rsp_merge#(

    parameter CACHE_ID          = 0,
    parameter NUM_REQS          = 1,
    parameter NUM_BANKS         = 1, 
    parameter NUM_PORTS         = 1,
    parameter WORD_SIZE         = 4,
    parameter CORE_TAG_WIDTH    = 3,  
    parameter CORE_TAG_ID_BITS  = 3,
    parameter OUT_REG           = 0

)(
    
    input wire clk,
    input wire reset,
    
    input wire [NUM_BANKS-1:0]                                per_bank_core_rsp_valid,
    input wire [NUM_BANKS*NUM_PORTS-1 : 0]                    per_bank_core_rsp_pmask,
    input wire [NUM_BANKS*NUM_PORTS*`WORD_WIDTH-1 : 0]        per_bank_core_rsp_data,
    input wire [NUM_BANKS*NUM_PORTS*`REQS_BITS-1 : 0]         per_bank_core_rsp_tid,
    input wire [NUM_BANKS*NUM_PORTS*CORE_TAG_WIDTH-1 : 0]     per_bank_core_rsp_tag,
    input wire [`CORE_RSP_TAGS-1:0]                           core_rsp_ready,
    
    output wire [NUM_BANKS-1 : 0]                             per_bank_core_rsp_ready,
    output wire [NUM_REQS-1 : 0]                              core_rsp_tmask,
    output wire [`CORE_RSP_TAGS-1 : 0]                        core_rsp_valid,
    output wire [CORE_TAG_WIDTH*`CORE_RSP_TAGS-1 : 0]         core_rsp_tag,
    output wire [NUM_REQS*`WORD_WIDTH-1 : 0]                  core_rsp_data

); 

    wire [NUM_PORTS-1 : 0]      per_bank_core_rsp_pmask_2d [NUM_BANKS-1:0];
    wire [`WORD_WIDTH-1 : 0]    per_bank_core_rsp_data_3d  [NUM_BANKS-1:0][NUM_PORTS-1:0];
    wire [`REQS_BITS-1 : 0]     per_bank_core_rsp_tid_3d   [NUM_BANKS-1:0][NUM_PORTS-1:0];
    wire [CORE_TAG_WIDTH-1 : 0] per_bank_core_rsp_tag_3d   [NUM_BANKS-1:0][NUM_PORTS-1:0];
    
    genvar m , n;
    generate
    
        for(m = 0 ; m < NUM_BANKS ; m = m + 1)
        begin
        
            assign per_bank_core_rsp_pmask_2d[m] = per_bank_core_rsp_pmask[(m+1) * NUM_PORTS-1 : m * NUM_PORTS];
        
        end
        
        for(m = 0 ; m < NUM_BANKS ; m = m + 1)
        begin
        
            for(n = 0 ; n < NUM_PORTS ; n = n + 1)
            begin
            
                assign per_bank_core_rsp_data_3d[m][n] = per_bank_core_rsp_data[(((m * NUM_PORTS) + n + 1) * `WORD_WIDTH) - 1 : (((m * NUM_PORTS) + n) * `WORD_WIDTH)];
                assign per_bank_core_rsp_tid_3d[m][n]  = per_bank_core_rsp_tid[(((m * NUM_PORTS) + n + 1) * `REQS_BITS) - 1 : (((m * NUM_PORTS) + n) * `REQS_BITS)];
                assign per_bank_core_rsp_tag_3d[m][n]  = per_bank_core_rsp_tag[(((m * NUM_PORTS) + n + 1) * CORE_TAG_WIDTH) - 1 : (((m * NUM_PORTS) + n) * CORE_TAG_WIDTH)];
            
            end
        
        end
    
    endgenerate
    
    genvar i , p;
    integer j , k;
    if(NUM_BANKS > 1)
    begin
    
        reg  [NUM_REQS-1:0]    core_rsp_valid_unqual;
        reg  [`WORD_WIDTH-1:0] core_rsp_data_unqual [NUM_REQS-1:0];
        wire [NUM_REQS*`WORD_WIDTH-1 : 0] core_rsp_data_unqual_1d;
        reg  [NUM_BANKS-1:0] per_bank_core_rsp_ready_r;
        
        if(CORE_TAG_ID_BITS != 0)
        begin
        
            wire [CORE_TAG_WIDTH-1:0] core_rsp_tag_unqual;
            wire core_rsp_ready_unqual;   
            if(NUM_PORTS > 1)
            begin
                    
                reg  [NUM_PORTS-1:0] per_bank_core_rsp_sent_r [NUM_BANKS-1:0];
                reg  [NUM_PORTS-1:0] per_bank_core_rsp_sent [NUM_BANKS-1:0];
                wire [NUM_PORTS-1:0] per_bank_core_rsp_sent_n [NUM_BANKS-1:0];
                        
                for(i = 0 ; i < NUM_BANKS ; i = i + 1)
                begin
                        
                    assign per_bank_core_rsp_sent_n[i] = per_bank_core_rsp_sent_r[i] | per_bank_core_rsp_sent[i];
                        
                end
                        
                always@(posedge clk)
                begin
                        
                    if(reset)
                    begin
                                
                        for(j = 0 ; j < NUM_BANKS ; j = j + 1)
                        begin
                                
                            per_bank_core_rsp_sent_r[j] <= 0;
                                
                        end//For
                            
                    end
                    else begin
                            
                        for(j = 0 ; j < NUM_BANKS ; j = j + 1)
                        begin
                                    
                            if (per_bank_core_rsp_sent_n[j] == per_bank_core_rsp_pmask[j])
                            begin
                                        
                                per_bank_core_rsp_sent_r[j] <= 0;
                                        
                            end
                            else begin
                                        
                                per_bank_core_rsp_sent_r[j] <= per_bank_core_rsp_sent_n[j];
                                        
                            end
                                    
                        end//For
                            
                    end
                            
                end//always
                        
                wire [NUM_PORTS-1:0] per_bank_core_rsp_valid_p [NUM_BANKS-1:0];
                wire [NUM_BANKS*NUM_PORTS-1 : 0] per_bank_core_rsp_valid_p_1d;
                        
                for (i = 0; i < NUM_BANKS; i = i + 1) 
                begin
                        
                    for (p = 0; p < NUM_PORTS; p = p + 1)
                    begin
                                    
                        assign per_bank_core_rsp_valid_p[i][p] = per_bank_core_rsp_valid[i] 
                                                              && per_bank_core_rsp_pmask_2d[i][p]
                                                              && !per_bank_core_rsp_sent_r[i][p];    
                                
                    end
                                
                    assign  per_bank_core_rsp_valid_p_1d[((i+1) * NUM_PORTS) - 1:i * NUM_PORTS]   =   per_bank_core_rsp_valid_p[i];
                            
                end//For loop
                        
                RV_find_first #(
                
                    .N     (NUM_BANKS * NUM_PORTS),
                    .DATAW (CORE_TAG_WIDTH)
                            
                ) find_first (
                
                    .valid_i (per_bank_core_rsp_valid_p_1d),
                    .data_i  (per_bank_core_rsp_tag),
                    .data_o  (core_rsp_tag_unqual),
                    .valid_o()
                );
                
                always@(*)
                begin
                
                    core_rsp_valid_unqual  = 0;
                    
                    for(j = 0 ; j < NUM_BANKS ; j = j + 1)
                    begin
                    
                        per_bank_core_rsp_sent[j] = 0;
                    
                    end
                    
                    for(j = 0 ; j < NUM_BANKS ; j = j + 1)
                    begin
                    
                        core_rsp_data_unqual[j]   = 0;
                    
                    end
                    
                    for(j = 0 ; j < NUM_BANKS ; j = j + 1)
                    begin
                    
                        for(k = 0 ; k < NUM_BANKS ; k = k + 1)
                        begin
                        
                            if(per_bank_core_rsp_valid[j]
                            && per_bank_core_rsp_pmask_2d[j][k]
                            && !per_bank_core_rsp_sent_r[j][k]
                            && (per_bank_core_rsp_tag_3d[j][k][CORE_TAG_ID_BITS-1:0]==core_rsp_tag_unqual[CORE_TAG_ID_BITS-1:0]))
                            begin
                            
                                core_rsp_valid_unqual[per_bank_core_rsp_tid_3d[j][k]] = 1;
                                core_rsp_data_unqual[per_bank_core_rsp_tid_3d[j][k]]  = per_bank_core_rsp_data_3d[j][k];
                                per_bank_core_rsp_sent[j][k]                          =  core_rsp_ready_unqual;
                            
                            end
                        
                        end//For loop
                    
                    end//For loop
                    
                    for(j = 0 ; j < NUM_BANKS ; j = j + 1)
                    begin
                    
                        per_bank_core_rsp_ready_r[j] = (per_bank_core_rsp_sent_n[j] == per_bank_core_rsp_pmask_2d[j]);
                    
                    end
                
                end//always
                           
            end//NUM_PORTS        
            else begin
                
                RV_find_first #(
                
                    .N     (NUM_BANKS),
                    .DATAW (CORE_TAG_WIDTH)
                    
                ) find_first (
                
                    .valid_i (per_bank_core_rsp_valid),
                    .data_i  (per_bank_core_rsp_tag),
                    .data_o  (core_rsp_tag_unqual),
                    .valid_o()
                    
                );  
                
                always@(*)
                begin
                    
                    core_rsp_valid_unqual     = 0; 
                    per_bank_core_rsp_ready_r = 0; 
                    
                    for(j = 0 ; j < NUM_BANKS ; j = j + 1)
                    begin
                    
                        core_rsp_data_unqual[j]   = 0;
                    
                    end 
                    
                    for(j = 0 ; j < NUM_BANKS ; j = j + 1)
                    begin
                        
                        if(per_bank_core_rsp_valid[j]
                        &&(per_bank_core_rsp_tag_3d[j][0][CORE_TAG_ID_BITS-1:0] == core_rsp_tag_unqual[CORE_TAG_ID_BITS-1:0]))
                        begin
                        
                            core_rsp_valid_unqual[per_bank_core_rsp_tid_3d[j][0]] = 1; 
                            core_rsp_data_unqual[per_bank_core_rsp_tid_3d[j][0]]  = per_bank_core_rsp_data_3d[j][0];
                            per_bank_core_rsp_ready_r[j]                          = core_rsp_ready_unqual;
                        
                        end
                    
                    end//For Loop
                
                end//always
            
            end//else 
            
            //flat the data to enter the skid buffer.
            for (i = 0; i < NUM_REQS; i = i + 1) begin
                
                assign core_rsp_data_unqual_1d[((i+1) * `WORD_WIDTH) - 1:i * `WORD_WIDTH] = core_rsp_data_unqual[i];
            
            end//for loop
            
            wire core_rsp_valid_any = (| per_bank_core_rsp_valid);
            
            RV_skid_buffer #(
            
                .DATAW    (NUM_REQS + CORE_TAG_WIDTH + (NUM_REQS *`WORD_WIDTH)),
                .PASSTHRU (0 == OUT_REG)    
                
            ) out_sbuf (
                .clk       (clk),       
                .reset     (reset),    
                .valid_in  (core_rsp_valid_any),          
                .data_in   ({core_rsp_valid_unqual, core_rsp_tag_unqual, core_rsp_data_unqual_1d}),  
                .ready_in  (core_rsp_ready_unqual), 
                .valid_out (core_rsp_valid),        
                .data_out  ({core_rsp_tmask, core_rsp_tag, core_rsp_data}), 
                .ready_out (core_rsp_ready)         
            );
        
        end//CORE_TAG_ID_BITS    
        else begin
            
            reg  [CORE_TAG_WIDTH-1 : 0] core_rsp_tag_unqual [NUM_REQS-1 : 0];
            wire [CORE_TAG_WIDTH*NUM_REQS-1 : 0] core_rsp_tag_unqual_1d;
            wire [NUM_REQS-1 : 0]       core_rsp_ready_unequal;
            
            if(NUM_PORTS > 1)
            begin
            
                reg [(`PORTS_BITS + `BANK_SELECT_BITS)-1 : 0] bank_select_table [NUM_REQS-1 : 0];
                
                reg  [NUM_PORTS-1:0] per_bank_core_rsp_sent_r [NUM_BANKS-1:0];
                reg  [NUM_PORTS-1:0] per_bank_core_rsp_sent [NUM_BANKS-1:0];
                wire [NUM_PORTS-1:0] per_bank_core_rsp_sent_n [NUM_BANKS-1:0];
                
                for(i = 0 ; i < NUM_BANKS ; i = i + 1)
                begin
                        
                    assign per_bank_core_rsp_sent_n[i] = per_bank_core_rsp_sent_r[i] | per_bank_core_rsp_sent[i];
                        
                end
                
                always@(posedge clk)
                begin
                
                    if(reset)
                    begin
                    
                        for(j = 0 ; j < NUM_BANKS ; j = j + 1)
                        begin
                                
                            per_bank_core_rsp_sent_r[j] <= 0;
                                
                        end//For
                    
                    end
                    else begin
                    
                        for(j = 0 ; j < NUM_BANKS ; j = j + 1)
                        begin
                                    
                            if (per_bank_core_rsp_sent_n[j] == per_bank_core_rsp_pmask[j])
                            begin
                                        
                                per_bank_core_rsp_sent_r[j] <= 0;
                                        
                            end
                            else begin
                                        
                                per_bank_core_rsp_sent_r[j] <= per_bank_core_rsp_sent_n[j];
                                        
                            end
                                    
                        end//For    
                    
                    end//else
                
                end//always  
                
                always@(*)
                begin
                
                    core_rsp_valid_unqual  = 0;
                
                    for(j = 0 ; j < NUM_BANKS ; j = j + 1)
                    begin
                    
                        per_bank_core_rsp_sent[j] = 0;
                    
                    end
                    
                    for(j = 0 ; j < NUM_BANKS ; j = j + 1)
                    begin
                    
                        core_rsp_data_unqual[j]   = 0;
                        core_rsp_tag_unqual[j]    = 0;
                        bank_select_table[j]      = 0;
                    
                    end
                    
                    for(j = 0 ; j < NUM_BANKS ; j = j + 1)
                    begin
                    
                        for(k = 0 ; k < NUM_BANKS ; k = k + 1)
                        begin
                        
                            if(per_bank_core_rsp_valid[j]
                            && per_bank_core_rsp_pmask_2d[j][k]
                            && !per_bank_core_rsp_sent_r[j][k])
                            begin
                            
                                core_rsp_valid_unqual[per_bank_core_rsp_tid_3d[j][k]] = 1;
                                core_rsp_data_unqual[per_bank_core_rsp_tid_3d[j][k]]  = per_bank_core_rsp_data_3d[j][k];
                                core_rsp_tag_unqual[per_bank_core_rsp_tid_3d[j][k]]   = per_bank_core_rsp_tag_3d[j][k];
                                bank_select_table[per_bank_core_rsp_tid_3d[j][k]]     = {k[`PORTS_BITS-1 : 0] , j[`BANK_SELECT_BITS-1 : 0]};
                            
                            end
                        
                        end//For loop
                    
                    end//For loop
                    
                    for(j = 0 ; j < NUM_BANKS ; j = j + 1)
                    begin
                    
                        if(core_rsp_valid_unqual[i])
                        begin
                            
                            per_bank_core_rsp_sent[bank_select_table[j][`BANK_SELECT_BITS - 1 : 0]][bank_select_table[j][`BANK_SELECT_BITS + `PORTS_BITS - 1: `BANK_SELECT_BITS]] = core_rsp_ready_unequal[j];
                        
                        end
                    
                    end
                    
                    for(j = 0 ; j < NUM_BANKS ; j = j + 1)
                    begin
                    
                        per_bank_core_rsp_ready_r[j] = (per_bank_core_rsp_sent_n[j] == per_bank_core_rsp_pmask[j]);
                    
                    end
                
                end//always   
            
            end//NUM_PORTS
            else begin
                
                reg [NUM_BANKS-1 : 0] bank_select_table [NUM_REQS-1 : 0];
                
                always@(*)
                begin
                
                    core_rsp_valid_unqual = 0; 
                    for(j = 0 ; j < NUM_BANKS ; j = j + 1)
                    begin
                    
                        core_rsp_data_unqual[j]   = 0;
                        core_rsp_tag_unqual[j]    = 0;
                        bank_select_table[j]      = 0;
                    
                    end
                    
                    for(j = 0 ; j < NUM_BANKS ; j = j + 1)
                    begin
                    
                        if (per_bank_core_rsp_valid[j]) 
                        begin
                        
                            core_rsp_valid_unqual[per_bank_core_rsp_tid_3d[j][0]] = 1;
                            core_rsp_tag_unqual[per_bank_core_rsp_tid_3d[j][0]]   = per_bank_core_rsp_tag_3d[j][0];
                            core_rsp_data_unqual[per_bank_core_rsp_tid_3d[j][0]]  = per_bank_core_rsp_data_3d[j][0];
                            bank_select_table[per_bank_core_rsp_tid_3d[j][0]]     = (1 << j);
                            
                        end
                    
                    end//For Loop
                    
                    for(j = 0 ; j < NUM_BANKS ; j = j + 1)
                    begin
                    
                         per_bank_core_rsp_ready_r[j] =  core_rsp_ready_unequal[per_bank_core_rsp_tid_3d[j][0]]
                                                      && bank_select_table[per_bank_core_rsp_tid_3d[j][0]];
                         
                    
                    end
                
                end//always
                            
            end
            
            for (i = 0; i < NUM_REQS; i = i + 1) begin
                 
                 assign core_rsp_data_unqual_1d[((i+1) * `WORD_WIDTH) - 1:i * `WORD_WIDTH]       = core_rsp_data_unqual[i];
                 assign core_rsp_tag_unqual_1d[((i+1) * CORE_TAG_WIDTH) - 1:i * CORE_TAG_WIDTH]  = core_rsp_tag_unqual[i];
             
            end//for loop
            
            for (i = 0; i < NUM_REQS; i = i + 1) 
            begin
            
                RV_skid_buffer #(
                
                    .DATAW    (CORE_TAG_WIDTH + `WORD_WIDTH),   
                    .PASSTHRU (0 == OUT_REG)   
                    
                ) out_sbuf (
                
                    .clk       (clk),       
                    .reset     (reset),     
                    .valid_in  (core_rsp_valid_unqual[i]),         
                    .data_in   ({core_rsp_tag_unqual_1d[((i+1)*CORE_TAG_WIDTH) - 1:i*CORE_TAG_WIDTH], core_rsp_data_unqual_1d[((i+1) * `WORD_WIDTH) - 1:i * `WORD_WIDTH]}), //  Data + Tag.
                    .ready_in  (core_rsp_ready_unequal[i]),     
                    .valid_out (core_rsp_valid[i]),        
                    .data_out  ({core_rsp_tag[((i+1)*CORE_TAG_WIDTH) - 1:i*CORE_TAG_WIDTH] , core_rsp_data[((i+1) * `WORD_WIDTH) - 1:i * `WORD_WIDTH]}),  
                    .ready_out (core_rsp_ready[i])         
                    
                );
                
            end//for loop
            
            assign core_rsp_tmask = core_rsp_valid;
            
        end//else
        
        assign per_bank_core_rsp_ready = per_bank_core_rsp_ready_r;  
        
    end//NUM_BANKS
    else begin
    
        if(NUM_REQS > 1)
        begin
        
            reg [CORE_TAG_WIDTH-1:0] core_rsp_tag_unqual [`CORE_RSP_TAGS-1:0]; 
            reg [`WORD_WIDTH-1:0] core_rsp_data_unqual [NUM_REQS-1:0]; 
            
            if (CORE_TAG_ID_BITS != 0)
            begin
            
                reg [NUM_REQS-1:0] core_rsp_tmask_unqual; 
                
                always@(*)
                begin
                
                    core_rsp_tmask_unqual[per_bank_core_rsp_tid] = per_bank_core_rsp_valid;
                    core_rsp_tag_unqual[0]                       = per_bank_core_rsp_tag;
                    core_rsp_data_unqual[per_bank_core_rsp_tid]  = per_bank_core_rsp_data;                    
                
                end//always
                
                assign core_rsp_valid          = per_bank_core_rsp_valid;
                assign core_rsp_tmask          = core_rsp_tmask_unqual;
                assign per_bank_core_rsp_ready = core_rsp_ready;
            
            end//CORE_TAG_ID_BITS
            else begin
            
                reg [`CORE_RSP_TAGS-1:0] core_rsp_valid_unqual;
                always@(*)
                begin
                
                    core_rsp_valid_unqual[per_bank_core_rsp_tid_3d[0][0]]   = per_bank_core_rsp_valid;
                    core_rsp_tag_unqual[per_bank_core_rsp_tid_3d[0][0]]     = per_bank_core_rsp_tag;
                    core_rsp_data_unqual[per_bank_core_rsp_tid_3d[0][0]]    = per_bank_core_rsp_data; 
                
                end//always
                
                assign core_rsp_valid = core_rsp_valid_unqual; 
                assign core_rsp_tmask = core_rsp_valid_unqual; 
                assign per_bank_core_rsp_ready = core_rsp_ready[per_bank_core_rsp_tid_3d[0][0]];
            
            end
            
            for (i = 0; i < `CORE_RSP_TAGS; i = i + 1) 
            begin
            
                assign core_rsp_tag[((i+1)*CORE_TAG_WIDTH) - 1:i*CORE_TAG_WIDTH]   = core_rsp_tag_unqual[i];    
                
            end
            
            for (i = 0; i < `CORE_RSP_TAGS; i = i + 1) 
            begin
            
                assign core_rsp_data[((i+1)*`WORD_WIDTH) - 1:i*`WORD_WIDTH]  = core_rsp_data_unqual[i];   
                        
            end
        
        end//NUM_REQS
        else begin
        
            assign core_rsp_valid = per_bank_core_rsp_valid;   
            assign core_rsp_tmask = per_bank_core_rsp_valid;    
            assign core_rsp_tag   = per_bank_core_rsp_tag;         
            assign core_rsp_data  = per_bank_core_rsp_data;     
            assign per_bank_core_rsp_ready = core_rsp_ready;    
        
        end
    
    end
    
endmodule