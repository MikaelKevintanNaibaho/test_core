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

    // --- Wires for CPU <-> Memory Connection ---
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_wmask;
    wire [31:0] mem_rdata;
    wire        mem_rstrb;
    wire        mem_rbusy;
    wire        mem_wbusy;

    // --- Instantiate the CPU Core ---
    rv32im cpu_inst (
        .clk(clk),
        .reset(reset),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wmask(mem_wmask),
        .mem_rdata(mem_rdata),
        .mem_rstrb(mem_rstrb),
        .mem_rbusy(mem_rbusy),
        .mem_wbusy(mem_wbusy)
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
        .mem_rbusy(mem_rbusy),
        .mem_wbusy(mem_wbusy)
    );

endmodule
