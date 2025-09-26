/*******************************************************************/
// Simple Memory Module for Simulation
//
// * Implements a single-port synchronous-write, asynchronous-read RAM.
// * Can be pre-loaded with data from a hex file.
// * Simulates a one-cycle read latency.
/*******************************************************************/

module memory #(
    parameter MEM_SIZE_WORDS = 8192, // 8192 words = 32 KB
    parameter string INIT_FILE      = ""     // Path to the hex file to load
) (
    input                       clk,

    // Interface to the CPU
    input      [31:0]           mem_addr,
    input      [31:0]           mem_wdata,
    input      [3:0]            mem_wmask,
    output reg [31:0]           mem_rdata,
    input                       mem_rstrb,
    output                      mem_rbusy,
    output                      mem_wbusy // Not used in this simple model
);

    // Core memory block: an array of 32-bit registers.
    // Use `MEM_SIZE_WORDS-1` for the array index.
    reg [31:0] mem [MEM_SIZE_WORDS-1:0];

    // --- Memory Initialization ---
    // At the start of the simulation, if an INIT_FILE is specified,
    // load its contents into our memory block.
    initial begin
        if (INIT_FILE != "") begin
            $display("Memory: Initializing from file: %s", INIT_FILE);
            $readmemh(INIT_FILE, mem);
        end
    end

    // The memory address is word-aligned, so we ignore the lower 2 bits.
    wire [31:0] word_addr = mem_addr >> 2;

    // --- Synchronous Write Logic ---
    // This block triggers on the positive edge of the clock.
    always @(posedge clk) begin
        // A write occurs if any bit in the write mask is set.
        if (|mem_wmask) begin
            // Check each byte mask and update the corresponding byte in memory.
            if (mem_wmask[0]) mem[word_addr][7:0]   <= mem_wdata[7:0];
            if (mem_wmask[1]) mem[word_addr][15:8]  <= mem_wdata[15:8];
            if (mem_wmask[2]) mem[word_addr][23:16] <= mem_wdata[23:16];
            if (mem_wmask[3]) mem[word_addr][31:24] <= mem_wdata[31:24];
        end
    end

    // --- Asynchronous Read with 1-Cycle Latency ---
    // The read itself is asynchronous, but we latch the data and control
    // the busy signal to simulate a one-cycle delay.
    
    // Asynchronously read from the memory array.
    wire [31:0] read_data_comb = mem[word_addr];

    // Latch the read data when a read strobe is active.
    always @(posedge clk) begin
        if (mem_rstrb) begin
            mem_rdata <= read_data_comb;
        end
    end

    // `mem_rbusy` signal generation
    reg rbusy_reg;
    always @(posedge clk) begin
        rbusy_reg <= mem_rstrb;
    end
    assign mem_rbusy = rbusy_reg;

    // This simple memory model has no write busy state.
    assign mem_wbusy = 1'b0;

endmodule
