/*******************************************************************/
// RV32IM Core
//
// * This is the main processor core.
// * Interfaces with I-Cache for instruction fetches.
// * Interfaces with D-Cache for loads and stores.
/*******************************************************************/

module rv32im(
    input clk,
    input reset,        // active-low reset

    // I-Cache Interface
    output [31:0]   icache_addr,
    output          icache_req,
    input [31:0]    icache_rdata,
    input           icache_ready,

    // D-Cache Interface
    output [31:0]   dcache_addr,
    output [31:0]   dcache_wdata,
    output [3:0]    dcache_wmask, 
    output          dcache_wen,
    output          dcache_ren,
    input [31:0]    dcache_rdata,
    input           dcache_ready
);
    // --- Parameters ---
    parameter ADDR_WIDTH = 24;
    parameter RESET_ADDR = 32'h00000000;

    // --- Internal Wires and Registers ---
    reg [31:0] instr_reg;
    wire [3:0] fsm_state;
    wire [3:0] WAIT_INSTR = 4'b0010;

    // PC Control signals
    wire [ADDR_WIDTH-1:0]   pc_out;
    wire [ADDR_WIDTH-1:0]   pc_plus_4;
    wire [ADDR_WIDTH-1:0]   pc_next;
    wire                    pc_load_en;

    // Instruction decoding signals
    wire [4:0]  rdId;
    wire [4:0]  rs1Id;
    wire [4:0]  rs2Id;
    wire [2:0]  funct3;
    wire        isLoad, isStore, isALUimm, isALUreg, isBranch, isJALR, isJAL, isLUI, isAUIPC;
    wire        isDivide, is_rem, is_unsigned_div;
    wire        isALU;
    wire        is_mul_div;

    // Register file signals
    wire [31:0] rf_read_data1;
    wire [31:0] rf_read_data2;
    wire [31:0] rf_write_data;
    wire        rf_write_en_from_fsm;
    wire        rf_write_en;

    // ALU signals
    wire [31:0] alu_in1;
    wire [31:0] alu_in2;
    wire [31:0] alu_out;
    wire        alu_busy;
    wire        alu_op_valid;
    wire        alu_eq, alu_lt, alu_ltu;

    // LSU signals
    wire [31:0] lsu_load_data_out;
    wire [31:0] lsu_store_wdata_out;
    wire [3:0]  lsu_store_wmask_out;

    // Immediate value wires
    wire [31:0] Iimm, Simm, Bimm, Uimm, Jimm;

    // --- Instruction Decoding ---
    assign rdId    = instr_reg[11:7];
    assign rs1Id   = instr_reg[19:15];
    assign rs2Id   = instr_reg[24:20];
    assign funct3  = instr_reg[14:12];
    assign isLoad   = (instr_reg[6:0] == 7'b0000011);
    assign isALUimm = (instr_reg[6:0] == 7'b0010011);
    assign isAUIPC  = (instr_reg[6:0] == 7'b0010111);
    assign isStore  = (instr_reg[6:0] == 7'b0100011);
    assign isALUreg = (instr_reg[6:0] == 7'b0110011);
    assign isLUI    = (instr_reg[6:0] == 7'b0110111);
    assign isBranch = (instr_reg[6:0] == 7'b1100011);
    assign isJALR   = (instr_reg[6:0] == 7'b1100111);
    assign isJAL    = (instr_reg[6:0] == 7'b1101111);
    assign isALU = isALUreg | isALUimm;
    
    // Decoding for M-extension
    assign is_mul_div = isALUreg && instr_reg[25];
    assign isDivide = is_mul_div && funct3[2];
    assign is_rem = isDivide && funct3[1];
    assign is_unsigned_div = isDivide && funct3[0];

    // Immediate value decoding
    assign Iimm = {{21{instr_reg[31]}}, instr_reg[30:20]};
    assign Simm = {{21{instr_reg[31]}}, instr_reg[30:25], instr_reg[11:7]};
    assign Bimm = {{20{instr_reg[31]}}, instr_reg[7], instr_reg[30:25], instr_reg[11:8], 1'b0};
    assign Uimm = {instr_reg[31:12], 12'b0};
    assign Jimm = {{12{instr_reg[31]}}, instr_reg[19:12], instr_reg[20], instr_reg[30:21], 1'b0};


    // --- Module Instantiations ---

    // 1. PC Control Unit
    pc_control #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .RESET_ADDR(RESET_ADDR)
    ) pc_control_inst (
        .clk(clk),
        .reset(reset),
        .load_en(pc_load_en),
        .PC_in(pc_next),
        .PC_out(pc_out),
        .PC_plus_4_out(pc_plus_4)
    );

    // 2. Control Unit (FSM)
    control_unit control_unit_inst (
        .clk(clk),
        .reset(reset),
        .isLoad(isLoad),
        .isStore(isStore),
        .isDivide(isDivide),
        .aluBusy(alu_busy),
        .icache_ready(icache_ready),
        .dcache_ready(dcache_ready),
        .pc_load_en(pc_load_en),
        .alu_op_valid(alu_op_valid),
        .writeBack_en(rf_write_en_from_fsm),
        .icache_req(icache_req),
        .dcache_ren(dcache_ren),
        .dcache_wen(dcache_wen),
        .state_out(fsm_state)
    );

    // 3. Register File
    regfile regfile_inst (
        .clk(clk),
        .write_en(rf_write_en),
        .write_addr(rdId),
        .write_data(rf_write_data),
        .read_addr1(rs1Id),
        .read_data1(rf_read_data1),
        .read_addr2(rs2Id),
        .read_data2(rf_read_data2)
    );

    // 4. ALU
    alu alu_inst (
        .clk(clk),
        .op_valid(alu_op_valid),
        .funct3(funct3),
        .instr_30(instr_reg[30]),
        .instr_5(instr_reg[5]),
        .is_mul_div(is_mul_div),
        .is_divide(isDivide),
        .is_rem(is_rem),
        .is_unsigned(is_unsigned_div),
        .in1(alu_in1),
        .in2(alu_in2),
        .out(alu_out),
        .busy(alu_busy),
        .eq(alu_eq),
        .lt(alu_lt),
        .ltu(alu_ltu)
    );

    // 5. Load/Store Unit (LSU)
    lsu lsu_inst (
        .mem_rdata(dcache_rdata),
        .rs2_data(rf_read_data2),
        .addr_lsb(dcache_addr[1:0]),
        .funct3(funct3),
        .LOAD_data_out(lsu_load_data_out),
        .STORE_wdata_out(lsu_store_wdata_out),
        .STORE_wmask_out(lsu_store_wmask_out)
    );

    always @(posedge clk) begin
        if (fsm_state == WAIT_INSTR && icache_ready) begin
            instr_reg <= icache_rdata;
        end
    end

    //--- Glue Logic (Connecting the modules) ---

    // ALU input selection
    assign alu_in1 = rf_read_data1;
    assign alu_in2 = (isALUreg || isBranch) ? rf_read_data2 : Iimm;

    // Branch predicate logic
    wire predicate =
        (funct3 == 3'b000 && alu_eq)  || // BEQ
        (funct3 == 3'b001 && ~alu_eq) || // BNE
        (funct3 == 3'b100 && alu_lt)  || // BLT
        (funct3 == 3'b101 && ~alu_lt) || // BGE
        (funct3 == 3'b110 && alu_ltu) || // BLTU
        (funct3 == 3'b111 && ~alu_ltu);  // BGEU

    // Next PC calculation
    wire [ADDR_WIDTH-1:0] branch_target; 
    wire [ADDR_WIDTH-1:0] jal_target;
    wire [ADDR_WIDTH-1:0] jalr_target;
    wire [31:0] jalr_sum;
    
    assign branch_target = pc_out + Bimm[ADDR_WIDTH-1:0];
    assign jal_target    = pc_out + Jimm[ADDR_WIDTH-1:0];
    assign jalr_sum      = rf_read_data1 + Iimm;
    assign jalr_target   = jalr_sum[ADDR_WIDTH-1:0] & 24'hFFFFFE;
    assign pc_next =  isJALR ? jalr_target :
                     (isBranch && predicate) ? branch_target :
                      isJAL ? jal_target :
                      pc_plus_4;

    // Data to be written back to the register file
    assign rf_write_data = isLoad ? lsu_load_data_out :
                      (isJAL || isJALR) ? {{(32-ADDR_WIDTH){1'b0}}, pc_plus_4} :
                       isLUI ? Uimm :
                       isAUIPC ? ({{(32-ADDR_WIDTH){1'b0}}, pc_out} + Uimm) :
                       alu_out;

    // I-Cache and D-Cache connections
    assign icache_addr = {{(32-ADDR_WIDTH){1'b0}}, pc_out};
    wire [31:0] lsu_addr = rf_read_data1 + (isStore ? Simm : Iimm);
    assign dcache_addr  = lsu_addr;
    assign dcache_wdata = lsu_store_wdata_out;
    assign dcache_wmask = lsu_store_wmask_out; // Connect the LSU wmask

    // Final write-enable for the register file
    wire instr_writes_back = isALU | isLUI | isAUIPC | isJAL | isJALR | isLoad;
    assign rf_write_en = rf_write_en_from_fsm && instr_writes_back;

endmodule
