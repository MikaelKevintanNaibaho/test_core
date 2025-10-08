/*******************************************************************/
// Branch Target Buffer (BTB)
//
// * 4-entry fully-associative cache for branch prediction.
/*******************************************************************/

module btb #(
    parameter N_ENTRIES     = 4,
    parameter ADDR_WIDTH    = 24
) (
    input clk,
    input reset,

    // Interface to the core
    input       [ADDR_WIDTH-1:0]    pc_in,
    input                           branch_taken,
    input       [ADDR_WIDTH-1:0]    branch_target_in,
    output reg                      btb_hit,
    output reg  [ADDR_WIDTH-1:0]    btb_target_out

);
    // BTB storage
    reg [ADDR_WIDTH-1:0]    tags[N_ENTRIES-1:0];
    reg [ADDR_WIDTH-1:0]    targets[N_ENTRIES-1:0];
    reg [1:0]               lru_bits; // simple LRU replacement policy
    
    integer i;

    // combinatorial lookup
    always@(*) begin
        btb_hit = 1'b0;
        btb_target_out = {ADDR_WIDTH{1'b0}};
        for (i = 0; i < N_ENTRIES; i = i + 1) begin
            if (tags[i] == pc_in) begin
                btb_hit = 1'b1;
                btb_target_out = targets[i];
            end
        end
    end

    // Synchronous update
    always @(posedge clk) begin
        if (!reset) begin
            for (i = 0; i < N_ENTRIES; i = i + 1) begin
                tags[i] <= {ADDR_WIDTH{1'b0}};
                targets[i] <= {ADDR_WIDTH{1'b0}};
            end
            lru_bits <= 2'b0;
        end else if (branch_taken) begin
            tags[lru_bits] <= pc_in;
            targets[lru_bits] <= branch_target_in;
            lru_bits <= lru_bits + 1;
       end
    end
    
endmodule

