// rtl/icache.v
/*******************************************************************/
// Instruction Cache (ICACHE) - CORRECTED
//
// * 4 KB Capacity, Direct-Mapped
// * 32-byte (8-word) line size
// * Fills one cache line with multiple memory reads on a miss
/*******************************************************************/
module icache (
    input               clk,
    input               reset,

    // Interface to CPU
    input      [31:0]   cpu_addr,
    input               cpu_req,      // CPU requests an instruction
    output reg [31:0]   cpu_rdata,
    output reg          cpu_busy,

    // Interface to Memory
    output reg [31:0]   mem_addr,
    output reg          mem_rstrb,
    input      [31:0]   mem_rdata,
    input               mem_rbusy
);

    // Cache Parameters
    localparam LINE_SIZE_WORDS = 8;
    localparam NUM_LINES       = 128; // 4KB / (4 bytes/word * 8 words/line) = 128 lines

    // Address decomposition
    wire [19:0] cpu_tag    = cpu_addr[31:12];
    wire [6:0]  cpu_index  = cpu_addr[11:5];
    wire [2:0]  cpu_offset = cpu_addr[4:2];

    // Cache Storage
    reg [19:0]  tag_array[NUM_LINES-1:0];
    reg         valid_array[NUM_LINES-1:0];
    reg [31:0]  data_array[NUM_LINES-1:0][LINE_SIZE_WORDS-1:0];

    // FSM States
    localparam S_IDLE        = 2'b00;
    localparam S_MEM_WAIT    = 2'b01;
    localparam S_MEM_FILL    = 2'b10;

    reg [1:0] state;
    reg [2:0] fill_counter;

    // Hit Logic
    wire hit = valid_array[cpu_index] && (tag_array[cpu_index] == cpu_tag);

    // FSM Logic
    always @(posedge clk) begin
        if (!reset) begin // Active-low reset
            for (integer i = 0; i < NUM_LINES; i = i + 1) begin
                valid_array[i] = 1'b0; // FIX: Use blocking assignment
            end
            state <= S_IDLE;
            cpu_busy <= 1'b0;
            mem_rstrb <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    mem_rstrb <= 1'b0;
                    if (cpu_req) begin
                        if (hit) begin
                            cpu_rdata <= data_array[cpu_index][cpu_offset];
                            cpu_busy <= 1'b0;
                        end else begin
                            cpu_busy <= 1'b1;
                            fill_counter <= 3'b0;
                            mem_addr <= {cpu_addr[31:5], 5'b0};
                            mem_rstrb <= 1'b1;
                            state <= S_MEM_WAIT;
                        end
                    end else begin
                        cpu_busy <= 1'b0;
                    end
                end

                S_MEM_WAIT: begin
                    mem_rstrb <= 1'b0;
                    if (!mem_rbusy) begin
                        data_array[cpu_index][fill_counter] <= mem_rdata;
                        fill_counter <= fill_counter + 1;
                        state <= S_MEM_FILL;
                    end
                end

                S_MEM_FILL: begin
                    mem_addr <= mem_addr + 4;
                    mem_rstrb <= 1'b1;

                    if (!mem_rbusy) begin
                        data_array[cpu_index][fill_counter] <= mem_rdata;
                        
                        // FIX: Specify width of the literal '7' to avoid width warning
                        if (fill_counter == 3'(LINE_SIZE_WORDS - 1)) begin
                            tag_array[cpu_index]   <= cpu_tag;
                            valid_array[cpu_index] <= 1'b1;
                            cpu_rdata <= data_array[cpu_index][cpu_offset];
                            cpu_busy <= 1'b0;
                            state <= S_IDLE;
                        end else begin
                            fill_counter <= fill_counter + 1;
                        end
                    end
                end
                
                // FIX: Add default case to make the case statement complete
                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end
endmodule
