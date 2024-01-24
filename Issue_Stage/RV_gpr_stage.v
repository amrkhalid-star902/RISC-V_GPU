`timescale 1ns / 1ps

`include "RV_define.vh"

module RV_gpr_stage#(


    parameter CORE_ID = 0

)(
    
    input  wire clk,
    input  wire reset,
    
    input  wire                            writeback_if_valid,
    input  wire [`UUID_BITS-1 : 0]         writeback_if_uuid,
    input  wire [`NUM_THREADS-1 : 0]       writeback_if_tmask,
    input  wire [`NW_BITS-1 : 0]           writeback_if_wid,
    input  wire [31 : 0]                   writeback_if_PC,
    input  wire [`NR_BITS-1 : 0]           writeback_if_rd,
    input  wire [(`NUM_THREADS*32)-1 : 0]  writeback_if_data,
    input  wire                            writeback_if_eop,
    input  wire [`NW_BITS-1 : 0]           gpr_req_if_wid,
    input  wire [`NR_BITS-1 : 0]           gpr_req_if_rs1,
    input  wire [`NR_BITS-1 : 0]           gpr_req_if_rs2,
    input  wire [`NR_BITS-1 : 0]           gpr_req_if_rs3,
    
    output wire                            writeback_if_ready,
    output wire [(`NUM_THREADS*32)-1 : 0]  gpr_rsp_if_rs1_data,
    output wire [(`NUM_THREADS*32)-1 : 0]  gpr_rsp_if_rs2_data,
    output wire [(`NUM_THREADS*32)-1 : 0]  gpr_rsp_if_rs3_data
    
);

    localparam RAM_SIZE = `NUM_WARPS * `NUM_REGS;
    wire write_enable = writeback_if_valid && (writeback_if_rd != 0);
    
    wire [`NUM_THREADS-1:0] wren;
    
    genvar i;
    generate
    
        for(i = 0 ; i < `NUM_THREADS ; i = i + 1)
        begin
        
           assign wren[i] = write_enable && writeback_if_tmask[i]; 
        
        end
    
    endgenerate
    
    wire [$clog2(RAM_SIZE)-1 : 0] waddr , raddr1 , raddr2;
    assign waddr = {writeback_if_wid, writeback_if_rd};
    assign raddr1 = {gpr_req_if_wid, gpr_req_if_rs1};
    assign raddr2 = {gpr_req_if_wid, gpr_req_if_rs2};
    
    generate
    
        for(i = 0 ; i < `NUM_THREADS ; i = i + 1)
        begin : gen_blk
        
            RV_dp_ram#(
            
                .DATAW(32),
                .SIZE(RAM_SIZE),
                .INIT_ENABLE(1),
                .INIT_VALUE(0)
                
            ) dp_ram1(
            
                .clk(clk),
                .wren(wren[i]),
                .waddr(waddr),
                .wdata(writeback_if_data[((i+1) * 32) - 1 : i * 32]),
                .raddr(raddr1),
                .rdata(gpr_rsp_if_rs1_data[((i+1) * 32) - 1 : i * 32])
            );
            
            RV_dp_ram#(
            
                .DATAW(32),
                .SIZE(RAM_SIZE),
                .INIT_ENABLE(1),
                .INIT_VALUE(0)
                
            ) dp_ram2(
            
                .clk(clk),
                .wren(wren[i]),
                .waddr(waddr),
                .wdata(writeback_if_data[((i+1) * 32) - 1 : i * 32]),
                .raddr(raddr2),
                .rdata(gpr_rsp_if_rs2_data[((i+1) * 32) - 1 : i * 32])
            );
        
        
        end
    
    endgenerate
    
    `ifdef EXT_F_ENABLE
        
        wire [$clog2(RAM_SIZE)-1 : 0] raddr3;
        assign raddr3 = {gpr_req_if_wid, gpr_req_if_rs3};
        
        for(i = 0 ; i < `NUM_THREADS ; i = i + 1)
        begin: gen_blk2
        
            RV_dp_ram#(
        
                .DATAW(32),
                .SIZE(RAM_SIZE),
                .INIT_ENABLE(1),
                .INIT_VALUE(0)
                
            ) dp_ram3(
            
                .clk(clk),
                .wren(wren[i]),
                .waddr(waddr),
                .wdata(writeback_if_data[((i+1) * 32) - 1 : i * 32]),
                .raddr(raddr3),
                .rdata(gpr_rsp_if_rs3_data[((i+1) * 32) - 1 : i * 32])
            );
                
        
        end
    
    `endif
    
    assign writeback_if_ready = 1'b1;

endmodule
