`timescale 1ns / 1ps

/*
    * This module implement a binary divider circut in the hardware
    * The steps of the algorithm is as follow:
    * 1. Subtract the Divisor register from the Remainder register and place the 
         result in the Remainder register
    * 2. Check wheter the remender is bigger or less than zer0
        2a.  Remainder ? 0 :  Shift the Quotient register to the left,
                               setting the new rightmost bit to 1
        2b.  Remainder < 0 :  Restore the original value by adding
                              the Divisor register to the Remainder
                              register and placing the sum in the
                              Remainder register. Also shift the
                              Quotient register to the left, setting the new left significant bit to zero
    * 3. hift the Divisor register right 1 bit
*/

module RV_serial_div#(

    parameter WIDTHN = 8,       // Width of Numerator
    parameter WIDTHD = 8,       // Width of Denominator 
    parameter WIDTHQ = 8,       // Width of Quotient 
    parameter WIDTHR = 8,       // Width of Remainder
    parameter LANES  = 1,
    parameter TAGW   = 1

)(

    input wire clk,
    input wire reset,
    
    input wire valid_in,
    input wire [(LANES*WIDTHN)-1 : 0] numer,
    input wire [(LANES*WIDTHD)-1 : 0] denom,
    input wire [TAGW-1 : 0] tag_in,
    input wire signed_mode,
    input wire ready_out,
    
    output wire ready_in,
    output wire [(LANES*WIDTHQ)-1 : 0] quotient,
    output wire [(LANES*WIDTHR)-1 : 0] remainder,
    output wire valid_out,
    output wire [TAGW-1 : 0] tag_out
    
);

    localparam MIN_ND = (WIDTHN < WIDTHD) ? WIDTHN : WIDTHD;
    localparam CNTRW  = $clog2(WIDTHN+1);  // CNTRW is the number of bits needed to represent a counter that counts up to WIDTHN+1.
    
    wire [WIDTHN-1 : 0] numer_2d     [LANES-1 : 0];
    wire [WIDTHD-1 : 0] denom_2d     [LANES-1 : 0];
    wire [WIDTHQ-1 : 0] quotient_2d  [LANES-1 : 0];
    wire [WIDTHR-1 : 0] remainder_2d [LANES-1 : 0];
    
    genvar m;
    generate
    
        for(m = 0 ; m < LANES ; m = m + 1)
        begin
        
            assign numer_2d[m] = numer[((m+1)*WIDTHN)-1 : m*WIDTHN];
            assign denom_2d[m] = denom[((m+1)*WIDTHD)-1 : m*WIDTHD];
            
            assign quotient[((m+1)*WIDTHQ)-1 : m*WIDTHQ]  = quotient_2d[m];
            assign remainder[((m+1)*WIDTHR)-1 : m*WIDTHR] = remainder_2d[m];
        
        end
    
    endgenerate
    
    reg [WIDTHN + MIN_ND : 0] working [LANES-1 : 0];
    reg [WIDTHD-1 : 0]        denom_r [LANES-1 : 0];
    
    wire [WIDTHN-1 : 0] numer_qual [LANES-1 : 0];
    wire [WIDTHD-1 : 0] denom_qual [LANES-1 : 0];
    wire [WIDTHD : 0]   sub_result [LANES-1 : 0];
    
    reg [LANES-1 : 0] inv_quot , inv_rem;
    
    reg [CNTRW-1 : 0] cntr;  // A counter register used to keep track of the number of bits that have been processed so far during each division operation.
    reg is_busy;

    reg [TAGW-1 : 0] tag_r;
    
    wire done = ~(| cntr);

    wire push = valid_in  && ready_in;
    wire pop  = valid_out && ready_out;
    
    genvar i;
    generate
    
        for(i = 0 ; i < LANES ; i = i + 1)
        begin
        
            wire negate_numer = signed_mode && numer_2d[i][WIDTHN-1];
            wire negate_denom = signed_mode && denom_2d[i][WIDTHD-1];
            
            assign numer_qual[i] = negate_numer ? -$signed(numer_2d[i]) : numer_2d[i];
            assign denom_qual[i] = negate_numer ? -$signed(denom_2d[i]) : denom_2d[i];
            assign sub_result[i] = working[i][WIDTHN + MIN_ND : WIDTHN] - denom_r[i];

        end
    
    endgenerate
    
    integer j;
    always@(posedge clk)
    begin
    
        if(reset)
        begin
        
            cntr    <= 0;
            is_busy <= 0;
        
        end//reset
        else begin
        
            if(push)
            begin
                cntr    <= WIDTHN;
                is_busy <= 1; 
            end
            else if(!done)
            begin
                cntr <= cntr - 1;            
            end
            if(pop)
            begin            
                is_busy <= 0;
            end
        
        end//else
        
        if(push)
        begin
        
            for(j = 0 ; j < LANES ; j = j + 1)
            begin
            
                working[j]  <= {{WIDTHD{1'b0}}, numer_qual[j], 1'b0};
                denom_r[j]  <= denom_qual[j];
                inv_quot[j] <= (denom_2d[j] != 0) && signed_mode && (numer_2d[j][31] ^ denom_2d[j][31]);
                inv_rem[j]  <= signed_mode && numer_2d[j][31];
                
            end
            tag_r <= tag_in;
        
        end
        else if(!done)
        begin
        
            for(j = 0 ; j < LANES ; j = j + 1)
            begin
            
                working[j] <= sub_result[j][WIDTHD] ? {working[j][WIDTHN+MIN_ND-1:0], 1'b0} :
                            {sub_result[j][WIDTHD-1:0], working[j][WIDTHN-1:0], 1'b1};    
                
            end
        
        end
    
    end//always
    
    generate
    
        for(m = 0 ; m < LANES ; m = m + 1)
        begin
        
            wire [WIDTHQ-1 : 0] q  = working[m][WIDTHQ-1:0];
            wire [WIDTHR-1 : 0] r  = working[m][WIDTHN+WIDTHR:WIDTHN+1];
            assign quotient_2d[m]  = inv_quot[m] ? -$signed(q) : q;
            assign remainder_2d[m] = inv_rem[m]  ? -$signed(r) : r;
        
        end
    
    endgenerate
    
    assign ready_in  = !is_busy;    
    assign tag_out   = tag_r;
    assign valid_out = is_busy && done;
    
endmodule
