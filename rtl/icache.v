/*******************************************************************/
// Instruction Cache (ICACHE)
//
// * 4 KB direct-mapped cache
// * Based on the design in "Implementation of FPGA based 32-bit
//   RISC-V processor"
/*******************************************************************/

module icache (
    input clk,
    input reset,

    // Interface to the CPU core
    input [31:0] cpu_addr,
    input cpu_req,
    output reg [31:0] cpu_rdata,
    output reg cpu_ready,

    // Interface to the Interconnect/Main Memory
    output reg [31:0] iomem_addr, // CORRECTED: Was 'reg' now '[31:0]'
    output reg iomem_req,
    input [31:0] iomem_rdata,
    input iomem_ready
);

    // Cache parameters
    localparam CACHE_SIZE_KB = 4;
    localparam LINE_SIZE_WORDS = 1; // 1 word per line
    localparam NUM_LINES = (CACHE_SIZE_KB * 1024) / (LINE_SIZE_WORDS * 4);
    localparam INDEX_BITS = $clog2(NUM_LINES);
    localparam TAG_BITS = 32 - INDEX_BITS - 2; // Word-aligned addresses

    // State machine definition
    localparam CACHE_READ = 0;
    localparam MEMORY_PULL = 1;
    localparam FINISH = 2;

    reg [2:0] state;

    // Cache memory
    reg [TAG_BITS-1:0] tag_array [NUM_LINES-1:0];
    reg [31:0] data_array [NUM_LINES-1:0];
    reg valid_array [NUM_LINES-1:0];

    // Address decoding
    wire [INDEX_BITS-1:0] index = cpu_addr[INDEX_BITS+1:2];
    wire [TAG_BITS-1:0] tag = cpu_addr[31:INDEX_BITS+2];

    // Hit/miss logic
    wire hit = valid_array[index] && (tag_array[index] == tag);

    // CORRECTED: Synthesizable reset loop
    integer i;
    always @(posedge clk) begin
        if (!reset) begin
            state <= CACHE_READ;
            cpu_ready <= 1'b0;
            for (i = 0; i < NUM_LINES; i = i + 1) begin
                valid_array[i] = 1'b0;
            end
        end else begin
            case (state)
                CACHE_READ: begin
                    cpu_ready <= 1'b0;
                    if (cpu_req) begin
                        if (hit) begin
                            cpu_rdata <= data_array[index];
                            cpu_ready <= 1'b1;
                        end else begin
                            state <= MEMORY_PULL;
                            iomem_addr <= cpu_addr;
                            iomem_req <= 1'b1;
                        end
                    end
                end
                MEMORY_PULL: begin
                    iomem_req <= 1'b0;
                    if (iomem_ready) begin
                        data_array[index] <= iomem_rdata;
                        tag_array[index] <= tag;
                        valid_array[index] <= 1'b1;
                        state <= FINISH;
                    end
                end
                FINISH: begin
                    cpu_rdata <= iomem_rdata;
                    cpu_ready <= 1'b1;
                    state <= CACHE_READ;
                end
            endcase
        end
    end

endmodule
