/*******************************************************************/
// Interconnect
//
// * Arbitrates between ICACHE and DCACHE for main memory access
/*******************************************************************/

module interconnect_cache (
    input clk,
    input reset,

    // ICACHE interface
    input [31:0] icache_addr,
    input icache_req,
    output [31:0] icache_rdata,
    output icache_ready,

    // DCACHE interface
    input [31:0] dcache_addr,
    input [31:0] dcache_wdata,
    input dcache_wen,
    input dcache_ren,
    output [31:0] dcache_rdata,
    output dcache_ready,

    // Main memory interface
    output [31:0] mem_addr,
    output [31:0] mem_wdata,
    output [3:0] mem_wmask,
    output mem_rstrb,
    input [31:0] mem_rdata,
    input mem_rbusy,
    input mem_wbusy
);

    reg icache_turn;

    assign mem_addr = icache_turn ? icache_addr : dcache_addr;
    assign mem_wdata = dcache_wdata;
    assign mem_wmask = !icache_turn && dcache_wen ? 4'b1111 : 4'b0000;
    assign mem_rstrb = icache_req | dcache_ren;

    assign icache_rdata = mem_rdata;
    assign dcache_rdata = mem_rdata;

    assign icache_ready = icache_turn && !mem_rbusy && !mem_wbusy;
    assign dcache_ready = !icache_turn && !mem_rbusy && !mem_wbusy;

    always @(posedge clk) begin
        if (!reset) begin
            icache_turn <= 1'b1;
        end else begin
            if (icache_req) begin
                icache_turn <= 1'b1;
            end else if (dcache_ren || dcache_wen) begin
                icache_turn <= 1'b0;
            end
        end
    end

endmodule
