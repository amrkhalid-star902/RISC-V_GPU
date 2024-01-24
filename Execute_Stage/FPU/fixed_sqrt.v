`timescale 1ns / 1ps


module fixed_sqrt#(

    parameter WIDTH = 28,
    parameter FBITS = 24

)(

    input  wire clk,
    input  wire reset,
    input  wire start,
    input  wire [WIDTH-1 : 0] rad, //radicand
    
    output wire busy,
    output wire valid,
    output wire [WIDTH-1 : 0] root,
    output wire [WIDTH-1 : 0] rem

);

    reg [WIDTH-1 : 0] x, x_next;    // radicand copy
    reg [WIDTH-1 : 0] q, q_next;    // intermediate root (quotient)
    reg [WIDTH+1 : 0] ac, ac_next;  // accumulator (2 bits wider)
    reg [WIDTH+1 : 0] test_res;     // sign test result (2 bits wider)
    
    localparam ITER = (WIDTH+FBITS) >> 1;
    integer i;
    
    always@(*)
    begin
    
        test_res = ac - {q, 2'b01};
        
        if(test_res[WIDTH+1] == 0) // test_res ?0? (check MSB)
        begin
        
           {ac_next, x_next} = {test_res[WIDTH-1:0], x, 2'b0};
           q_next = {q[WIDTH-2:0], 1'b1};
        
        end
        else begin
        
            {ac_next, x_next} = {ac[WIDTH-1:0], x, 2'b0};
            q_next = q << 1;
        
        end
        
    end
    
    reg busy_n, valid_n;
    reg [WIDTH-1 : 0] root_n, rem_n;
    
    wire pop = valid_n && !busy;
    
    always@(posedge clk)
    begin
        if(reset)
        begin
            
            busy_n <= 0;
            valid_n <= 0;
            i <= 0;
            q <= 0;    
        
        end
        else if (start) 
        begin
            busy_n <= 1;
            valid_n <= 0;
            i <= 0;
            q <= 0;
            {ac, x} <= {{WIDTH{1'b0}}, rad, 2'b0};
        end else if (busy) begin
            if (i == ITER-1) 
            begin  // we're done
                busy_n <= 0;
                valid_n <= 1;
                root_n <= q_next;
                rem_n <= ac_next[WIDTH+1:2];  // undo final shift
            end else begin  // next iteration
                i <= i + 1;
                x <= x_next;
                ac <= ac_next;
                q <= q_next;
            end
        end
        
        if(pop)
        begin
        
            valid_n <= 0;
        
        end
    
    end
    
    assign busy  = busy_n;
    assign valid = valid_n;
    assign root  = root_n;
    assign rem   = rem_n;

endmodule
