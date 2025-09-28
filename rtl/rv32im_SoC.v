/*******************************************************************/
// RV32IM SoC Top-Level
//
// * Instantiates the CPU core, caches, and interconnect.
// * Connects the components to form the complete system.
/*******************************************************************/

module rv32im_SoC (
    input clk,
    input reset,

    // Interface to main memory
    output [31:0] mem_addr,
    output [31:0] mem_wdata,
    output [3:0] mem_wmask,
    input [31:0] mem_rdata,
    output mem_rstrb,
    input mem_rbusy,
    input mem_wbusy
);

    // Core <-> ICache connections
    wire [31:0] core_icache_addr;
    wire core_icache_req;
    wire [31:0] core_icache_rdata;
    wire core_icache_ready;

    // Core <-> DCache connections
    wire [31:0] core_dcache_addr;
    wire [31:0] core_dcache_wdata;
    wire core_dcache_wen;
    wire core_dcache_ren;
    wire [31:0] core_dcache_rdata;
    wire core_dcache_ready;

    // ICache <-> Interconnect connections
    wire [31:0] icache_iomem_addr;
    wire icache_iomem_req;
    wire [31:0] icache_iomem_rdata;
    wire icache_iomem_ready;

    // DCache <-> Interconnect connections
    wire [31:0] dcache_iomem_addr;
    wire [31:0] dcache_iomem_wdata;
    wire dcache_iomem_wen;
    wire dcache_iomem_ren;
    wire [31:0] dcache_iomem_rdata;
    wire dcache_iomem_ready;

    // 1. Instantiate the CPU Core
    rv32im cpu_core_inst (
        .clk(clk),
        .reset(reset),
        .icache_addr(core_icache_addr),
        .icache_req(core_icache_req),
        .icache_rdata(core_icache_rdata),
        .icache_ready(core_icache_ready),
        .dcache_addr(core_dcache_addr),
        .dcache_wdata(core_dcache_wdata),
        .dcache_wen(core_dcache_wen),
        .dcache_ren(core_dcache_ren),
        .dcache_rdata(core_dcache_rdata),
        .dcache_ready(core_dcache_ready)
    );

    // 2. Instantiate the Instruction Cache
    icache icache_inst (
        .clk(clk),
        .reset(reset),
        .cpu_addr(core_icache_addr),
        .cpu_req(core_icache_req),
        .cpu_rdata(core_icache_rdata),
        .cpu_ready(core_icache_ready),
        .iomem_addr(icache_iomem_addr),
        .iomem_req(icache_iomem_req),
        .iomem_rdata(icache_iomem_rdata),
        .iomem_ready(icache_iomem_ready)
    );

    // 3. Instantiate the Data Cache
    dcache dcache_inst (
        .clk(clk),
        .reset(reset),
        .cpu_addr(core_dcache_addr),
        .cpu_wdata(core_dcache_wdata),
        .cpu_wen(core_dcache_wen),
        .cpu_ren(core_dcache_ren),
        .cpu_rdata(core_dcache_rdata),
        .cpu_ready(core_dcache_ready),
        .iomem_addr(dcache_iomem_addr),
        .iomem_wdata(dcache_iomem_wdata),
        .iomem_wen(dcache_iomem_wen),
        .iomem_ren(dcache_iomem_ren),
        .iomem_rdata(dcache_iomem_rdata),
        .iomem_ready(dcache_iomem_ready)
    );

    // 4. Instantiate the Interconnect
    interconnect_cache interconnect_inst (
        .clk(clk),
        .reset(reset),
        .icache_addr(icache_iomem_addr),
        .icache_req(icache_iomem_req),
        .icache_rdata(icache_iomem_rdata),
        .icache_ready(icache_iomem_ready),
        .dcache_addr(dcache_iomem_addr),
        .dcache_wdata(dcache_iomem_wdata),
        .dcache_wen(dcache_iomem_wen),
        .dcache_ren(dcache_iomem_ren),
        .dcache_rdata(dcache_iomem_rdata),
        .dcache_ready(dcache_iomem_ready),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wmask(mem_wmask),
        .mem_rstrb(mem_rstrb),
        .mem_rdata(mem_rdata),
        .mem_rbusy(mem_rbusy),
        .mem_wbusy(mem_wbusy)
    );

endmodule
