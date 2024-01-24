`timescale 1ns / 1ps



module RV_fifo_queue#(

    parameter DATAW         = 8,
    parameter SIZE          = 8,
    parameter ALM_FULL      = SIZE - 1,
    parameter ALM_EMPTY     = 1,
    parameter ADDRW         = $clog2(SIZE),
    parameter SIZEW         = $clog2(SIZE + 1),
    parameter OUT_REG       = 0

)(
    
    input wire clk,
    input wire reset,
    input wire                push,
    input wire                pop,
    input wire [DATAW-1 : 0]  data_in,
    
    output wire [DATAW-1 : 0] data_out,
    output wire               empty,
    output wire               alm_empty,
    output wire               full,
    output wire               alm_full,
    output wire [SIZEW-1 : 0] size
    
);

    if(SIZE == 1)
    begin
    
        reg [DATAW-1 : 0] head_r;
        reg size_r;
        
        always@(posedge clk)
        begin
        
            if(reset)
            begin
            
                head_r  <= 0;
                size_r  <= 0;
            
            end//reset end
            else begin
            
                if(push)
                begin
                
                    if(!pop)
                    begin
                    
                        size_r <= 1;
                    
                    end//!pop end
                
                end//push end
                else if(pop)
                begin
                
                    size_r <= 0;
                
                end
                
                if(push)
                begin
                
                    head_r <= data_in;
                
                end
            
            end
        
        end//always end
        
        assign data_out  = head_r;
        assign empty     = (size_r == 0);
        assign alm_empty = 1;
        assign full      = (size_r != 0);
        assign alm_full  = 1;
        assign size      = size_r;
    
    end
    else begin
    
        reg empty_r , alm_empty_r;
        reg full_r  , alm_full_r;
        reg [ADDRW-1 : 0] ptr;
        
        always@(posedge clk)
        begin
        
            if(reset)
            begin
            
                empty_r      <= 1;  
                alm_empty_r  <= 1;
                full_r       <= 0;
                alm_full_r   <= 0;
                ptr          <= 0;
            
            end
            else begin
            
                if(push)
                begin
                    
                    if(!pop)
                    begin
                    
                        empty_r <= 0;
                        if(ptr == ALM_EMPTY)
                        begin
                            
                            alm_empty_r <= 0;
                        
                        end    
                        if(ptr == SIZE-1)
                        begin
                            
                            full_r <= 1;
                        
                        end
                        if(ptr == ALM_FULL-1)
                        begin
                            
                            alm_full_r <= 1;
                        
                        end 
                     
                    
                    end//!pop
                
                end//push 
                else if(pop)
                begin
                
                    full_r <= 0;
                    if(ptr == ALM_FULL)
                    begin
                        
                        alm_full_r <= 0;
                    
                    end    
                    if(ptr == 1)
                    begin
                        
                        empty_r <= 1;
                    
                    end
                    if(ptr == ALM_EMPTY+1)
                    begin
                        
                        alm_empty_r <= 1;
                    
                    end   
                
                end//pop end
                
                if(SIZE > 2)
                begin
                    
                    //ptr <= ptr + $signed({1'b0 , push} - {1'b0 , pop});
                    if(push)
                    begin
                        
                        ptr <= ptr + 1;
                    
                    end
                    else if(pop)
                    begin
                        
                        ptr <= ptr - 1;
                    
                    end
                
                end//SIZE > 2
                else begin
                    
                    ptr[0] <= ptr[0] ^ (push ^ pop);
                
                end//SIZE == 2
            
            end
        
        end//always end
        
        if(SIZE == 2)
        begin
        
            if(OUT_REG == 0)
            begin
            
                reg [DATAW-1 : 0] shift_reg [1 : 0];
                
                always@(posedge clk)
                begin
                
                    if(push)
                    begin
                        
                        shift_reg[1] <= shift_reg[0];
                        shift_reg[0] <= data_in; 
                    
                    end
                
                end
                
                assign data_out = shift_reg[!ptr[0]];
            
            end//OUT_REG
            else begin
            
                reg [DATAW-1 : 0] data_out_r;
                reg [DATAW-1 : 0] buffer;
                
                always@(posedge clk)
                begin
                
                    if(push)
                    begin
                    
                        buffer <= data_in;
                    
                    end
                    if(push && (empty_r || (ptr && pop)))
                    begin
                    
                        data_out_r <= data_in;
                    
                    end
                    else if(pop)
                    begin
                    
                        data_out_r <= buffer;
                    
                    end
                
                end
                
                assign data_out = data_out_r;
            
            end
        
        end//SIZE == 2 
        else begin
        
             if(OUT_REG == 0)
             begin
             
                reg [ADDRW-1 : 0] rd_ptr_r;
                reg [ADDRW-1 : 0] wr_ptr_r;
                
                always@(posedge clk)
                begin
                
                    if(reset)
                    begin
                    
                        rd_ptr_r  <= 0;
                        wr_ptr_r  <= 0;
                    
                    end
                    else begin
                    
                        rd_ptr_r <= rd_ptr_r + ({{ADDRW-2{1'b0}}, pop});
                        wr_ptr_r <= wr_ptr_r + ({{ADDRW-2{1'b0}}, push});
                    
                    end
                
                end//always
                
                RV_dp_ram #(
                
                    .DATAW   (DATAW),
                    .SIZE    (SIZE),
                    .OUT_REG (0),
                    .INIT_ENABLE(1)
                    
                ) dp_ram (
                
                    .clk   (clk),
                    .wren  (push),
                    .waddr (wr_ptr_r),
                    .wdata (data_in),
                    .raddr (rd_ptr_r),
                    .rdata (data_out)
                    
                );
             
             end//OUT_REG 
             else begin
                
                wire [DATAW-1:0] dout;
                reg  [DATAW-1:0] dout_r;
                reg  [ADDRW-1:0] wr_ptr_r;
                reg  [ADDRW-1:0] rd_ptr_r;
                reg  [ADDRW-1:0] rd_ptr_n_r;
                
                always@(posedge clk)
                begin
                
                    if(reset)
                    begin
                    
                        wr_ptr_r   <= 0;
                        rd_ptr_r   <= 0;
                        rd_ptr_n_r <= 1;
                    
                    end
                    else begin
                    
                        if(push)
                        begin
                        
                            wr_ptr_r <= wr_ptr_r + 1;
                        
                        end
                        if(pop)
                        begin
                        
                            rd_ptr_r <= rd_ptr_n_r;
                            if(SIZE > 2)
                            begin
                            
                                rd_ptr_n_r <= rd_ptr_r + 2;
                            
                            end
                            else begin
                                
                                rd_ptr_n_r <= ~rd_ptr_n_r;
                            
                            end
                        
                        end//pop    
                    
                    end
                
                end//always
                
                RV_dp_ram #(
                
                    .DATAW   (DATAW),
                    .SIZE    (SIZE),
                    .OUT_REG (0),
                    .INIT_ENABLE(1)
                ) dp_ram (
                    .clk   (clk),
                    .wren  (push),
                    .waddr (wr_ptr_r),
                    .wdata (data_in),
                    .raddr (rd_ptr_n_r),
                    .rdata (dout)
                ); 
                
                always @(posedge clk) 
                begin
                
                    if (push && (empty_r || ((ptr == 1) && pop))) 
                    begin
                    
                        dout_r <= data_in;
                        
                    end else if (pop) 
                    begin
                    
                        dout_r <= dout;
                        
                    end
                    
                end//always
                
                assign data_out = dout_r;
             
             end
        
        end//SIZE > 2
        
        assign empty     = empty_r;        
        assign alm_empty = alm_empty_r;
        assign full      = full_r;
        assign alm_full  = alm_full_r;
        assign size      = {full_r, ptr};
    
    end

endmodule
