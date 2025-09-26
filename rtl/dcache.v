// rtl/dcache.v
/*******************************************************************/
// Data Cache (DCACHE) - FINAL, ROBUST VERSION
//
// * Handles misses by returning to IDLE and waiting for a CPU retry.
/*******************************************************************/
module dcache (
    input               clk,
    input               reset,

    // Interface to CPU
    input      [31:0]   cpu_addr,
    input      [31:0]   cpu_wdata,
    input      [3:0]    cpu_wmask,
    input               cpu_read_req,
    input               cpu_write_req,
    output reg [31:0]   cpu_rdata,
    output reg          cpu_busy,

    // Interface to Memory Interconnect
    output reg [31:0]   mem_addr,
    output reg [31:0]   mem_wdata,
    output reg [3:0]    mem_wmask,
    output reg          mem_read_req,
    output reg          mem_write_req,
    input      [31:0]   mem_rdata,
    input               mem_busy
);

    // Cache Parameters
    localparam LINE_SIZE_WORDS = 8;
    localparam NUM_SETS        = 16;

    // Address decomposition
    wire [22:0] tag     = cpu_addr[31:9];
    wire [3:0]  index   = cpu_addr[8:5];
    wire [2:0]  offset  = cpu_addr[4:2];

    // Storage
    reg [22:0]  tag_0[NUM_SETS-1:0], tag_1[NUM_SETS-1:0];
    reg         valid_0[NUM_SETS-1:0], valid_1[NUM_SETS-1:0];
    reg [31:0]  data_0[NUM_SETS-1:0][LINE_SIZE_WORDS-1:0];
    reg [31:0]  data_1[NUM_SETS-1:0][LINE_SIZE_WORDS-1:0];
    reg         lru[NUM_SETS-1:0]; // 0=Way0 LRU, 1=Way1 LRU

    // Hit Logic
    wire hit_0 = valid_0[index] && (tag_0[index] == tag);
    wire hit_1 = valid_1[index] && (tag_1[index] == tag);

    // FSM States
    localparam S_IDLE          = 3'b000;
    localparam S_MEM_WRITE     = 3'b001;
    localparam S_MEM_READ_WAIT = 3'b010;
    localparam S_MEM_READ_FILL = 3'b011;

    reg [2:0] state;
    reg [2:0] fill_counter;
    reg       victim_way;

    always @(posedge clk) begin
        if (!reset) begin
            for (integer i = 0; i < NUM_SETS; i = i + 1) begin
                valid_0[i] = 1'b0;
                valid_1[i] = 1'b0;
            end
            state <= S_IDLE;
            cpu_busy <= 1'b0;
            mem_read_req <= 1'b0;
            mem_write_req <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    cpu_busy <= 1'b0;
                    mem_read_req <= 1'b0;
                    mem_write_req <= 1'b0;

                    if (cpu_read_req) begin
                        if (hit_0) begin
                            cpu_rdata <= data_0[index][offset];
                            lru[index] <= 1'b1;
                        end else if (hit_1) begin
                            cpu_rdata <= data_1[index][offset];
                            lru[index] <= 1'b0;
                        end else begin
                            // READ MISS: Start line fill
                            cpu_busy <= 1'b1;
                            victim_way <= lru[index];
                            fill_counter <= 3'b0;
                            mem_addr <= {cpu_addr[31:5], 5'b0};
                            mem_read_req <= 1'b1;
                            state <= S_MEM_READ_WAIT;
                        end
                    end else if (cpu_write_req) begin
                        // WRITE-THROUGH
                        cpu_busy <= 1'b1;
                        mem_addr <= cpu_addr;
                        mem_wdata <= cpu_wdata;
                        mem_wmask <= cpu_wmask;
                        mem_write_req <= 1'b1;
                        state <= S_MEM_WRITE;
                        
                        if (hit_0) data_0[index][offset] <= cpu_wdata;
                        if (hit_1) data_1[index][offset] <= cpu_wdata;
                    end
                end

                S_MEM_WRITE: begin
                    mem_write_req <= 1'b0;
                    if (!mem_busy) begin
                        cpu_busy <= 1'b0;
                        state <= S_IDLE;
                    end
                end

                S_MEM_READ_WAIT: begin
                    mem_read_req <= 1'b0;
                    if (!mem_busy) begin
                        if (victim_way == 0) data_0[index][fill_counter] <= mem_rdata;
                        else                 data_1[index][fill_counter] <= mem_rdata;
                        fill_counter <= fill_counter + 1;
                        state <= S_MEM_READ_FILL;
                    end
                end
                
                S_MEM_READ_FILL: begin
                    mem_addr <= mem_addr + 4;
                    mem_read_req <= 1'b1;

                    if (!mem_busy) begin
                        if (victim_way == 0) data_0[index][fill_counter] <= mem_rdata;
                        else                 data_1[index][fill_counter] <= mem_rdata;
                        
                        if (fill_counter == 3'(LINE_SIZE_WORDS - 1)) begin
                            // Line fill is complete. Update tags and go to IDLE.
                            // The CPU is stalled and will re-try the request, which will now be a hit.
                            if (victim_way == 0) begin
                                tag_0[index] <= tag;
                                valid_0[index] <= 1'b1;
                            end else begin
                                tag_1[index] <= tag;
                                valid_1[index] <= 1'b1;
                            end
                            lru[index] <= ~victim_way;
                            cpu_busy <= 1'b0;
                            state <= S_IDLE;
                        end else begin
                            fill_counter <= fill_counter + 1;
                        end
                    end
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end
endmodule
