`timescale 1ns / 1ps

`include "VX_define.vh"


module VX_conv_unit#(

    parameter CORE_ID = 0

)(  
    
    input  wire clk,
    input  wire reset,
    
    input  wire                             conv_req_if_valid,
    input  wire [`UUID_BITS-1 : 0]          conv_req_if_uuid,
    input  wire [`NW_BITS-1 : 0]            conv_req_if_wid,
    input  wire [`NUM_THREADS-1 : 0]        conv_req_if_tmask,
    input  wire [31 : 0]                    conv_req_if_PC,
    input  wire [(`NUM_THREADS*32)-1 : 0]   conv_req_if_rs1_data,
    input  wire [(`NUM_THREADS*32)-1 : 0]   conv_req_if_rs2_data,
    input  wire [`NR_BITS-1 : 0]            conv_req_if_rd,
    input  wire                             conv_req_if_wb,
    input  wire                             conv_commit_if_ready,
    
    output wire                             conv_req_if_ready,
    output wire                             conv_commit_if_valid,
    output wire [`UUID_BITS-1 : 0]          conv_commit_if_uuid,
    output wire [`NW_BITS-1 : 0]            conv_commit_if_wid,
    output wire [`NUM_THREADS-1 : 0]        conv_commit_if_tmask,
    output wire [31 : 0]                    conv_commit_if_PC,
    output wire [31 : 0]                    conv_commit_if_data,
    output wire [`NR_BITS-1 : 0]            conv_commit_if_rd,
    output wire                             conv_commit_if_wb,
    output wire                             conv_commit_if_eop
    
 );
 
    //Converting flat data into 2d array
    wire [31 : 0] dataa [`NUM_THREADS-1 : 0];
    wire [31 : 0] datab [`NUM_THREADS-1 : 0];
    
    wire [(`NUM_THREADS*32)-1 : 0] products;
    wire [(`NUM_THREADS*32)-1 : 0] tree_in;
    wire [31 : 0]                  tree_out;
    wire valid_out;
    
    genvar i;
    generate
    
        for(i = 0 ; i < `NUM_THREADS ; i = i + 1)
        begin
        
            assign dataa[i] = conv_req_if_rs1_data[(i+1) * 32 - 1:i * 32];
            assign datab[i] = conv_req_if_rs2_data[(i+1) * 32 - 1:i * 32];
            
        end
    
    endgenerate
    
    wire stall  = ~conv_commit_if_ready && conv_commit_if_valid;
    wire enable = !stall && conv_req_if_valid;
    
    generate
        
        for(i = 0 ; i < `NUM_THREADS ; i = i + 1)
        begin
        
            VX_multiplier#(
            
                .WIDTHA(32),
                .WIDTHB(32),
                .WIDTHP(64),  //Width of the  product
                .SIGNED(1),
                .LATENCY(0)
            
            )multyplier(
                
                .clk(clk),
                .enable(enable),
                .dataa(dataa[i]),
                .datab(datab[i]),
                .result(products[(i+1) * 32 - 1:i * 32])
                
            );
        
        end
    
    endgenerate
    
    wire adder_en , adder_active;
    
    VX_pipe_register#(
        
        .DATAW(1 + (`NUM_THREADS * 32))
    
    )pipe_reg(
    
        .clk(clk),
        .reset(reset),
        .enable(enable),
        .data_in({enable , products}),
        .data_out({adder_en , tree_in})
    
    );
    
    VX_adder_tree#(
    
        .N(`NUM_THREADS),
        .DATAW(32)
    
    )adder_tree(
        
        .clk(clk),
        .reset(reset),
        .en(adder_en),
        .dataIn(tree_in),
        .dout(tree_out),
        .active(adder_active)
        
    );
    
    wire [31 : 0] accumIn , accumOut;
    wire accum_en;
    
    VX_pipe_register#(
        
        .DATAW(1 + 32)
    
    )pipe_reg1(
    
        .clk(clk),
        .reset(reset),
        .enable(adder_active),
        .data_in({adder_active , tree_out}),
        .data_out({accum_en , accumIn})
    
    );
    
    VX_accumlate#(
    
        .DATAW(32),
        .N(`NUM_THREADS) 
    
    )accumlator(
        
        .clk(clk),
        .reset(reset),
        .enable(accum_en),
        .dataIn(accumIn),
        .dataOut(accumOut),
        .valid_out(valid_out)
        
    );
    
    VX_pipe_register #(

        .DATAW  (1 + `UUID_BITS + `NW_BITS + `NUM_THREADS + 32 + `NR_BITS + 1),
        .RESETW (1),
        .DEPTH  (0)
        
    ) pipe_reg2(
    
        .clk      (clk),    
        .reset    (reset),  
        .enable   (enable), 
        .data_in  ({valid_out , conv_req_if_uuid , conv_req_if_wid , conv_req_if_tmask , conv_req_if_PC , conv_req_if_rd , conv_req_if_wb}),
        .data_out ({conv_commit_if_valid , conv_commit_if_uuid , conv_commit_if_wid , conv_commit_if_tmask , conv_commit_if_PC , conv_commit_if_rd , conv_commit_if_wb})
        
    );
    
    assign conv_req_if_ready   = enable;
    assign conv_commit_if_eop  = 1;
    assign conv_commit_if_data = accumOut;
    
endmodule
