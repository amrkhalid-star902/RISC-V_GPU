`timescale 1ns / 1ps

`include "RV_define.vh"

/*
    *RV_warp_sched,  is a module responsible for scheduling the execution of warps (groups of threads) on a GPU core. 
    *The module has several inputs and outputs, such as the warp ID, the instruction opcode, the register file, the scoreboard, and the ready signals. 
    *The module uses a finite state machine to control the warp scheduling logic, which involves checking the availability of resources, 
    *issuing instructions to execution units, handling stalls and hazards, and updating the warp status.
*/

module RV_warp_sched#(

    parameter CORE_ID  = 0

)(

    input wire clk,
    input wire reset,
    
    //-------------------------TMC instruction-------------------------//
    input wire                                  ifetch_req_if_ready,
    input wire                                  warp_ctl_if_valid,
    input wire [`NW_BITS-1 : 0]	                warp_ctl_if_wid,
    input wire                                  warp_ctl_if_tmc_valid,
    input wire [`NUM_THREADS-1 : 0]             warp_ctl_if_tmc_tmask,
    
    
    //-------------------------Wspawn instruction-------------------------//
    input wire                                  warp_ctl_if_wspawn_valid,
    input wire [`NUM_WARPS-1 : 0]               warp_ctl_if_wspawn_wmask,
    input wire [31 : 0]                         warp_ctl_if_wspawn_pc,

    //-------------------------Barrier instruction-------------------------//
    input wire                                  warp_ctl_if_barrier_valid,
    input wire [`NB_BITS-1 : 0]                 warp_ctl_if_barrier_id,
    input wire [`NW_BITS-1 : 0]                 warp_ctl_if_barrier_size_m1,
    
    //-------------------------Split-Join instruction-------------------------//
    input wire                                  warp_ctl_if_split_valid,
    input wire                                  warp_ctl_if_split_diverged,
    input wire [`NUM_THREADS-1 : 0]             warp_ctl_if_split_then_tmask,
    input wire [`NUM_THREADS-1 : 0]             warp_ctl_if_split_else_tmask,
    input wire [31 : 0]                         warp_ctl_if_split_pc,
    input wire                                  wstall_if_valid,
    input wire [`NW_BITS-1 : 0]                 wstall_if_wid,
    input wire                                  wstall_if_stalled,
    input wire                                  join_if_valid,
    input wire [`NW_BITS-1 : 0]                 join_if_wid,
    input wire                                  branch_ctl_if_valid,
    input wire [`NW_BITS-1 : 0]                 branch_ctl_if_wid,
    input wire                                  branch_ctl_if_taken,
    input wire [31 : 0]                         branch_ctl_if_dest,
    
    //output side
    output wire                                 ifetch_req_if_valid,
    output wire [`UUID_BITS-1 : 0]	            ifetch_req_if_uuid,
    output wire [`NUM_THREADS-1 : 0]            ifetch_req_if_tmask,
    output wire [`NW_BITS-1 : 0]	            ifetch_req_if_wid,
    output wire [31:0]				            ifetch_req_if_PC,
    output wire [(`NUM_WARPS*`NUM_THREADS)-1:0]	fetch_to_csr_if_thread_masks,
    output wire                                 busy
    
);

    wire                        join_else;
    wire [31 : 0]               join_pc;
    wire [`NUM_THREADS-1 : 0]   join_tmask;
    
    reg [`NUM_WARPS-1 : 0] active_warps , active_warps_n;
    reg [`NUM_WARPS-1 : 0] stalled_warps;
    
    reg [`NUM_THREADS-1 : 0] thread_masks [`NUM_WARPS-1 : 0];
    reg [31 : 0]             warps_pcs    [`NUM_WARPS-1 : 0];
    
    //Tracking of inserted barriers
    reg  [`NUM_WARPS-1 : 0] barrier_masks [`NUM_BARRIERS-1 : 0];
    wire reached_barrier_limit;
    
    //Wspawn Instruction
    reg [31 : 0] wspawn_pc;
    reg [`NUM_WARPS-1 : 0] use_wspawn;
    
    wire [`NW_BITS-1 : 0]      schedule_wid;
    wire [`NUM_THREADS-1 : 0]  schedule_tmask;
    wire [31 : 0]              schedule_pc;
    wire                       schedule_valid;
    wire                       warp_scheduled;
    
    reg [`UUID_BITS-1:0] issued_instrs;
    
    wire ifetch_req_fire = ifetch_req_if_valid && ifetch_req_if_ready;
    wire tmc_active      = (warp_ctl_if_tmc_tmask != 0); 
    
	function automatic signed [`NUM_WARPS-1:0] NUM_WARPS_cast;
	
        input reg signed [`NUM_WARPS-1:0] inp;
        NUM_WARPS_cast = inp;
        
    endfunction
    
	function automatic signed [`NUM_THREADS-1:0] NUM_THREADS_cast;
	
        input reg signed [`NUM_THREADS-1:0] inp;
        NUM_THREADS_cast = inp;
        
    endfunction
    
    always@(*)
    begin
    
        active_warps_n = active_warps;
        if(warp_ctl_if_valid && warp_ctl_if_wspawn_valid)
        begin
        
            active_warps_n = warp_ctl_if_wspawn_wmask;
        
        end
        
        if (warp_ctl_if_valid && warp_ctl_if_tmc_valid)
        begin
        
            active_warps_n[warp_ctl_if_wid] = tmc_active;
        
        end
    
    end
    
    integer i;
    always@(posedge clk)
    begin
    
        if(reset)
        begin
        
            use_wspawn      <= 0;
            stalled_warps   <= 0;
            active_warps    <= 0;
            issued_instrs   <= 0;
            
            for(i = 0 ; i < `NUM_BARRIERS ; i = i + 1)
            begin
                
                barrier_masks[i] <= 0;
            
            end//for loop
            
            for(i = 0 ; i < `NUM_WARPS ; i = i + 1)
            begin
                
                warps_pcs[i] <= 0;
            
            end//for loop
            
            for(i = 0 ; i < `NUM_WARPS ; i = i + 1)
            begin
                
                thread_masks[i] <= 0;
            
            end//for loop
            
            warps_pcs[0]     <= `STARTUP_ADDR;
            active_warps[0]  <= 1;
            thread_masks[0]  <= 1;
        
        end//reset   
        else begin
        
            if(warp_ctl_if_valid && warp_ctl_if_wspawn_valid)
            begin
            
                use_wspawn <= warp_ctl_if_wspawn_wmask & (~NUM_WARPS_cast(1));
                wspawn_pc  <= warp_ctl_if_wspawn_pc;
            
            end    
            
            if(warp_ctl_if_valid && warp_ctl_if_barrier_valid)
            begin
            
                stalled_warps[warp_ctl_if_wid] <= 0;
                if(reached_barrier_limit)
                begin
                
                    barrier_masks[warp_ctl_if_barrier_id] <= 0;
                
                end
                else begin
                
                    barrier_masks[warp_ctl_if_barrier_id][warp_ctl_if_wid] <= 1;
                
                end
            
            end
            
            if(warp_ctl_if_valid && warp_ctl_if_tmc_valid) 
            begin
            
                thread_masks[warp_ctl_if_wid]  <= warp_ctl_if_tmc_tmask;
                stalled_warps[warp_ctl_if_wid] <= 0;
            
            end
            
            if (warp_ctl_if_valid && warp_ctl_if_split_valid) 
            begin
            
                stalled_warps[warp_ctl_if_wid] <= 0;
                if (warp_ctl_if_split_diverged) 
                begin
                
                    thread_masks[warp_ctl_if_wid] <= warp_ctl_if_split_then_tmask;
                
                end
                
            end
            
            if (branch_ctl_if_valid) 
            begin
            
                if (branch_ctl_if_taken) 
                begin
                
                    warps_pcs[branch_ctl_if_wid] <= branch_ctl_if_dest;
                
                end
                stalled_warps[branch_ctl_if_wid] <= 0;
                
            end
            
            if (warp_scheduled) 
            begin
            
                // stall the warp until decode stage
                stalled_warps[schedule_wid] <= 1;

                // release wspawn
                use_wspawn[schedule_wid] <= 0;
                if (use_wspawn[schedule_wid]) 
                begin
                
                    thread_masks[schedule_wid] <= 1;
                    
                end

                issued_instrs <= issued_instrs + 1;
                
            end
            
            //Next PC to be fetched
            if (ifetch_req_fire) 
            begin
            
                warps_pcs[ifetch_req_if_wid] <= ifetch_req_if_PC + 4;
            
            end
            
            if (wstall_if_valid) 
            begin
            
                stalled_warps[wstall_if_wid] <= wstall_if_stalled;
            
            end
            
            if (join_if_valid) 
            begin
            
                if (join_else) 
                begin
                
                    warps_pcs[join_if_wid] <= join_pc;
                
                end
                thread_masks[join_if_wid] <= join_tmask;
            
            end
            
            active_warps <= active_warps_n;
        
        end//else
    
    end//always
    
    // export thread mask register
    genvar j;
    generate 
    
        for ( j = 0; j < `NUM_WARPS; j = j + 1)
         begin 
         
            assign fetch_to_csr_if_thread_masks [j*`NUM_THREADS+:`NUM_THREADS] = thread_masks [j];
            
        end
    
    endgenerate
    
    wire [`NW_BITS:0] active_barrier_count;
    wire [`NUM_WARPS-1:0] barrier_mask = barrier_masks[warp_ctl_if_barrier_id];
    
    RV_popcount #(
    
        .N(`NUM_WARPS)
    
    )barrier_count(
    
        .in_i(barrier_mask),
        .cnt_o(active_barrier_count)
        
    );
    
    assign reached_barrier_limit = (active_barrier_count[`NW_BITS-1:0] == warp_ctl_if_barrier_size_m1);
    
    reg [`NUM_WARPS-1:0] barrier_stalls;
    always @(*) 
    begin
    
        barrier_stalls = barrier_masks[0];
        for ( i = 1; i < `NUM_BARRIERS; i = i + 1) 
        begin
        
            barrier_stalls = barrier_stalls | barrier_masks[i];
        
        end
        
    end
    
    // Split / join stack managment
    //The width of ipdom stack entry used to store thread mask and the alternative pc in case if else path
    wire [(32+`NUM_THREADS)-1 : 0] ipdom_data [`NUM_WARPS-1 : 0]; 
    wire [`NUM_WARPS-1 : 0] ipdom_index;
    
    generate
    
        for(j = 0 ; j < `NUM_WARPS ; j = j + 1)
        begin
        
            wire push = warp_ctl_if_valid 
                     && warp_ctl_if_split_valid
                     && (j == warp_ctl_if_wid);     
                     
            wire pop = join_if_valid && (j == join_if_wid);
            
            wire [`NUM_THREADS-1:0] else_tmask = warp_ctl_if_split_else_tmask;
            wire [`NUM_THREADS-1:0] orig_tmask = thread_masks[warp_ctl_if_wid];
            
            wire [(32+`NUM_THREADS)-1:0] q_else = {warp_ctl_if_split_pc, else_tmask};
            wire [(32+`NUM_THREADS)-1:0] q_end  = {32'b0,                orig_tmask};
            
            RV_ipdom_stack #(
            
                .WIDTH (32+`NUM_THREADS), 
                .DEPTH (2 ** (`NT_BITS+1))
                
            ) ipdom_stack (
            
                .clk   (clk),
                .reset (reset),
                .push  (push),
                .pop   (pop),
                .pair  (warp_ctl_if_split_diverged),
                .q1    (q_end),
                .q2    (q_else),
                .d     (ipdom_data[j]),
                .index (ipdom_index[j]),
                .empty (),
                .full  ()
                
            );
            
            
        end
        
    endgenerate
    
    assign {join_pc, join_tmask} = ipdom_data[join_if_wid];
    assign join_else = ~ipdom_index[join_if_wid];
    
    wire [`NUM_WARPS-1:0] ready_warps = active_warps & ~(stalled_warps | barrier_stalls);
    
    RV_lzc #(
    
        .N (`NUM_WARPS)
        
    ) wid_select (
    
        .in_i    (ready_warps),
        .cnt_o   (schedule_wid),
        .valid_o (schedule_valid)
        
    );
    
    wire [(`NUM_THREADS + 32)-1:0] schedule_data [`NUM_WARPS-1:0];
    
    genvar k;
    generate
    
        for ( k = 0; k < `NUM_WARPS; k = k + 1) 
        begin
        
            assign schedule_data[k] = {(use_wspawn[k] ? NUM_THREADS_cast(1) : thread_masks[k]),
                                       (use_wspawn[k] ? wspawn_pc : warps_pcs[k])};
                                       
        end
    
    endgenerate
    
    assign {schedule_tmask, schedule_pc} = schedule_data[schedule_wid];

    wire stall_out = ~ifetch_req_if_ready && ifetch_req_if_valid;   

    assign warp_scheduled = schedule_valid && ~stall_out;
    
    wire [`UUID_BITS-1:0] instr_uuid = (issued_instrs * `NUM_CORES * `NUM_CLUSTERS) + {12'b0, (CORE_ID)};   //  Concatenated 12'b0 to avoid warnings.
    
    RV_pipe_register #( 
    
        .DATAW  (1 + `UUID_BITS + `NUM_THREADS + 32 + `NW_BITS),
        .RESETW (1)
        
    ) pipe_reg (
    
        .clk      (clk),
        .reset    (reset),
        .enable   (!stall_out),
        .data_in  ({schedule_valid,      instr_uuid,         schedule_tmask,      schedule_pc,      schedule_wid}),
        .data_out ({ifetch_req_if_valid, ifetch_req_if_uuid, ifetch_req_if_tmask, ifetch_req_if_PC, ifetch_req_if_wid})
        
    );
    
    assign busy = (active_warps != 0);
    
endmodule
