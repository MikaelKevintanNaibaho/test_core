/*******************************************************************/
// Data Cache (DCACHE)
//
// * 1 KB 2-way set-associative cache
// * Based on the design in "Implementation of FPGA based 32-bit
//   RISC-V processor"
/*******************************************************************/

module dcache (
    input clk,
    input reset,

    // Interface to the CPU core
    input [31:0] cpu_addr,
    input [31:0] cpu_wdata,
    input cpu_wen,
    input cpu_ren,
    output reg [31:0] cpu_rdata,
    output reg cpu_ready,

    // Interface to the Interconnect/Main Memory
    output reg [31:0] iomem_addr,
    output reg [31:0] iomem_wdata,
    output reg iomem_wen,
    output reg iomem_ren,
    input [31:0] iomem_rdata,
    input iomem_ready
);

    // Cache parameters
    localparam CACHE_SIZE_KB = 1;
    localparam NUM_WAYS = 2;
    localparam LINE_SIZE_WORDS = 1;
    localparam NUM_SETS = (CACHE_SIZE_KB * 1024) / (LINE_SIZE_WORDS * 4 * NUM_WAYS);
    localparam INDEX_BITS = $clog2(NUM_SETS);
    localparam TAG_BITS = 32 - INDEX_BITS - 2;

    // State machine definition
    localparam HIT = 0;
    localparam MEMORY_WRITE = 1;
    localparam MEMORY_READ = 2;
    localparam FINISH = 3;

    reg [2:0] state;

    // Cache memory
    reg [TAG_BITS-1:0] tag_array [NUM_WAYS-1:0][NUM_SETS-1:0];
    reg [31:0] data_array [NUM_WAYS-1:0][NUM_SETS-1:0];
    reg valid_array [NUM_WAYS-1:0][NUM_SETS-1:0];
    reg dirty_array [NUM_WAYS-1:0][NUM_SETS-1:0];
    reg lru_array [NUM_SETS-1:0]; // 0: way 0 is LRU, 1: way 1 is LRU

    // Address decoding
    wire [INDEX_BITS-1:0] index = cpu_addr[INDEX_BITS+1:2];
    wire [TAG_BITS-1:0] tag = cpu_addr[31:INDEX_BITS+2];

    // Hit/miss logic
    wire hit0 = valid_array[0][index] && (tag_array[0][index] == tag);
    wire hit1 = valid_array[1][index] && (tag_array[1][index] == tag);
    wire hit = hit0 | hit1;

    reg [31:0] saved_wdata;
    reg saved_wen;

    // CORRECTED: Synthesizable reset loop
    integer j;
    always @(posedge clk) begin
        if (!reset) begin
            state <= HIT;
            cpu_ready <= 1'b0;
            for (j = 0; j < NUM_SETS; j = j + 1) begin
                valid_array[0][j] = 1'b0;
                valid_array[1][j] = 1'b0;
                dirty_array[0][j] = 1'b0;
                dirty_array[1][j] = 1'b0;
                lru_array[j] = 1'b0;
            end
        end else begin
            case (state)
                HIT: begin
                    cpu_ready <= 1'b0;
                    if (cpu_ren || cpu_wen) begin
                        if (hit) begin
                            if (cpu_ren) begin
                                cpu_rdata <= hit0 ? data_array[0][index] : data_array[1][index];
                            end
                            if (cpu_wen) begin
                                if (hit0) begin
                                    data_array[0][index] <= cpu_wdata;
                                    dirty_array[0][index] <= 1'b1;
                                end else begin
                                    data_array[1][index] <= cpu_wdata;
                                    dirty_array[1][index] <= 1'b1;
                                end
                            end
                            lru_array[index] <= hit0; // Update LRU
                            cpu_ready <= 1'b1;
                        end else begin // Miss
                            saved_wdata <= cpu_wdata;
                            saved_wen <= cpu_wen;
                            if (dirty_array[lru_array[index]][index]) begin
                                state <= MEMORY_WRITE;
                                iomem_addr <= {tag_array[lru_array[index]][index], index, 2'b00};
                                iomem_wdata <= data_array[lru_array[index]][index];
                                iomem_wen <= 1'b1;
                            end else begin
                                state <= MEMORY_READ;
                                iomem_addr <= cpu_addr;
                                iomem_ren <= 1'b1;
                            end
                        end
                    end
                end
                MEMORY_WRITE: begin
                    iomem_wen <= 1'b0;
                    if (iomem_ready) begin
                        state <= MEMORY_READ;
                        iomem_addr <= cpu_addr;
                        iomem_ren <= 1'b1;
                    end
                end
                MEMORY_READ: begin
                    iomem_ren <= 1'b0;
                    if (iomem_ready) begin
                        if (saved_wen) begin
                            data_array[lru_array[index]][index] <= saved_wdata;
                            dirty_array[lru_array[index]][index] <= 1'b1;
                        end else begin
                            data_array[lru_array[index]][index] <= iomem_rdata;
                            dirty_array[lru_array[index]][index] <= 1'b0;
                        end
                        tag_array[lru_array[index]][index] <= tag;
                        valid_array[lru_array[index]][index] <= 1'b1;
                        lru_array[index] <= ~lru_array[index];
                        state <= FINISH;
                    end
                end
                FINISH: begin
                    cpu_rdata <= saved_wen ? 32'b0 : data_array[~lru_array[index]][index];
                    cpu_ready <= 1'b1;
                    state <= HIT;
                end
            endcase
        end
    end

endmodule
