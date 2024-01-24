`timescale 1ns / 1ps

`include "RV_cache_define.vh"


module RV_miss_resrv#(

    parameter CACHE_ID          = 0,
    parameter BANK_ID           = 0,
    parameter CACHE_SIZE        = 1,
    parameter CACHE_LINE_SIZE   = 1,
    parameter NUM_BANKS         = 1,
    parameter NUM_PORTS         = 1,
    parameter NUM_REQS          = 1,
    parameter WORD_SIZE         = 4,
    parameter MSHR_SIZE         = 4,
    parameter CORE_TAG_WIDTH    = 1,
    parameter MSHR_ADDR_WIDTH   = $clog2(MSHR_SIZE)

)(

    input wire clk,
    input wire reset,
    
    input wire                              allocate_valid,
    input wire [`LINE_ADDR_WIDTH-1 : 0]     allocate_addr,
    input wire [`MSHR_DATA_WIDTH-1 : 0]     allocate_data,
    
    input wire                              fill_valid,
    input wire [MSHR_ADDR_WIDTH-1 : 0]      fill_id,
    
    input wire                              lookup_valid,
    input wire                              lookup_replay,
    input wire [MSHR_ADDR_WIDTH-1 : 0]      lookup_id,
    input wire [`LINE_ADDR_WIDTH-1 : 0]     lookup_addr,
    
    input wire                              dequeue_ready,
    
    input wire                              release_valid,
    input wire [MSHR_ADDR_WIDTH-1 : 0]      release_id,
    
    
    output wire [MSHR_ADDR_WIDTH-1 : 0]     allocate_id,
    output wire                             allocate_ready,
    
    output wire [`LINE_ADDR_WIDTH-1 : 0]    fill_addr,
    output wire                             lookup_match,
    
    output wire                             dequeue_valid,
    output wire [MSHR_ADDR_WIDTH-1 : 0]     dequeue_id,
    output wire [`LINE_ADDR_WIDTH-1 : 0]    dequeue_addr,
    output wire [`MSHR_DATA_WIDTH-1 : 0]    dequeue_data
    
);

    //Table to track the addresses of each moss request
    reg [(`LINE_ADDR_WIDTH*MSHR_SIZE)-1 : 0] addr_table , addr_table_n;
    
    //Arrays to keep track of valid entries
    reg [MSHR_SIZE-1 : 0] valid_table , valid_table_n , valid_table_x;

    
    //Arrays to keep track of ready entries 
    reg [MSHR_SIZE-1 : 0] ready_table , ready_table_n , ready_table_x;
    
    //Flags to determine whether the MSHR have free entry
    reg  allocate_ready_r;
    wire allocate_ready_n;
    
    //The entry number in miss reservatio
    reg  [MSHR_ADDR_WIDTH-1 : 0] allocate_id_r ; 
    wire [MSHR_ADDR_WIDTH-1 : 0] allocate_id_n;
    
    //Keep tracking of ready entries to to be dequeued
    reg  dequeue_val_r, dequeue_val_n;
    wire dequeue_val_x;
    reg  [MSHR_ADDR_WIDTH-1:0] dequeue_id_r, dequeue_id_n;
    wire [MSHR_ADDR_WIDTH-1:0] dequeue_id_x;
    
    reg [`LINE_ADDR_WIDTH-1 : 0] fill_addr_r;
    reg [`LINE_ADDR_WIDTH-1 : 0] dequeue_addr_r;
    
    wire [MSHR_SIZE-1:0] addr_matches;
    
    wire allocate_fire = allocate_valid && allocate_ready;
    
    wire dequeue_fire  = dequeue_valid && dequeue_ready;
    
    genvar i;
    generate
    
        for(i = 0 ; i < MSHR_SIZE ; i = i + 1)
        begin
            
            assign addr_matches[i] = (addr_table[(i+1)*(`LINE_ADDR_WIDTH)-1 : i*(`LINE_ADDR_WIDTH)] == lookup_addr);
        
        end
    
    endgenerate
    
    always@(*)
    begin
    
        valid_table_x  = valid_table;
        ready_table_x  = ready_table;
        
        if(dequeue_fire)
        begin
            
            valid_table_x[dequeue_id] = 0;
        
        end
        
        if(lookup_replay)
        begin
        
             ready_table_x = ready_table_x | addr_matches;     
        
        end
    
    end
    
    // Lazy Counter module to determine next slot to be allocated
    RV_lzc #(
    
        .N (MSHR_SIZE) 
        
    ) allocate_sel (
    
        .in_i    (~valid_table_n),  
        .cnt_o   (allocate_id_n),   
        .valid_o (allocate_ready_n)  
         
    );
    
    //Lazy Counter module to determine next ready entry to be dequeued
    //The enty to be dequeued must satisify the following conditions: 
    //  1. The valid flag of the entry is active / 2.The ready flag is active
    RV_lzc #(
    
        .N (MSHR_SIZE)  
        
    ) dequeue_sel (
    
        .in_i    (valid_table_x & ready_table_x),   
        .cnt_o   (dequeue_id_x),   
        .valid_o (dequeue_val_x)   
        
    );
    
    integer j;
    always@(*)
    begin
    
        valid_table_n  = valid_table_x;
        ready_table_n  = ready_table_x;
        addr_table_n   = addr_table;
        dequeue_val_n  = dequeue_val_r;
        dequeue_id_n   = dequeue_id_r;
        
        if(dequeue_fire)
        begin
            
            dequeue_val_n = dequeue_val_x;
            dequeue_id_n  = dequeue_id_x;
        
        end 
        
        if(allocate_fire)
        begin
        
            valid_table_n[allocate_id] = 1;
            ready_table_n[allocate_id] = 0;
            
            for(j = 0 ; j < `LINE_ADDR_WIDTH ; j = j + 1)
            begin
                
                addr_table_n[allocate_id*(`LINE_ADDR_WIDTH) + j] = allocate_addr[j];
            
            end
                    
        end
        
        if(fill_valid)
        begin
            
            dequeue_val_n = 1;
            dequeue_id_n  = fill_id;
        
        end
        
        if (release_valid) 
        begin
        
            valid_table_n[release_id] = 0;  
            
        end
        
        for(j = 0 ; j < `LINE_ADDR_WIDTH ; j = j + 1)
        begin
                
            dequeue_addr_r[j] = addr_table[dequeue_id_r*(`LINE_ADDR_WIDTH) + j];
                    
        end
        
        for(j = 0 ; j < `LINE_ADDR_WIDTH ; j = j + 1)
        begin
                
            fill_addr_r[j] = addr_table[fill_id*(`LINE_ADDR_WIDTH) + j];
                    
        end
        
    
    end
    
    always@(posedge clk)
    begin
    
        if(reset)
        begin
            
            valid_table       <= 0;
            allocate_ready_r  <= 0;
            dequeue_val_r     <= 0;
         
        end
        else begin
            
            valid_table       <= valid_table_n;
            allocate_ready_r  <= allocate_ready_n;
            dequeue_val_r     <= dequeue_val_n;
        
        end
        
        ready_table   <= ready_table_n;
        addr_table    <= addr_table_n;                
        dequeue_id_r  <= dequeue_id_n;
        allocate_id_r <= allocate_id_n;
    
    end
    

    RV_dp_ram #(
    
        .DATAW  (`MSHR_DATA_WIDTH), 
        .SIZE   (MSHR_SIZE),        
        .INIT_ENABLE (1)
        
    ) entries (
    
        .clk   (clk),   
        .waddr (allocate_id_r),     
        .raddr (dequeue_id_r),      
        .wren  (allocate_valid),    
        .wdata (allocate_data),     
        .rdata (dequeue_data)       
    
    );
    
    assign fill_addr = fill_addr_r;
    
    assign allocate_ready = allocate_ready_r;
    assign allocate_id    = allocate_id_r;
    
    assign dequeue_valid  = dequeue_val_r;
    assign dequeue_id     = dequeue_id_r;
    assign dequeue_addr   = dequeue_addr_r;

    
    wire [MSHR_SIZE-1:0] lookup_entries;
    
    generate
    
        for (i = 0; i < MSHR_SIZE; i = i + 1)
        begin
        
            assign lookup_entries[i] = (i != lookup_id);
            
        end
    
    endgenerate

    assign lookup_match = |(lookup_entries & valid_table & addr_matches);
    
endmodule
