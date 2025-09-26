// rtl/cache_interconnect.v
/*******************************************************************/
// Cache Interconnect / Arbiter
// Manages shared access to main memory for ICACHE and DCACHE.
// DCACHE has priority.
/*******************************************************************/
module cache_interconnect (

    // ICACHE Interface
    input      [31:0]   icache_addr,
    input               icache_rstrb,
    output reg [31:0]   icache_rdata,
    output reg          icache_busy,

    // DCACHE Interface
    input      [31:0]   dcache_addr,
    input      [31:0]   dcache_wdata,
    input      [3:0]    dcache_wmask,
    input               dcache_rstrb,
    input               dcache_wstrb,
    output reg [31:0]   dcache_rdata,
    output reg          dcache_busy,

    // Main Memory Interface
    output reg [31:0]   mem_addr,
    output reg [31:0]   mem_wdata,
    output reg [3:0]    mem_wmask,
    output reg          mem_rstrb,
    output reg          mem_wstrb,
    input      [31:0]   mem_rdata,
    input               mem_busy
);

    always @* begin
        // By default, outputs are idle
        mem_addr = 32'b0;
        mem_wdata = 32'b0;
        mem_wmask = 4'b0;
        mem_rstrb = 1'b0;
        mem_wstrb = 1'b0;
        
        icache_rdata = mem_rdata;
        dcache_rdata = mem_rdata;

        icache_busy = mem_busy;
        dcache_busy = mem_busy;

        // DCACHE has priority
        if (dcache_rstrb || dcache_wstrb) begin
            mem_addr = dcache_addr;
            mem_wdata = dcache_wdata;
            mem_wmask = dcache_wmask;
            mem_rstrb = dcache_rstrb;
            mem_wstrb = dcache_wstrb;
            icache_busy = 1'b1; // Keep ICACHE waiting
        end else if (icache_rstrb) begin
            mem_addr = icache_addr;
            mem_rstrb = icache_rstrb;
            dcache_busy = 1'b1; // Keep DCACHE waiting
        end
    end

endmodule
