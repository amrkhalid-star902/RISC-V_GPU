`timescale 1ns / 1ps



module FusedMulAdd(clk , en , reset , a , b , c , q);

    input  wire clk;
    input  wire reset;
    input  wire en;
    input  wire [31 : 0] a , b , c;
    output reg [31 : 0] q;
    
    //Some internal wires
    wire [31 : 0] product;
    wire [31 : 0] src1 , src2;
    

    //Extract different fields of A and B
    wire A_sign;
    wire [7:0] A_exp;     //exponent part of input A
    wire [22:0] A_frac;   //fraction part of A
    wire B_sign;
    wire [7:0] B_exp;     //exponent part of input B
    wire [22:0] B_frac;   //fraction part of B
    
    //extracting sign of the input
    assign A_sign = a[31];
    assign B_sign = b[31];
    
    //extracting exponent part of the inputs
    assign A_exp = a[30:23];
    assign B_exp = b[30:23];
    
    //extracting fraction part of the inputs 
    //the fraction part will be concatenated with 1 to be in normalized form
    assign A_frac = {1'b1 , a[22:1]};
    assign B_frac = {1'b1 , b[22:1]};
    
    // XOR sign bits to determine product sign.
    wire prod_sign;
    assign prod_sign = A_sign ^ B_sign;
    
    //Multply the fractional part of the inputs
    wire [45:0] pre_product_frac;
    assign pre_product_frac = A_frac * B_frac;
    
    //Add exponents of A and B
    wire [8:0] pre_product_exp;
    assign pre_product_exp = A_exp + B_exp;
    
    //If top bit of product frac is 0, shift left one
    wire [7:0] product_exp;
    wire [22:0] product_frac;
    assign product_exp  = pre_product_frac[45] ? (pre_product_exp - 9'd126) : ((pre_product_exp - 9'd127));
    assign product_frac = pre_product_frac[45] ? (pre_product_frac[44:22])  : (pre_product_frac[43:21]);
     
     
     //Underflow detection
     wire underflow;
     assign underflow =  pre_product_exp < 9'h80;
     
     //Detect zero conditions (either product frac doesn't start with 1, or underflow)
     assign product = en ? underflow         ? 27'b0 :
                      (B_exp == 8'd0)   ? 27'b0 :
                      (A_exp == 8'd0)   ? 27'b0 :
                      {prod_sign , product_exp , product_frac} : 32'hx;
                      
   RV_pipe_register#(
                        
        .DATAW(64),
        .RESETW(64),
        .DEPTH(1)
                        
    )pipe1(
                            
        .clk(clk),
        .reset(reset),
        .enable(en),
        .data_in({product , c}),
        .data_out({src1 , src2})
                            
    );
    
    //Extract different fields of A and B
    wire src1_sign;
    wire [7:0] src1_exp;     //exponent part of input A
    wire [22:0] src1_frac;   //fraction part of A
    wire src2_sign;
    wire [7:0] src2_exp;     //exponent part of input B
    wire [22:0] src2_frac;   //fraction part of B
    
    //extracting sign of the input
    assign src1_sign = src1[31];
    assign src2_sign = src2[31];
    
    //extracting exponent part of the inputs
    assign src1_exp = src1[30:23];
    assign src2_exp = src2[30:23];
    
    //extracting fraction part of the inputs 
    //the fraction part will be concatenated with 1 to be in normalized form
    assign src1_frac = {1'b1 , src1[22:1]};
    assign src2_frac = {1'b1 , src2[22:1]};
    
    wire src1_larger;
    
    //Shifting fractions of A and B so that they align.
    wire [7:0] exp_diff_src1;
    wire [7:0] exp_diff_src2;
    wire [7:0] larger_exp;
    wire [46:0] src1_frac_shifted;
    wire [46:0] src2_frac_shifted;
    
    assign exp_diff_src1 = src2_exp - src1_exp;     //if B is larger
    assign exp_diff_src2 = src1_exp - src2_exp;     //if A is larger
    
    assign larger_exp = (src2_exp > src1_exp) ? src2_exp : src1_exp;
   
    assign src1_frac_shifted =  src1_larger            ? {1'b0 , src1_frac , 23'b0} :
                             (exp_diff_src1 > 9'd45)   ? 47'b0:
                             ({1'b0 , src1_frac , 23'b0} >> exp_diff_src1);

    assign src2_frac_shifted =  ~src1_larger           ? {1'b0 , src2_frac , 23'b0} :
                             (exp_diff_src2 > 9'd45)   ? 47'b0:
                             ({1'b0 , src2_frac , 23'b0} >> exp_diff_src2);
                             
    //Determine which of A,B is larger
    assign src1_larger = (src1_exp > src2_exp)                               ? 1'b1  :
                         ((src1_exp == src2_exp) && (src1_frac > src2_frac)) ? 1'b1  :
                         1'b0;
                         
   //Calculate sum or difference of shifted fractions.
   wire [46:0] pre_sum;
   assign pre_sum = ((src1_sign ^ src2_sign) & src1_larger)  ? src1_frac_shifted - src2_frac_shifted :
                    ((src1_sign ^ src2_sign) & ~src1_larger) ? src2_frac_shifted - src1_frac_shifted :
                     src1_frac_shifted + src2_frac_shifted;
    
   reg [46:0] buf_pre_sum;
   reg [7:0]  buf_larger_exp;
   reg        buf_src1_exp_zero;
   reg        buf_src2_exp_zero;
   reg [31:0] buf_src1;
   reg [31:0] buf_src2;
   reg        sum_sign;
   
   always@(posedge clk)
   begin
        
       buf_pre_sum         <=  pre_sum;    
       buf_larger_exp      <= larger_exp;
       buf_src1_exp_zero   <= (src1_exp == 8'b0);
       buf_src2_exp_zero   <= (src2_exp == 8'b0);
       buf_src1            <= src1;
       buf_src2            <= src2;
       sum_sign            <= src1_larger ? src1_sign : src2_sign;
       
   end
   
   //Convert to positive fraction and a sign bit.
   wire [46:0] pre_frac;
   
   assign pre_frac = buf_pre_sum;
   
   //Determine output fraction and exponent change with position of first 1
   wire [22:0] sum_frac;
   wire [7:0] shift_amount;
   
   assign shift_amount = pre_frac[46] ? 8'd0  : pre_frac[45] ? 8'd1  :
                         pre_frac[44] ? 8'd2  : pre_frac[43] ? 8'd3  :
                         pre_frac[42] ? 8'd4  : pre_frac[41] ? 8'd5  :
                         pre_frac[40] ? 8'd6  : pre_frac[39] ? 8'd7  :
                         pre_frac[38] ? 8'd8  : pre_frac[37] ? 8'd9  :
                         pre_frac[36] ? 8'd10 : pre_frac[35] ? 8'd11 :
                         pre_frac[34] ? 8'd12 : pre_frac[33] ? 8'd13 :
                         pre_frac[32] ? 8'd14 : pre_frac[31] ? 8'd15 :
                         pre_frac[30] ? 8'd16 : pre_frac[29] ? 8'd17 :
                         pre_frac[28] ? 8'd18 : pre_frac[27] ? 8'd19 :
                         pre_frac[26] ? 8'd20 : pre_frac[25] ? 8'd21 :
                         pre_frac[24] ? 8'd22 : pre_frac[23] ? 8'd23 :
                         pre_frac[22] ? 8'd24 : pre_frac[21] ? 8'd25 :
                         pre_frac[20] ? 8'd26 : pre_frac[19]  ? 8'd27 :
                         pre_frac[18] ? 8'd28 : pre_frac[17]  ? 8'd29 :
                         pre_frac[16] ? 8'd30 : pre_frac[15]  ? 8'd31 :
                         pre_frac[14] ? 8'd32 : pre_frac[13]  ? 8'd33 :
                         pre_frac[12] ? 8'd34 : pre_frac[11]  ? 8'd35 :
                         pre_frac[10] ? 8'd36 : pre_frac[9]   ? 8'd37 :
                         pre_frac[8]  ? 8'd38 : pre_frac[7]   ? 8'd39 :
                         pre_frac[6]  ? 8'd40 : pre_frac[5]   ? 8'd41 :
                         pre_frac[4]  ? 8'd42 : pre_frac[3]   ? 8'd43 :
                         pre_frac[2]  ? 8'd44 : pre_frac[1]   ? 8'd45 :
                         pre_frac[0]  ? 8'd46 : 8'd47;
                         
    wire [63:0] pre_frac_shift , uflow_shift;
                         
   //the shift +1 is because high order bit is not stored, but implied
   assign pre_frac_shift = {pre_frac , 17'b0} << (shift_amount + 1);
   assign uflow_shift = {pre_frac , 17'b0} << (shift_amount);
   assign sum_frac = pre_frac_shift[63:41]; 
   
   wire [7:0] sum_exp;
   assign sum_exp = buf_larger_exp - shift_amount + 1;
   
   //Detect underflow
   //Find  if top bit of matissa is not set
   wire underflow1;
   //assign underflow = 0;
   assign underflow1 = ~uflow_shift[63];    
   
   always@(posedge clk)
   begin
       
       if(reset)begin
           q <= 32'h00;
       end
       else if(en)begin
       
           q <= (buf_src1_exp_zero && buf_src2_exp_zero) ? 32'b0 :
                  buf_src1_exp_zero    ? buf_src2 :
                  buf_src2_exp_zero    ? buf_src1 :
                  underflow1        ? 32'b0 :
                  (pre_frac == 0)   ? 32'b0 :
                  {sum_sign , sum_exp , sum_frac};
       
       end
   
   end 

endmodule
