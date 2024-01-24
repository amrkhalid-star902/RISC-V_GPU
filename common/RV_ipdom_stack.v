`timescale 1ns / 1ps


module RV_ipdom_stack#(

    parameter WIDTH = 8,
    parameter DEPTH = 4

)(

    input  wire clk,
    input  wire reset,
    
    input  wire                pair,
    input  wire [WIDTH-1 : 0]  q1,
    input  wire [WIDTH-1 : 0]  q2,
    input  wire                push,
    input  wire                pop,
    output wire                index,
    output wire                empty,
    output wire                full,
    output wire [WIDTH - 1:0]  d

);

    localparam ADDRW = $clog2(DEPTH);

    reg  is_part [DEPTH-1:0];
    reg  [ADDRW-1:0] rd_ptr, wr_ptr;
    wire [WIDTH-1:0] d1, d2;
    
    always@(posedge clk)
    begin
    
        if(reset)
        begin
        
            rd_ptr <= 0;
            wr_ptr <= 0;
        
        end
        else begin
        
            if(push)
            begin
            
                rd_ptr <= wr_ptr;
                wr_ptr <= wr_ptr + 1;
            
            end
            else if(pop)
            begin
            
               wr_ptr <= wr_ptr - is_part[rd_ptr]; 
               rd_ptr <= rd_ptr - is_part[rd_ptr]; 
            
            end
        
        end
    
    end    
    
    RV_dp_ram #(
    
        .DATAW  (WIDTH * 2),
        .SIZE   (DEPTH)
        
    ) store (
    
        .clk   (clk),
        .wren  (push),
        .waddr (wr_ptr),
        .wdata ({q2, q1}),
        .raddr (rd_ptr),
        .rdata ({d2, d1})
        
    );
    
    always @(posedge clk) 
    begin
    
        if (push) 
        begin
        
            is_part[wr_ptr] <= ~pair;   
            
        end else if (pop) 
        begin    
                
            is_part[rd_ptr] <= 1;
            
        end
        
    end
    
    assign index  = is_part[rd_ptr];
    assign d      = index ? d1 : d2;
    assign empty  = wr_ptr == 0;
    assign full   = wr_ptr == DEPTH-1;

endmodule
