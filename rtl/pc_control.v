/***************yy****************************************************/
// PC Control Unit
//
// * Contains the Program Counter (PC) register.
// * Update the PC based on an input value.
// * Calculate PC + 4 for sequential execution and link_adresses.
/*******************************************************************/

module pc_control #(
    parameter ADDR_WIDTH = 24,
    parameter RESET_ADDR = 32'h00000000
) (
    input                           clk,
    input                           reset,        // active-low reset

    // Control
    input                           load_en,
    input       [ADDR_WIDTH-1:0]    PC_in,

    // Outputs
    output reg  [ADDR_WIDTH-1:0]    PC_out,
    output      [ADDR_WIDTH-1:0]    PC_plus_4_out
);

    // the PC register updates on posedge clk when enebled, or on reset
    always @(posedge clk) begin
        if (!reset) begin
            PC_out <= RESET_ADDR[ADDR_WIDTH-1:0];
        end else if (load_en) begin
            PC_out <= PC_in;
        end
    end

    // Combinatorially calculate PC + 4 
    assign PC_plus_4_out = PC_out + 4;
endmodule



