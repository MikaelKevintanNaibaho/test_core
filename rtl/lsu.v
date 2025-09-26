// rtl/lsu.v
/*******************************************************************/
// Load/Store Unit (LSU) - FINAL, ROBUST VERSION
//
// * Uses a single always block to prevent inferred latches.
/*******************************************************************/

module lsu (
    // Inputs
    input [31:0]    mem_rdata,
    input [31:0]    rs2_data, 
    input [1:0]     addr_lsb,
    input [2:0]     funct3,

    // Outputs
    output reg [31:0]   LOAD_data_out,
    output reg [31:0]   STORE_wdata_out,
    output reg [3:0]    STORE_wmask_out
);

    // Decode access type from funct3
    wire is_byte_access = (funct3[1:0] == 2'b00);
    wire is_half_access = (funct3[1:0] == 2'b01);
    wire is_word_access = (funct3[1:0] == 2'b10);
    wire is_signed_load = (~funct3[2]);

    // Intermediate wires for load logic
    wire [15:0] load_halfword = addr_lsb[1] ? mem_rdata[31:16] : mem_rdata[15:0];
    wire [7:0]  load_byte     = addr_lsb[0] ? load_halfword[15:8] : load_halfword[7:0];
    wire        load_sign     = is_signed_load & (is_byte_access ? load_byte[7] : load_halfword[15]);

    // A single combinatorial block for all logic
    always @* begin
        // --- Step 1: Assign default values to all outputs ---
        LOAD_data_out   = mem_rdata; // Default for word load
        STORE_wdata_out = rs2_data;  // Default for word store
        STORE_wmask_out = 4'b0000;   // Default to no write

        // --- Step 2: Handle LOAD logic ---
        if (is_byte_access) begin
            LOAD_data_out = {{24{load_sign}}, load_byte};
        end else if (is_half_access) begin
            LOAD_data_out = {{16{load_sign}}, load_halfword};
        end

        // --- Step 3: Handle STORE logic ---
        if (is_byte_access) begin
            STORE_wdata_out = {4{rs2_data[7:0]}};
            STORE_wmask_out = 4'b0001 << addr_lsb;
        end else if (is_half_access) begin
            STORE_wdata_out = {2{rs2_data[15:0]}};
            STORE_wmask_out = (addr_lsb[1] ? 4'b1100 : 4'b0011);
        end else if (is_word_access) begin // Specifically for SW
            STORE_wdata_out = rs2_data;
            STORE_wmask_out = 4'b1111;
        end
    end
    
endmodule
