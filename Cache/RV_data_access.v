`timescale 1ns / 1ps

`include "RV_define.vh"
`include "RV_cache_define.vh"

module RV_data_access#(

    parameter CACHE_ID          = 0,
    parameter BANK_ID           = 0,
    parameter CACHE_SIZE        = 16384,
    parameter CACHE_LINE_SIZE   = 64,
    parameter NUM_BANKS         = 4,
    parameter NUM_PORTS         = 1,
    parameter WORD_SIZE         = 4,
    parameter WRITE_ENABLE      = 1,
    parameter WORD_SELECT_BITS  = `UP(`WORD_SELECT_BITS)

)(
    
    input wire clk,
    input wire reset,
    
    
    input wire                                      stall,
    input wire                                      read,
    input wire                                      fill,
    input wire                                      write,
    input wire [`LINE_ADDR_WIDTH-1:0]               addr,
    input wire [(NUM_PORTS*WORD_SELECT_BITS)-1:0]   wsel,
    input wire [NUM_PORTS-1 : 0]                    pmask,
    input wire [(NUM_PORTS*WORD_SIZE)-1 : 0]        byteen,
    input wire [(`WORDS_PER_LINE*`WORD_WIDTH)-1:0]  fill_data,
    input wire [(NUM_PORTS*`WORD_WIDTH)-1:0]        write_data,
    
    output wire [(NUM_PORTS*`WORD_WIDTH)-1:0]       read_data 
    
    
);

    //Converting flat data to 2d data
    wire [WORD_SELECT_BITS-1 : 0] wsel_arr_2d [NUM_PORTS-1 : 0];
    wire [WORD_SIZE-1 : 0] byteen_arr_2d [NUM_PORTS-1 : 0];
    wire [`WORD_WIDTH-1 : 0] write_data_arr_2d [NUM_PORTS-1 : 0];
    wire [`WORD_WIDTH-1 : 0] read_data_arr_2d [NUM_PORTS-1 : 0];
    
    localparam BYTEENW = WRITE_ENABLE ? CACHE_LINE_SIZE : 1;
    
    wire [`WORD_WIDTH-1:0] rdata [`WORDS_PER_LINE-1:0];
    wire [(`WORD_WIDTH*`WORDS_PER_LINE)-1:0] rdata_1d;
    wire [(`WORD_WIDTH*`WORDS_PER_LINE)-1:0] wdata;
    wire [BYTEENW-1:0] wren;
    
    wire [`LINE_SELECT_BITS-1:0] line_addr = addr[`LINE_SELECT_BITS-1:0];
    
    genvar j;
    generate 
    
        for(j = 0 ; j < NUM_PORTS ; j = j + 1)
        begin
        
            assign wsel_arr_2d[j]       = wsel[((j+1) * WORD_SELECT_BITS) - 1 : WORD_SELECT_BITS*j];
            assign byteen_arr_2d[j]     = byteen[((j+1) * WORD_SIZE) - 1 : WORD_SIZE*j];
            assign write_data_arr_2d[j] = write_data [((j+1) * `WORD_WIDTH) - 1 : `WORD_WIDTH*j];
            
            assign read_data[((j+1) * `WORD_WIDTH) - 1 : `WORD_WIDTH*j] = read_data_arr_2d[j];
                             
        end
    
    endgenerate
    
    generate
    
        for(j = 0 ; j < `WORDS_PER_LINE ; j = j + 1)
        begin
        
            assign rdata[j] = rdata_1d[((j+1)*`WORD_WIDTH)-1 : j*`WORD_WIDTH];
        
        end
    
    endgenerate
    
    integer i;
    
    generate
    
        if(WRITE_ENABLE)
        begin
        
            if(`WORDS_PER_LINE > 1)
            begin
           
                reg [`WORD_WIDTH-1 : 0] wdata_r [`WORDS_PER_LINE-1 : 0];
                reg [WORD_SIZE-1:0] wren_r [`WORDS_PER_LINE-1 : 0];
                
                wire [(`WORD_WIDTH*`WORDS_PER_LINE)-1 : 0] wdata_r_flat;
                wire [(WORD_SIZE*`WORDS_PER_LINE)-1 : 0] wren_r_flat;
                
                for(j = 0 ; j < `WORDS_PER_LINE ; j = j + 1)
                begin
                    
                    assign wren_r_flat[((j+1)*WORD_SIZE)-1 : WORD_SIZE*j] = wren_r[j];
                
                end
                
                if(NUM_PORTS > 1)
                begin
                
                    always@(*)
                    begin
                    
                        for(i = 0 ; i < `WORDS_PER_LINE ; i = i + 1)
                        begin
                        
                            wdata_r[i] = 0;
                            wren_r[i]  = 0;
                        
                        end//end for loop
                        
                        for(i = 0 ; i < NUM_PORTS ; i = i + 1)
                        begin
                            if(pmask[i])
                            begin
                            
                                wdata_r[wsel_arr_2d[i]] = write_data_arr_2d[i];
                                wren_r[wsel_arr_2d[i]]  = byteen_arr_2d[i];
                            
                            end
                        end//end for loop
                    
                    end//end always
                
                end//NUM_PORTS end
                else begin
                
                    //`UNUSED_VAR (pmask)
                    always@(*)
                    begin
                    
                        //A for loop is ueed to assign values as in verilog
                        //memory variables cannot be assigned directly.
                        for(i = 0 ; i < `WORDS_PER_LINE ; i = i + 1)
                        begin
                            
                            wdata_r[i] = write_data;
                            wren_r[i]  = 0;
                        
                        end            
                        
                        wren_r[wsel] = byteen;
                        
                    end
                
                end
                
                for (j=0 ; j<`WORDS_PER_LINE ; j=j+1)
                begin 
                
                    assign  wdata_r_flat[((j+1)*`WORD_WIDTH)-1 : `WORD_WIDTH*j] = wdata_r[j];
                    
                end
                
                assign wdata = write ? wdata_r_flat : fill_data;
                assign wren  = write ? wren_r_flat : {BYTEENW{fill}};
           
            end//WORDS_PER_LINE
            else begin
            
                assign wdata = write ? write_data : fill_data;
                assign wren  = write ? byteen : {BYTEENW{fill}};   
            
            end
        
        end//WRITE_ENABLE end
        else begin
        
            assign wdata = fill_data;
            assign wren  = fill;
        
        end
    
    endgenerate
    
    RV_sp_ram #(
    
        .DATAW       (`CACHE_LINE_WIDTH),
        .SIZE        (`LINES_PER_BANK),
        .BYTEENW     (BYTEENW),
        .INIT_ENABLE (1)
        
    ) data_store (
        .clk   (clk),
        .addr  (line_addr),
        .wren  (wren),
        .wdata (wdata),
        .rdata (rdata_1d)
    );
    
    generate
    
        if(`WORDS_PER_LINE > 1)
        begin
        
            for ( j = 0; j < NUM_PORTS; j= j+1) 
            begin
            
                assign read_data_arr_2d[j] = rdata[wsel_arr_2d[j]];
           
            end    
        
        end
        else begin
            
            assign read_data_arr_2d[0] = rdata[0];    
        
        end
    
    endgenerate

endmodule
