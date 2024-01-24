`timescale 1ns / 1ps


module RV_pending_size#(

    parameter SIZE  = 4,
    parameter SIZEW = $clog2(SIZE+1)

)(

    input wire clk,
    input wire reset,
    input wire incr,
    input wire decr,
    
    output wire empty,
    output wire full,
    output wire [SIZEW-1 : 0] size

);


    localparam ADDRW = $clog2(SIZE);
    
    reg [ADDRW-1 : 0] counter;
    reg empty_r;
    reg full_r;
    
    always@(posedge clk)
    begin
    
        if(reset)
        begin
        
            counter <= 0;
            empty_r <= 1;
            full_r  <= 0;
        
        end
        else begin
        
            if(incr)
            begin
            
                if(!decr)
                begin
                    
                    empty_r <= 0;
                    if(counter == SIZE-1)
                        full_r <= 1;
                
                end//!decr
            
            end//incr
            else if(decr)
            begin
                
                full_r <= 0;
                if(counter == 1)
                    empty_r <= 1;
            
            end
            
            if(incr && !decr)
                counter <= counter + 1;
                
            if(!incr && decr)
                    counter <= counter - 1;
            
        end
    
    end
    
    assign empty = empty_r;
    assign full  = full_r;
    assign size  = {full_r, counter};

endmodule
