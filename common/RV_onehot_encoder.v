`timescale 1ns / 1ps

// Fast encoder using parallel prefix computation
// Adapted from BaseJump STL: http://bjump.org/data_out.html

module RV_onehot_encoder#(

    parameter N        = 5,
    parameter REVERSE  = 0,
    parameter MODEL    = 3,
    parameter LN       = $clog2(N)

)(
    
    input  wire [N-1 : 0]  data_in,
    output wire [LN-1 : 0] data_out,
    output wire            valid_out
    
);

    genvar level, segment;
    genvar i, j;
    integer k;
        
    generate
    
        if(N == 1)
        begin
        
            assign data_out  = data_in;
            assign valid_out = data_in;
        
        end
        else if(N == 2)
        begin
        
            assign data_out  = data_in[!REVERSE];
            assign valid_out = (| data_in);
        
        end
        else if(MODEL == 1)
        begin
        
            localparam levels_lp        = $clog2(N);
            localparam aligned_width_lp = 1 << $clog2(N); 
            
            wire [aligned_width_lp-1 : 0] addr [levels_lp : 0];
            wire [aligned_width_lp-1 : 0] v    [levels_lp : 0];    
            
            assign v[0]    = REVERSE ? ({{(aligned_width_lp-N){1'b0}}, data_in} << (aligned_width_lp - N)) : {{(aligned_width_lp-N){1'b0}}, data_in};
            assign addr[0] = 0;  //The first level isnot used 
            
            for (level = 1; level < levels_lp+1; level=level+1)
            begin
                
                localparam segments_lp      = 2**(levels_lp-level);
                localparam segment_slot_lp  = aligned_width_lp/segments_lp;
                localparam segment_width_lp = level; 
                
                 for (segment = 0; segment < segments_lp; segment=segment+1)
                 begin
                    
                    wire [1 : 0] vs = {
                    
                         v[level-1][segment*segment_slot_lp+(segment_slot_lp >> 1)],
                         v[level-1][segment*segment_slot_lp]  
                    
                    };
                    
                    assign v[level][segment*segment_slot_lp] = (| vs); 
                    
                    if(level == 1)
                    begin
                        
                        assign addr[level][((segment*segment_slot_lp) + segment_width_lp) - 1 : (segment*segment_slot_lp)] = vs[!REVERSE]; 
                    
                    end
                    else begin
                    
                        assign addr[level][((segment*segment_slot_lp) + segment_width_lp) - 1 : (segment*segment_slot_lp)] = { 
                            
                            vs[!REVERSE],
                            addr[level-1][((segment*segment_slot_lp) + segment_width_lp) - 2 : (segment*segment_slot_lp)] | 
                            addr[level-1][(segment*segment_slot_lp+(segment_slot_lp >> 1)) + segment_width_lp - 2 : segment*segment_slot_lp+(segment_slot_lp >> 1)]
                        
                        };    
                    
                    end
                    
                 end
            
            end
            
            localparam LOG2UP_N = (((N) > 1) ? $clog2(N) : 1);
            
            assign data_out  = addr[levels_lp][LOG2UP_N-1:0];
            assign valid_out = v[levels_lp][0];
            
        end
        else if(MODEL == 2)
        begin
        
            for (j = 0; j < LN; j = j + 1)
            begin
                    
                wire [N-1 : 0] mask;
               
                for (i = 0; i < N; i = i + 1) 
                begin
               
                    assign mask[i] = i[j];
               
                end
                
                assign data_out[j] = |(mask & data_in); 
            
            end
            
            assign valid_out = (|data_in);  
        
        end
        else begin
        
            reg [LN-1 : 0] index_r;
            
            if(REVERSE)
            begin
            
                always@(*)
                begin
                
                    index_r = 0;
                    for (k = N-1; k >= 0; k = k-1)
                    begin
                    
                        if (data_in[k]) 
                        begin
                        
                            index_r = k;
                        
                        end
                    
                    end
                
                end
            
            end
            else begin
            
                always@(*)
                begin
                    
                    index_r = 0; 
                    for (k = 0; k < N; k = k + 1)
                    begin
                    
                        if (data_in[k]) 
                        begin
                        
                            index_r = k;
                        
                        end   
                    
                    end
                
                end
            
            end
            
            assign data_out  = index_r;  
            assign valid_out = (| data_in);
        
        end
    
    endgenerate

endmodule
