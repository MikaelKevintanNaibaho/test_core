/*******************************************************************/
// Load/Store Unit (LSU)
//
// * Handles byte/half-word alignment for memory accesses.
// * Performs sign-extension for signed LOAD instructions.
// * Generates the memory write mask for STORE instructions.
// * Purely combinatorial logic.
/*******************************************************************/

module lsu (
    // Inputs
    input [31:0]    mem_rdata,          // Data read from memory
    input [31:0]    rs2_data,           // Data to be stored (from register rs2) 
    input [1:0]     addr_lsb,           // Lower two bits of the memory adress
    input [2:0]     funct3,             // instruction's funct3 field

    // Outputs
    output [31:0]   LOAD_data_out,      // Final data from the register file after a LOAD
    output [31:0]   STORE_wdata_out,    // Write mask for memory for a STORE
    output [3:0]    STORE_wmask_out     // Dta formatted for memory write for a STORE

);

    // Decode acess type from funct3
    wire is_byte_access     = (funct3[1:0] == 2'b00);
    wire is_half_access     = (funct3[1:0] == 2'b01);
    wire is_signed_load     = (~funct3[2]);

    // ---- LOAD logic ----
    
    // select the correct half-word from the 32-bit memory data
    wire [15:0] load_halfword = addr_lsb[1] ? mem_rdata[31:16] : mem_rdata[15:0];

    // select the correct bute from the chosen half-word
    wire [7:0] load_byte = addr_lsb[0] ? load_halfword[15:8] : load_halfword[7:0];

    // Determine the sign bit for signed loads
    wire load_sign = is_signed_load & (is_byte_access ? load_byte[7] : load_halfword[15]);

    // Mux and sign-extend to produce the final 32-bit result
    assign LOAD_data_out =
        is_byte_access ? {{24{load_sign}}, load_byte} :
        is_half_access ? {{16{load_sign}}, load_halfword} : mem_rdata;

    // ------ STORE LOGIC -----
    
    // for byte/half-word stores, we replicate the data across the 32-bit bus.
    // the memory peripheral will use the write mask to update only the
    // correct bytes.
    assign STORE_wdata_out =
        is_byte_access ? {4{rs2_data[7:0]}} :
        is_half_access ? {2{rs2_data[15:0]}} : rs2_data;

    // generate the 4-bit write mask based on access size and adress
    assign STORE_wmask_out = 
        is_byte_access ? (4'b0001 << addr_lsb) :
        is_half_access ? (addr_lsb[1] ? 4'b1100 : 4'b0011) : 4'b1111;

endmodule
