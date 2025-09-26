// rtl/rv32im.v
/*******************************************************************/
// RV32IM top-level module - FINAL CORRECTED VERSION
/*******************************************************************/
module rv32im(
    input clk,
    input reset,

    // Instruction Cache Interface
    output [31:0]   imem_addr,
    input  [31:0]   imem_rdata,
    output          imem_rstrb,
    input           imem_busy,

    // Data Cache Interface
    output [31:0]   dmem_addr,
    output [31:0]   dmem_wdata,
    output [3:0]    dmem_wmask,
    input  [31:0]   dmem_rdata,
    output          dmem_rstrb,
    output          dmem_wstrb,
    input           dmem_busy
);

    parameter ADDR_WIDTH = 24;
    parameter RESET_ADDR = 32'h00000000;

    reg  [31:0] instr_reg;
    wire [3:0]  fsm_state;
    wire [ADDR_WIDTH-1:0]   pc_out, pc_plus_4, pc_next;
    wire                    pc_load_en;

    wire [4:0]  rdId    = instr_reg[11:7];
    wire [4:0]  rs1Id   = instr_reg[19:15];
    wire [4:0]  rs2Id   = instr_reg[24:20];
    wire [2:0]  funct3  = instr_reg[14:12];
    wire isLoad   = (instr_reg[6:2] == 5'b00000);
    wire isStore  = (instr_reg[6:2] == 5'b01000);
    wire isALUimm = (instr_reg[6:2] == 5'b00100);
    wire isALUreg = (instr_reg[6:2] == 5'b01100);
    wire isBranch = (instr_reg[6:2] == 5'b11000);
    wire isJALR   = (instr_reg[6:2] == 5'b11001);
    wire isJAL    = (instr_reg[6:2] == 5'b11011);
    wire isLUI    = (instr_reg[6:2] == 5'b01101);
    wire isAUIPC  = (instr_reg[6:2] == 5'b00101);
    wire isALU    = isALUreg | isALUimm;
    wire is_mul_div = isALUreg && instr_reg[25];
    wire isDivide = is_mul_div && funct3[2];
    
    wire [31:0] rf_read_data1, rf_read_data2, rf_write_data;
    wire rf_write_en_from_fsm, rf_write_en;
    wire [31:0] alu_in1, alu_in2, alu_out;
    wire alu_busy, alu_op_valid, alu_eq, alu_lt, alu_ltu;
    wire [31:0] lsu_load_data_out, lsu_store_wdata_out;
    wire [3:0]  lsu_store_wmask_out;
    wire mem_addr_sel, mem_rstrb_from_fsm, mem_write_en;
    wire [31:0] Iimm, Simm, Bimm, Uimm, Jimm;
    
    pc_control #( .ADDR_WIDTH(ADDR_WIDTH), .RESET_ADDR(RESET_ADDR) ) 
    pc_control_inst (.clk(clk), .reset(reset), .load_en(pc_load_en), .PC_in(pc_next), .PC_out(pc_out), .PC_plus_4_out(pc_plus_4));

    control_unit control_unit_inst (
        .clk(clk), .reset(reset), .isLoad(isLoad), .isStore(isStore), .isDivide(isDivide), .aluBusy(alu_busy), 
        .mem_rbusy(imem_busy), .mem_wbusy(dmem_busy), .pc_load_en(pc_load_en),
        .alu_op_valid(alu_op_valid), .writeBack_en(rf_write_en_from_fsm), .mem_addr_sel(mem_addr_sel),
        .mem_rstrb(mem_rstrb_from_fsm), .mem_write_en(mem_write_en), .state_out(fsm_state)
    );

    regfile regfile_inst (.clk(clk), .write_en(rf_write_en), .write_addr(rdId), .write_data(rf_write_data), .read_addr1(rs1Id), .read_data1(rf_read_data1), .read_addr2(rs2Id), .read_data2(rf_read_data2));
    
    alu alu_inst (
        .clk(clk), .op_valid(alu_op_valid), .funct3(funct3), .instr_30(instr_reg[30]),
        .instr_5(instr_reg[5]), .is_mul_div(is_mul_div), .is_divide(isDivide), .is_rem(isDivide && funct3[1]),
        .is_unsigned(isDivide && funct3[0]), .in1(alu_in1), .in2(alu_in2), .out(alu_out),
        .busy(alu_busy), .eq(alu_eq), .lt(alu_lt), .ltu(alu_ltu)
    );

    lsu lsu_inst (
        .mem_rdata(dmem_rdata), .rs2_data(rf_read_data2), .addr_lsb(dmem_addr[1:0]),
        .funct3(funct3), .LOAD_data_out(lsu_load_data_out), .STORE_wdata_out(lsu_store_wdata_out),
        .STORE_wmask_out(lsu_store_wmask_out)
    );

    always @(posedge clk) begin
        if (fsm_state == 4'b0010 && !imem_busy) begin
            instr_reg <= imem_rdata;
        end
    end

    assign Iimm = {{21{instr_reg[31]}}, instr_reg[30:20]};
    assign Simm = {{21{instr_reg[31]}}, instr_reg[30:25], instr_reg[11:7]};
    assign Bimm = {{20{instr_reg[31]}}, instr_reg[7], instr_reg[30:25], instr_reg[11:8], 1'b0};
    assign Uimm = {instr_reg[31:12], 12'b0};
    assign Jimm = {{12{instr_reg[31]}}, instr_reg[19:12], instr_reg[20], instr_reg[30:21], 1'b0};

    assign alu_in1 = rf_read_data1;
    assign alu_in2 = (isALUreg || isBranch) ? rf_read_data2 : Iimm;

    wire predicate = (funct3 == 3'b000 && alu_eq)  || (funct3 == 3'b001 && ~alu_eq) ||
                     (funct3 == 3'b100 && alu_lt)  || (funct3 == 3'b101 && ~alu_lt) ||
                     (funct3 == 3'b110 && alu_ltu) || (funct3 == 3'b111 && ~alu_ltu);

    wire [31:0] pc_out_32 = {{(32-ADDR_WIDTH){1'b0}}, pc_out};
    wire [31:0] jalr_sum = rf_read_data1 + Iimm;
    
    wire [31:0] pc_next_full = isJALR ? {jalr_sum[31:1], 1'b0} :
                             (isBranch && predicate) ? (pc_out_32 + Bimm) :
                             isJAL ? (pc_out_32 + Jimm) :
                             {8'b0, pc_plus_4};
    assign pc_next = pc_next_full[ADDR_WIDTH-1:0];

    assign rf_write_data = isLoad ? lsu_load_data_out :
                      (isJAL || isJALR) ? {{(32-ADDR_WIDTH){1'b0}}, pc_plus_4} :
                       isLUI ? Uimm :
                       isAUIPC ? (pc_out_32 + Uimm) :
                       alu_out;
    
    wire [31:0] lsu_addr = rf_read_data1 + (isStore ? Simm : Iimm);
    
    assign imem_addr = pc_out_32;
    assign imem_rstrb = mem_rstrb_from_fsm && !mem_addr_sel;
    assign dmem_addr = lsu_addr;
    assign dmem_wdata = lsu_store_wdata_out;
    assign dmem_wmask = mem_write_en ? lsu_store_wmask_out : 4'b0;
    assign dmem_rstrb = mem_rstrb_from_fsm && mem_addr_sel;
    assign dmem_wstrb = mem_write_en;

    wire instr_writes_back = isALU | isLUI | isAUIPC | isJAL | isJALR | isLoad;
    assign rf_write_en = rf_write_en_from_fsm && instr_writes_back;
endmodule
