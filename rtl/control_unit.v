/*******************************************************************/
//  Control Unit (FSM)
//
// * Contains the main processor state machine.
// * Takes status signals from the datapath.
// * Generates timed control signals for all other modules.
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
    output pc_load_en,      // Enable for PC_Control to load a new adress
    output alu_op_valid,    // Strobe to start a multi-cyle ALU op (division)
    output writeBack_en,    // Enable for regfile write port
    output mem_addr_sel,    // Mux select for mem_addr (0=PC, 1=LSU_addr)
    output mem_rstrb,       // Memory read strobe
    output mem_write_en,    // Memory write enable
    output [NB_STATES-1:0] state_out

);

    // --- State Machine Definition ---
    localparam FETCH_INSTR_bit          = 0;
    localparam WAIT_INSTR_bit           = 1;
    localparam EXECUTE_INSTR_bit        = 2;
    localparam WAIT_ALU_OR_MEM_bit      = 3;
    localparam NB_STATES                = 4;

    localparam FETCH_INSTR      = 1 << FETCH_INSTR_bit;
    localparam WAIT_INSTR       = 1 << WAIT_INSTR_bit;
    localparam EXECUTE          = 1 << EXECUTE_INSTR_bit;
    localparam WAIT_ALU_OR_MEM  = 1 << WAIT_ALU_OR_MEM_bit;

    (* onehot *)
    reg [NB_STATES-1:0] state;

    // -- combinatorial control signal generation ---
    // There signals are determined by the current state and inputs.

    // the PC is updated in the EXECUTE state.
    assign pc_load_en = (state == EXECUTE);

    // multi-cyle ALU operation start in the EXECUTE state.
    assign alu_op_valid = (state == EXECUTE) & isDivide; // currently only division in multi-cyle

    // the memory address is the PC during fetch, and the LSU's result
    // otherwise.
    assign mem_addr_sel = (state == EXECUTE) && (isLoad || isStore);

    // memory read is strobed for instruction fetch or for a load instruction
    assign mem_rstrb = (state == FETCH_INSTR) || (state == EXECUTE) && isLoad;

    // memory write is enabled only during the EXECUTE state for a strore
    // instruction
    assign mem_write_en = (state == EXECUTE) && isStore;

    // write-back to the register file happens after the EXECUTE of after
    // waiting.
    // Note : the top-level module will still need to check if the instruction
    // is one that actually writes back (e.g not a branch or store).
    assign writeBack_en = (state == EXECUTE) || (state == WAIT_ALU_OR_MEM);

    // --- state transition logic ---
    wire needToWait = isLoad || isStore || isDivide;

    always @(posedge clk) begin
        if (!reset) begin
            // on reset, wait for memory to be rady before starting.
            state <= WAIT_ALU_OR_MEM;
        end else begin
            // state transitions are discribed as a case statement.
            case (state)
                FETCH_INSTR: begin
                    state <= WAIT_INSTR;
                end

                WAIT_INSTR: begin
                    if(!mem_rbusy) begin
                        state <= EXECUTE;
                    end
                end 

                EXECUTE: begin
                    if(needToWait) begin
                        state <= WAIT_ALU_OR_MEM;
                    end else begin
                        state <= FETCH_INSTR;
                    end
                end

                WAIT_ALU_OR_MEM: begin
                    if (!aluBusy && !mem_rbusy && !mem_wbusy) begin
                        state <= FETCH_INSTR;
                    end
                end

                default: begin
                    state <= FETCH_INSTR;
                end
            endcase
        end
    end
    assign state_out = state;
endmodule

