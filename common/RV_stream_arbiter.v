`timescale 1ns / 1ps


module RV_stream_arbiter#(

    parameter NUM_REQS    = 4,
    parameter LANES       = 1,
    parameter DATAW       = 8,
    parameter TYPE        = "P",
    parameter LOCK_ENABLE = 0,
    parameter BUFFERED    = 0

)(

    input wire clk,
    input wire reset,
    
    input wire [LANES-1:0]                   ready_out,
    input wire [NUM_REQS*LANES-1 : 0]        valid_in,
    input wire [NUM_REQS*LANES*DATAW-1 : 0]  data_in,
    
    output wire [NUM_REQS*LANES-1 : 0]       ready_in,
    output wire [LANES-1 : 0]                valid_out,
    output wire [LANES*DATAW-1 : 0]          data_out
    
);
    localparam LOG_NUM_REQS = $clog2(NUM_REQS);
    
    wire [LANES-1:0] valid_in_2d [NUM_REQS-1:0];   
    wire [DATAW-1:0] data_in_3d  [NUM_REQS-1:0][LANES-1:0];
    wire [DATAW-1:0] data_out_2d [LANES-1:0];
    wire [LANES-1:0] ready_in_2d [NUM_REQS-1:0]; 
    
    genvar i , j , k;
    generate
    
        for(i = 0 ; i < NUM_REQS ; i = i + 1)
        begin
        
            assign  valid_in_2d[i]   =   valid_in[(i+1)*LANES-1 : i*LANES];
            assign  ready_in[(i+1)*LANES-1 : i*LANES]   =   ready_in_2d[i];
        
        end
        
        for(i = 0 ; i < NUM_REQS ; i = i + 1)
        begin
        
            for(j = 0 ; j < LANES ; j = j + 1)
            begin
            
                 assign data_in_3d[i][j] = data_in[(((i * LANES) + j + 1)*DATAW)-1 : (((i * LANES) + j)*DATAW)];
            
            end
        
        end
        
        for(k = 0 ; k < LANES ; k = k + 1)
        begin
        
            assign  data_out[(k+1)*DATAW-1 : k*DATAW]   =   data_out_2d[k];
        
        end
    
    endgenerate
    
    generate
    
        if(NUM_REQS > 1)
        begin
        
            wire sel_valid;
            wire sel_ready;
            wire [LOG_NUM_REQS-1 : 0] sel_index;
            wire [NUM_REQS-1 : 0]     sel_onehot;
            
            wire [NUM_REQS-1 : 0] valid_in_any;
            wire [LANES-1 : 0]    ready_in_sel;
            
            if (LANES > 1)
             begin
             
                for ( i = 0; i < NUM_REQS; i = i + 1) 
                begin
                
                    assign valid_in_any[i] = (| valid_in_2d[i]);    //  Requests are sent to the arbiter if they are valid in any Lane.
                
                end
                
                assign sel_ready = (| ready_in_sel);    
           
            end 
            else begin
            
                for ( i = 0; i < NUM_REQS; i = i + 1) 
                begin
                    
                    assign valid_in_any[i] = valid_in_2d[i]; 
                
                end
                
                assign sel_ready = ready_in_sel[0];
            
            end
            
            if (TYPE == "R") 
            begin
            
                RV_rr_arbiter #(
                
                    .NUM_REQS    (NUM_REQS),
                    .LOCK_ENABLE (LOCK_ENABLE)
                    
                ) sel_arb (
                    .clk          (clk),
                    .reset        (reset),
                    .requests     (valid_in_any),  
                    .enable       (sel_ready),
                    .grant_valid  (sel_valid),
                    .grant_index  (sel_index),
                    .grant_onehot (sel_onehot)
                );
                
            end 
            else if(TYPE == "P")
            begin
            
                RV_fixed_arbiter #(
                
                    .NUM_REQS    (NUM_REQS),
                    .LOCK_ENABLE (LOCK_ENABLE)
                    
                ) sel_arb (
                
                    .clk          (clk),
                    .reset        (reset),
                    .requests     (valid_in_any),  
                    .enable       (sel_ready),
                    .grant_valid  (sel_valid),
                    .grant_index  (sel_index),
                    .grant_onehot (sel_onehot)
                    
                );
            
            end
            
            wire [LANES-1:0] valid_in_sel;                 
            wire [DATAW-1:0] data_in_sel    [LANES-1:0];   
            wire [(LANES * DATAW)-1:0] data_in_sel_1d; 
            
            for ( i = 0; i < LANES; i = i + 1)
            begin
            
                assign data_in_sel[i] = data_in_sel_1d[((i+1) * DATAW) - 1 : i * DATAW];
            
            end
            
            if (LANES > 1) begin
            
                wire [(LANES * (1 + DATAW))-1:0] valid_data_in [NUM_REQS-1:0];   //  Valid Signal and Data of each Request across Lanes.
                
                //  Assign each Request's Valid Signal and Data.
                for ( i = 0; i < NUM_REQS; i = i + 1) 
                begin
                
                    assign valid_data_in[i] = {valid_in_2d[i], data_in[((i+1) * (DATAW*LANES)) - 1 : i * (DATAW*LANES)]};
                
                end
    
                //  Granted Request is index (sel_index), output its Data and Valid.
                assign {valid_in_sel, data_in_sel_1d} = valid_data_in[sel_index];
    
            end 
            else begin
                
                assign data_in_sel[0]  = data_in_3d[sel_index][0];
                assign valid_in_sel[0] = sel_valid;
                
            end
            
            for ( i = 0; i < NUM_REQS; i = i + 1) 
            begin
            
                assign ready_in_2d[i] = ready_in_sel & {LANES{sel_onehot[i]}};
                
            end
            
            for ( i = 0; i < LANES; i = i + 1) 
            begin
            
                RV_skid_buffer #(
                
                    .DATAW    (DATAW),
                    .PASSTHRU (0 == BUFFERED),
                    .OUT_REG  (2 == BUFFERED)
                    
                ) out_buffer (
                
                    .clk       (clk),
                    .reset     (reset),
                    .valid_in  (valid_in_sel[i]),        
                    .data_in   (data_in_sel[i]),
                    .ready_in  (ready_in_sel[i]),      
                    .valid_out (valid_out[i]),
                    .data_out  (data_out_2d[i]),
                    .ready_out (ready_out[i])
                    
                );
                
            end
        
        end
        else begin
            
            assign valid_out = valid_in_2d[0];        
            assign data_out_2d[0]  = data_in_3d[0][0];
            assign ready_in_2d[0]  = ready_out;
    
        end
        
    endgenerate
    
endmodule
