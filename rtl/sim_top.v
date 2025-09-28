/*******************************************************************/
// Simulation Top-Level Wrapper
//
// * Instantiates the CPU SoC (rv32im_SoC) and the Memory.
// * Connects them together.
/*******************************************************************/

module sim_top#(
    parameter string INIT_FILE = ""
)(
    input clk,
    input reset
);

    // --- Wires for SoC <-> Memory Connection ---
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_wmask;
    wire [31:0] mem_rdata;
    wire        mem_rstrb;
    wire        mem_rbusy;
    wire        mem_wbusy;

    // --- Instantiate the CPU SoC ---
    rv32im_SoC soc_inst (
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
