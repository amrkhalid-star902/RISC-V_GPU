`timescale 1ns / 1ps


module RV_dp_ram#(
    
    parameter DATAW       = 8,
    parameter SIZE        = 4,
    parameter BYTEENW     = 1,
    parameter OUT_REG     = 0,
    parameter ADDRW       = $clog2(SIZE),
    parameter INIT_ENABLE = 0,  
    parameter INIT_FILE   = "",  
    parameter [DATAW-1:0] INIT_VALUE = 0
    
    
)(
    
    input  wire                 clk,
    input  wire [BYTEENW-1 : 0] wren,
    input  wire [ADDRW-1 : 0]   waddr,
    input  wire [DATAW-1 : 0]   wdata,
    input  wire [ADDRW-1 : 0]   raddr,
    output wire [DATAW-1 : 0]   rdata

);
    
    integer k;
    `define RAM_INITIALIZATION                          \
    if (INIT_ENABLE) begin                              \
        if (INIT_FILE != "") begin                      \
            initial $readmemh(INIT_FILE, ram);          \
        end else begin                                  \
            initial                                     \
                for (k = 0; k < SIZE; k = k + 1)        \
                    ram[k] = INIT_VALUE;                \
        end                                             \
    end
    
    if(OUT_REG)
    begin
    
        reg [DATAW-1:0] rdata_r;
        if(BYTEENW > 1)
        begin
        
            reg [(BYTEENW * 8) - 1:0] ram [SIZE-1:0]; 
            `RAM_INITIALIZATION
            always@(posedge clk) 
            begin : RAM_operations
                //Writing data to memory entry
                //The writing process is done through two loops
                //where the outer loop is used to iterate over 
                //the bytes through mempry entry , while the inner
                //loop is used to assign bits within the byte
                //Nested for loop is used instead of using bounding
                //expression like [((i+1)*8)-1 : i*8] as the bounding 
                //expression requires that that boundaries must be constanr
                integer i,j;
                for(i = 0 ; i < BYTEENW; i = i + 1)
                begin
                    
                    for(j = 0 ; j < 8 ; j = j + 1)
                    begin
                    
                        if (wren[i])
                            ram[waddr][(i*8)+j] <= wdata[i * 8  + j];
                            
                    end
                    
                end//for end
                
                
                rdata_r <= ram[raddr];
            
            end//always end  
            
        end//BYTEENW end
        else begin
        
            reg [DATAW-1:0] ram [SIZE-1:0];
            `RAM_INITIALIZATION
            integer i;
            always @(posedge clk) 
            begin
                
                if(wren)
                    ram[waddr] <= wdata;
                rdata_r <= ram[raddr];
            
            end
        
        end
        
        assign rdata = rdata_r;
    
    end
    else begin
    
        if(BYTEENW > 1)
        begin
        
            reg [(BYTEENW * 8) - 1:0] ram [SIZE-1:0]; 
            `RAM_INITIALIZATION
            always@(posedge clk)
            begin : RAM_Operations1
                //Writing data to memory entry
                //The writing process is done through two loops
                //where the outer loop is used to iterate over 
                //the bytes through mempry entry , while the inner
                //loop is used to assign bits within the byte
                //Nested for loop is used instead of using bounding
                //expression like [((i+1)*8)-1 : i*8] as the bounding 
                //expression requires that that boundaries must be constanr
                integer i,j;
                for(i = 0 ; i < BYTEENW; i = i + 1)
                begin
                    for(j = 0 ; j < 8 ; j = j + 1)
                    begin
                    
                        if (wren[i])
                            ram[waddr][(i*8)+j] <= wdata[i * 8  + j];
                            
                    end
                    
                end//for end
            
            end//always end  
            
            assign rdata  = ram[raddr];
            
        end//BYTEENW end
        else begin
        
            reg [DATAW-1:0] ram [SIZE-1:0];
            `RAM_INITIALIZATION
            integer i;
            always @(posedge clk) 
            begin 
                
                if(wren)
                    ram[waddr] <= wdata;
                                
            end
            
            assign rdata  = ram[raddr];
        
        end
        
    end
    

endmodule
