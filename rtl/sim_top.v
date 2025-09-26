/*******************************************************************/
// Simulation Top-Level Wrapper
//
// * Instantiates the CPU (rv32im) and the Memory.
// * Connects them together.
// * This is the module that Verilator will compile.
/*******************************************************************/

module sim_top#(
    parameter string INIT_FILE = ""
)(
    input clk,
    input reset
);

    // --- CPU <-> ICACHE wires ---
    wire [31:0] cpu_imem_addr;
    wire [31:0] cpu_imem_rdata;
    wire        cpu_imem_rstrb;
    wire        cpu_imem_busy;

    // --- CPU <-> DCACHE wires --
    wire [31:0] cpu_dmem_addr;
    wire [31:0] cpu_dmem_wdata;
    wire [3:0]  cpu_dmem_wmask;
    wire [31:0] cpu_dmem_rdata;
    wire        cpu_dmem_rstrb;
    wire        cpu_dmem_wstrb;
    wire        cpu_dmem_busy;

    // --- Cache <-> Interconnect wires
    wire [31:0] icache_mem_addr;
    wire [31:0] icache_mem_rdata;
    wire        icache_mem_rstrb;
    wire        icache_mem_busy;

    wire [31:0] dcache_mem_addr;
    wire [31:0] dcache_mem_wdata;
    wire [3:0]  dcache_mem_wmask;
    wire        dcache_mem_rstrb;
    wire        dcache_mem_wstrb;
    wire [31:0] dcache_mem_rdata;
    wire        dcache_mem_busy;

    // --- Interconnect <-> Memory Wires ---
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_wmask;
    wire        mem_rstrb;
    wire        mem_wstrb;
    wire [31:0] mem_rdata;
    wire        mem_busy;
    // --- Instantiate the CPU Core ---
    rv32im cpu_inst (
        .clk(clk),
        .reset(reset),
        .imem_addr(cpu_imem_addr),
        .imem_rdata(cpu_imem_rdata),
        .imem_rstrb(cpu_imem_rstrb),
        .imem_busy(cpu_imem_busy),
        .dmem_addr(cpu_dmem_addr),
        .dmem_wdata(cpu_dmem_wdata),
        .dmem_wmask(cpu_dmem_wmask),
        .dmem_rdata(cpu_dmem_rdata),
        .dmem_rstrb(cpu_dmem_rstrb),
        .dmem_wstrb(cpu_dmem_wstrb),
        .dmem_busy(cpu_dmem_busy)
    );

    // --- Instantiate icache
    icache icache_inst(
        .clk(clk),
        .reset(reset),

        // connect to CPU
        .cpu_addr(cpu_imem_addr),
        .cpu_req(cpu_imem_rstrb),
        .cpu_rdata(cpu_imem_rdata),
        .cpu_busy(cpu_imem_busy),

        // Connect to Memory
        .mem_addr(icache_mem_addr),
        .mem_rstrb(icache_mem_rstrb),
        .mem_rdata(icache_mem_rdata),
        .mem_rbusy(icache_mem_busy)
    );

    // -- Instantiate dcache
    dcache dcache_inst(
        .clk(clk),
        .reset(reset),
        .cpu_addr(cpu_dmem_addr),
        .cpu_wdata(cpu_dmem_wdata),
        .cpu_wmask(cpu_dmem_wmask),
        .cpu_read_req(cpu_dmem_rstrb),
        .cpu_write_req(cpu_dmem_wstrb),
        .cpu_rdata(cpu_dmem_rdata),
        .cpu_busy(cpu_dmem_busy),
        .mem_addr(dcache_mem_addr),
        .mem_wdata(dcache_mem_wdata),
        .mem_wmask(dcache_mem_wmask),
        .mem_read_req(dcache_mem_rstrb),
        .mem_write_req(dcache_mem_wstrb),
        .mem_rdata(dcache_mem_rdata),
        .mem_busy(dcache_mem_busy)
    );

    // --- Instantiate Interconnect ---
    cache_interconnect interconnect_inst (
        .icache_addr(icache_mem_addr), .icache_rstrb(icache_mem_rstrb),
        .icache_rdata(icache_mem_rdata), .icache_busy(icache_mem_busy),
        .dcache_addr(dcache_mem_addr), .dcache_wdata(dcache_mem_wdata),
        .dcache_wmask(dcache_mem_wmask), .dcache_rstrb(dcache_mem_rstrb),
        .dcache_wstrb(dcache_mem_wstrb), .dcache_rdata(dcache_mem_rdata),
        .dcache_busy(dcache_mem_busy), .mem_addr(mem_addr), .mem_wdata(mem_wdata),
        .mem_wmask(mem_wmask), .mem_rstrb(mem_rstrb), .mem_wstrb(mem_wstrb), // Note: mem_wstrb
        .mem_rdata(mem_rdata), .mem_busy(mem_busy)
    );

    // --- Instantiate the Memory ---
    // The INIT_FILE parameter is passed from the C++ testbench via a compiler define.
    memory #(
        .INIT_FILE(INIT_FILE)
    ) memory_inst (
        .clk(clk),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wmask(mem_wmask),
        .mem_rdata(mem_rdata),
        .mem_rstrb(mem_rstrb),
        .mem_rbusy(mem_busy),
        .mem_wbusy(mem_busy)
    );

endmodule
