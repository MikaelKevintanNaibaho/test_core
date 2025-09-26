// rtl/control_unit.v
/*******************************************************************/
//  Control Unit (FSM) - Original Correct Version
/*******************************************************************/
module control_unit(
    input clk,
    input reset,            // active-low reset

    // Status Inputs
    input isLoad,
    input isStore,
    input isDivide,
    input aluBusy,
    input mem_rbusy,
    input mem_wbusy,

    // Control Outputs
    output pc_load_en,
    output alu_op_valid,
    output writeBack_en,
    output mem_addr_sel,    // Mux select for mem_addr (0=PC, 1=LSU_addr)
    output mem_rstrb,       // General memory read strobe
    output mem_write_en,    // General memory write enable
    output [3:0] state_out  // Original 4-bit state vector
);

    // --- State Machine Definition ---
    localparam FETCH_INSTR      = 4'b0001;
    localparam WAIT_INSTR       = 4'b0010;
    localparam EXECUTE          = 4'b0100;
    localparam WAIT_ALU_OR_MEM  = 4'b1000;

    reg [3:0] state;
    assign state_out = state;

    // -- Combinatorial control signal generation ---
    assign pc_load_en   = (state == EXECUTE);
    assign alu_op_valid = (state == EXECUTE) & isDivide;
    assign mem_addr_sel = (state == EXECUTE) && (isLoad || isStore);
    assign mem_rstrb    = (state == FETCH_INSTR) || ((state == EXECUTE) && isLoad);
    assign mem_write_en = (state == EXECUTE) && isStore;
    assign writeBack_en = (state == EXECUTE) || (state == WAIT_ALU_OR_MEM);

    // --- State transition logic ---
    wire needToWait = isLoad || isStore || isDivide;

    always @(posedge clk) begin
        if (!reset) begin
            state <= FETCH_INSTR;
        end else begin
            case (state)
                FETCH_INSTR: state <= WAIT_INSTR;
                WAIT_INSTR: if (!mem_rbusy) state <= EXECUTE;
                EXECUTE: if (needToWait) state <= WAIT_ALU_OR_MEM; else state <= FETCH_INSTR;
                WAIT_ALU_OR_MEM: if (!aluBusy && !mem_rbusy && !mem_wbusy) state <= FETCH_INSTR;
                default: state <= FETCH_INSTR;
            endcase
        end
    end
endmodule
