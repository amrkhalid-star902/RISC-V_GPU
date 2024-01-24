`timescale 1ns / 1ps

`include "RV_define.vh"


module RV_ibuffer#(

    parameter CORE_ID = 0

)(

    input  wire clk,
    input  wire reset,
    
    input  wire                          decode_if_valid,
    input  wire [`UUID_BITS-1 : 0]       decode_if_uuid,
    input  wire [`NW_BITS-1 : 0]         decode_if_wid,
    input  wire [`NUM_THREADS-1 : 0]     decode_if_tmask,
    input  wire [31 : 0]                 decode_if_PC,
    input  wire [`EX_BITS-1 : 0]         decode_if_ex_type,
    input  wire [`INST_OP_BITS-1 : 0]    decode_if_op_type,
    input  wire [`INST_MOD_BITS-1 : 0]   decode_if_op_mod,
    input  wire                          decode_if_wb,
    input  wire                          decode_if_use_PC,
    input  wire                          decode_if_use_imm,
    input  wire [31 : 0]                 decode_if_imm,
    input  wire [`NR_BITS-1 : 0]         decode_if_rd,
    input  wire [`NR_BITS-1 : 0]         decode_if_rs1,
    input  wire [`NR_BITS-1 : 0]         decode_if_rs2,
    input  wire [`NR_BITS-1 : 0]         decode_if_rs3,
    input  wire                          ibuffer_if_ready,
    
    output wire                          decode_if_ready,
    output wire                          ibuffer_if_valid,
    output wire [`UUID_BITS-1 : 0]       ibuffer_if_uuid,
    output wire [`NW_BITS-1 : 0]         ibuffer_if_wid,
    output wire [`NUM_THREADS-1 : 0]     ibuffer_if_tmask,
    output wire [31 : 0]                 ibuffer_if_PC,
    output wire [`EX_BITS-1 : 0]         ibuffer_if_ex_type,
    output wire [`INST_OP_BITS-1 : 0]    ibuffer_if_op_type,
    output wire [`INST_MOD_BITS-1 : 0]   ibuffer_if_op_mod,
    output wire                          ibuffer_if_wb,
    output wire                          ibuffer_if_use_PC,
    output wire                          ibuffer_if_use_imm,
    output wire [31 : 0]                 ibuffer_if_imm,
    output wire [`NR_BITS-1 : 0]         ibuffer_if_rd,
    output wire [`NR_BITS-1 : 0]         ibuffer_if_rs1,
    output wire [`NR_BITS-1 : 0]         ibuffer_if_rs2,
    output wire [`NR_BITS-1 : 0]         ibuffer_if_rs3,
    output wire [`NR_BITS-1 : 0]         ibuffer_if_rd_n,
    output wire [`NR_BITS-1 : 0]         ibuffer_if_rs1_n,
    output wire [`NR_BITS-1 : 0]         ibuffer_if_rs2_n,
    output wire [`NR_BITS-1 : 0]         ibuffer_if_rs3_n,
    output wire [`NW_BITS-1 : 0]         ibuffer_if_wid_n

);
    
    localparam DATAW   = `UUID_BITS + `NUM_THREADS + 32 + `EX_BITS + `INST_OP_BITS + `INST_FRM_BITS + 1 + (`NR_BITS * 4) + 32 + 1 + 1;
    localparam ADDRW   = $clog2(`IBUF_SIZE+1);
    localparam NWARPSW = $clog2(`NUM_WARPS+1);
    
    reg [ADDRW-1 : 0] used_r [`NUM_WARPS-1 : 0];
    reg [`NUM_WARPS-1 : 0] full_r , empty_r , alm_empty_r;
    
    wire [`NUM_WARPS-1 : 0] q_full , q_empty , q_alm_empty;
    wire [DATAW-1 : 0] q_data_in;
    wire [DATAW-1 : 0] q_data_prev [`NUM_WARPS-1 : 0];    
    reg  [DATAW-1 : 0] q_data_out  [`NUM_WARPS-1 : 0];
    
    wire enq_fire = decode_if_valid && decode_if_ready;
    wire deq_fire = ibuffer_if_valid && ibuffer_if_ready;
    
    genvar i;
    generate
    
        for(i = 0 ; i < `NUM_WARPS ; i = i + 1)
        begin
        
            wire writing = enq_fire && (i == decode_if_wid); 
            wire reading = deq_fire && (i == ibuffer_if_wid);
            
            wire going_empty = empty_r[i] || (alm_empty_r[i] && reading);
            
            RV_elastic_buffer #(
            
                .DATAW   (DATAW),
                .SIZE    (`IBUF_SIZE),
                .OUT_REG (1)
                
            ) queue (
            
                .clk      (clk),
                .reset    (reset),
                .valid_in (writing && !going_empty),
                .data_in  (q_data_in),            
                .ready_out(reading),
                .data_out (q_data_prev[i]),            
                .ready_in(),
                .valid_out()
                
            );
            
            always@(posedge clk)
            begin
            
                if(reset)
                begin
                
                    used_r[i]      <= 0;
                    full_r[i]      <= 0;
                    empty_r[i]     <= 1; 
                    alm_empty_r[i] <= 1;
                
                end//reset
                else begin
                    
                    if(writing)
                    begin
                        
                        if(!reading)
                        begin
                        
                            empty_r[i] <= 0;
                            if(used_r[i] == 1)
                                alm_empty_r[i] <= 0;
                            if(used_r[i] == `IBUF_SIZE)
                                full_r[i] <= 1;
                                
                        end//reading
                    
                    end//writing
                    else if(reading)
                    begin
                            
                        full_r[i] <= 0; 
                        if(used_r[i] == 1)
                            empty_r[i] <= 1;
                        if(used_r[i] == 2)
                            alm_empty_r[i] <= 1;
                    
                    end
                    
                    if(writing)
                        used_r[i] <= used_r[i] + 1;
                    else if(reading)
                        used_r[i] <= used_r[i] - 1;
                
                end//else
                
                if(writing && going_empty) 
                begin                                                       
                    q_data_out[i] <= q_data_in;
                end 
                else if(reading) 
                begin
                    q_data_out[i] <= q_data_prev[i];
                end 
            
            end//always
            
            assign q_full[i]      = full_r[i];
            assign q_empty[i]     = empty_r[i];
            assign q_alm_empty[i] = alm_empty_r[i];
            
        end//For Loop
        
        reg  [`NUM_WARPS-1 : 0] valid_table , valid_table_n;
        reg  [`NW_BITS-1 : 0] deq_wid , deq_wid_n;
        reg  [`NW_BITS-1 : 0] deq_wid_rr; 
        wire [`NW_BITS-1 : 0] deq_wid_rr_n;
        
        reg deq_valid, deq_valid_n;
        reg [DATAW-1 : 0] deq_instr , deq_instr_n;
        reg [NWARPSW-1:0] num_warps;
        
        always@(*)
        begin
        
            valid_table_n = valid_table;  
            if(deq_fire)
            begin
            
                valid_table_n[deq_wid] = !q_alm_empty[deq_wid];
            
            end
            
            if(enq_fire)
            begin
            
                valid_table_n[decode_if_wid] = 1;
            
            end
        
        end
        
        // round-robin warp scheduling
        RV_rr_arbiter #(
        
            .NUM_REQS (`NUM_WARPS)
            
        ) rr_arbiter (
            .clk (clk),
            .reset (reset),          
            .requests (valid_table_n), 
            .grant_index (deq_wid_rr_n),
            .grant_valid (),
            .grant_onehot (),
            .enable ()
        );
        
        always@(*)
        begin
        
            if(num_warps > 1)
            begin
            
                deq_valid_n = 1;
                deq_wid_n   = deq_wid_rr; 
                deq_instr_n = q_data_out[deq_wid_rr];
            
            end
            else if(num_warps == 1 && !(deq_fire && q_alm_empty[deq_wid]))
            begin
            
                deq_valid_n  = 1;
                deq_wid_n    = deq_wid;
                deq_instr_n = deq_fire ? q_data_prev[deq_wid] : q_data_out[deq_wid];
            
            end
            else begin
            
                deq_valid_n = enq_fire;
                deq_wid_n   = decode_if_wid;
                deq_instr_n = q_data_in;
            
            end
        
        end//always
        
        wire warp_added   = enq_fire && q_empty[decode_if_wid];
        wire warp_removed = deq_fire && ~(enq_fire && decode_if_wid == deq_wid) && q_alm_empty[deq_wid];
        
        always @(posedge clk) 
        begin
        
            if (reset)  
            begin         
               
                valid_table <= 0;
                deq_valid   <= 0;  
                num_warps   <= 0;
                
            end 
            else begin
            
                valid_table <= valid_table_n;            
                deq_valid   <= deq_valid_n;
                
    
                if (warp_added && !warp_removed) 
                begin
                    num_warps <= num_warps + 1;
                end 
                else if (warp_removed && !warp_added) 
                begin
                    num_warps <= num_warps - 1;                
                end
                
            end
                
            deq_wid    <= deq_wid_n;
            deq_wid_rr <= deq_wid_rr_n;
            deq_instr  <= deq_instr_n;
            
        end//always
        
        assign decode_if_ready = ~q_full[decode_if_wid];
        
        assign q_data_in = {decode_if_uuid,
                            decode_if_tmask, 
                            decode_if_PC, 
                            decode_if_ex_type, 
                            decode_if_op_type, 
                            decode_if_op_mod, 
                            decode_if_wb,
                            decode_if_use_PC,
                            decode_if_use_imm,
                            decode_if_imm,
                            decode_if_rd, 
                            decode_if_rs1, 
                            decode_if_rs2, 
                            decode_if_rs3};
                            
        assign ibuffer_if_valid = deq_valid;
        assign ibuffer_if_wid   = deq_wid;
        assign {ibuffer_if_uuid,
                ibuffer_if_tmask, 
                ibuffer_if_PC, 
                ibuffer_if_ex_type, 
                ibuffer_if_op_type, 
                ibuffer_if_op_mod, 
                ibuffer_if_wb,
                ibuffer_if_use_PC,
                ibuffer_if_use_imm,
                ibuffer_if_imm,
                ibuffer_if_rd, 
                ibuffer_if_rs1, 
                ibuffer_if_rs2, 
                ibuffer_if_rs3} = deq_instr;
                
         // scoreboard forwarding
         assign ibuffer_if_wid_n = deq_wid_n;
         assign ibuffer_if_rd_n  = deq_instr_n[(3+1)*`NR_BITS - 1 : 3*`NR_BITS];
         assign ibuffer_if_rs1_n = deq_instr_n[(2+1)*`NR_BITS - 1 : 2*`NR_BITS];    
         assign ibuffer_if_rs2_n = deq_instr_n[(1+1)*`NR_BITS - 1 : 1*`NR_BITS];
         assign ibuffer_if_rs3_n = deq_instr_n[(0+1)*`NR_BITS - 1 : 0*`NR_BITS];
    
    endgenerate
    
endmodule
