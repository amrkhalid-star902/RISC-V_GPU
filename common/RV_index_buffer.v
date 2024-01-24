`timescale 1ns / 1ps

module RV_index_buffer#(
    
    parameter DATAW = 8,
    parameter SIZE  = 4,
    parameter ADDRW = $clog2(SIZE)
    
)(
    
    input wire clk,
    input wire reset,
    input wire [DATAW-1 : 0] write_data,
    input wire acquire_slot,
    input wire [ADDRW-1:0] read_addr,
    input wire [ADDRW-1:0] release_addr,
    input wire release_slot,
    
    output wire [ADDRW-1:0] write_addr,
    output wire [DATAW-1:0] read_data,
    output wire empty,
    output wire full
    
);

    reg [SIZE-1  :  0] free_slots , free_slots_n;
    reg [ADDRW-1 :  0] write_addr_r;
    reg empty_r , full_r;
    
    wire free_valid;
    wire [ADDRW-1 :  0] free_index;

    always@(posedge clk)
    begin
        if(reset)
        begin
        
            write_addr_r  <= {ADDRW{1'b0}};
            free_slots    <= {SIZE{1'b1}};
            empty_r       <= 1'b1;
            full_r        <= 1'b0;
        
        end
        else begin
            
            write_addr_r  <= free_index;
            free_slots    <= free_slots_n;
            empty_r       <= (&free_slots_n);
            full_r        <= ~free_valid;
        
        end
    
    end
    
    always@(*)
    begin
        
        free_slots_n = free_slots;
        if(release_slot)
        begin
        
            free_slots_n[release_addr] = 1;
        
        end
        
        if(acquire_slot)
        begin
        
            free_slots_n[write_addr_r] = 0;
        
        end
    
    end
    
    RV_lzc #(
    
        .N (SIZE)
        
    ) free_slots_sel (
    
        .in_i    (free_slots_n),
        .cnt_o   (free_index),
        .valid_o (free_valid)
        
    );
    
    RV_dp_ram #(
    
        .DATAW  (DATAW),
        .SIZE   (SIZE),
        .INIT_ENABLE(1)
        
    ) data_table (
    
        .clk   (clk), 
        .wren  (acquire_slot),
        .waddr (write_addr_r),
        .wdata (write_data),
        .raddr (read_addr),
        .rdata (read_data)
        
    );       
       
    assign write_addr = write_addr_r;
    assign empty      = empty_r;
    assign full       = full_r;

endmodule 