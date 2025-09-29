/*******************************************************************/
//  Control Unit (FSM)
//
// * Contains the main processor state machine.
// * Generates control signals for the core and cache interfaces.
/*******************************************************************/

module control_unit(
    input clk,
    input reset,            // active-low reset

    // Status Inputs
    input isLoad,
    input isStore,
    input isDivide,
    input aluBusy,
    input icache_ready,
    input dcache_ready,

    // Control Outputs
    output pc_load_en,
    output alu_op_valid,
    output reg writeBack_en,
    output icache_req,
    output dcache_ren,
    output dcache_wen,

    output [3:0] state_out
);

    // --- State Machine Definition ---
    localparam FETCH_INSTR_bit        = 0;
    localparam WAIT_INSTR_bit         = 1;
    localparam EXECUTE_INSTR_bit      = 2;
    localparam WAIT_ALU_OR_MEM_bit    = 3;
    localparam NB_STATES              = 4;

    localparam FETCH_INSTR      = 1 << FETCH_INSTR_bit;
    localparam WAIT_INSTR       = 1 << WAIT_INSTR_bit;
    localparam EXECUTE          = 1 << EXECUTE_INSTR_bit;
    localparam WAIT_ALU_OR_MEM  = 1 << WAIT_ALU_OR_MEM_bit;

    (* onehot *)
    reg [NB_STATES-1:0] state;

    // --- Combinatorial control signal generation ---
    assign pc_load_en     = (state == EXECUTE);
    assign alu_op_valid   = (state == EXECUTE) & isDivide;
    assign icache_req     = (state == FETCH_INSTR);
    assign dcache_ren     = (state == EXECUTE) && isLoad;
    assign dcache_wen     = (state == EXECUTE) && isStore;

    // --- State transition logic ---
    wire needToWait = isLoad || isStore || isDivide;

    always @(posedge clk) begin
        if (!reset) begin
            writeBack_en <= 1'b0;
        end else begin
            writeBack_en <= (state == EXECUTE && !needToWait) || 
                            (state == WAIT_ALU_OR_MEM && isLoad && dcache_ready);
        end
        if (!reset) begin
            state <= FETCH_INSTR;
        end else begin
            case (state)
                FETCH_INSTR: begin
                    state <= WAIT_INSTR;
                end

                WAIT_INSTR: begin
                    if (icache_ready) begin
                        state <= EXECUTE;
                    end
                end 

                EXECUTE: begin
                    if (needToWait) begin
                        state <= WAIT_ALU_OR_MEM;
                    end else begin
                        state <= FETCH_INSTR;
                    end
                end

                WAIT_ALU_OR_MEM: begin
                    // Wait until the appropriate unit is no longer busy
                    if ((isLoad || isStore) && dcache_ready) begin
                        state <= FETCH_INSTR;
                    end else if (isDivide && !aluBusy) begin
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
