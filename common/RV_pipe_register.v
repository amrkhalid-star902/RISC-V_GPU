`timescale 1ns / 1ps

module RV_pipe_register#(

    parameter DATAW  = 8,
    parameter RESETW = DATAW,
    parameter DEPTH  = 1

)(
    
    input  wire clk,
    input  wire reset,
    input  wire enable,
    input  wire [DATAW-1:0] data_in,
    output wire [DATAW-1:0] data_out
    
);

    generate
    
        if(DEPTH == 0)
        begin
            
            //Indicate that this varaibles are unused to prevent compiler warnings
            always @(clk) begin end
            always @(clk) begin end
            always @(clk) begin end
            
            assign data_out = data_in;
            
        end  
        else if(DEPTH == 1)
        begin
        
            //single-stage pipline
            if(RESETW == 0)
            begin
            
                //The system is not resetable
                always @(reset) begin end
                reg [DATAW-1 : 0] value;
                
                always@(posedge clk)
                begin
                
                    if(enable)begin
                    
                        value <= data_in;
                    
                    end
                
                end
                
                assign data_out = value;
            
            end
            else if(RESETW == DATAW)
            begin
                
                //All the reg bits are resetable
                reg [DATAW-1 : 0] value;
                
                always@(posedge clk)
                begin
                
                    if(reset)begin
                    
                        value <= {RESETW{1'b0}};
                    
                    end
                    else if(enable)begin
                    
                        value <= data_in;
                    
                    end
                
                end
                
                assign data_out = value;
                
            end
            else begin
            
                //0 < RESETW < DATAW
                //only part of register bits is resetable
                reg [DATAW-RESETW-1 : 0] value_d;
                reg [RESETW-1 : 0]       value_r;
                
                always@(posedge clk)
                begin
                
                    if(reset) begin
                        
                        value_r <= {RESETW{1'b0}};
                    
                    end
                    else if(enable) begin
                    
                        value_r <= data_in[DATAW-1:DATAW-RESETW]; // Register most significant bits
                    
                    end
                
                end
                
                always@(posedge clk)
                begin
                
                    if(enable) 
                    begin
                    
                        value_d <=  data_in[DATAW-RESETW-1:0]; // Register Least significant bits
                    
                    end
                
                end
                
                assign data_out = {value_r , value_d};
            
            end
        
        end
        else begin
        
            // Multiple pipeline stages using a shift register
            RV_shift_register #(
                .DATAW  (DATAW),
                .RESETW (RESETW),
                .DEPTH  (DEPTH)
            ) shift_reg (
                .clk      (clk),
                .reset    (reset),
                .enable   (enable),
                .data_in  (data_in),
                .data_out (data_out)
            );  
        
        end
        
    endgenerate


endmodule
