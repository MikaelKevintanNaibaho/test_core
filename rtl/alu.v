/*******************************************************************/
// ALU
// 
// * Implements all RV32IM operations.
// * Includes combinatorial logic for standard ALU ops.
// * Includes sequential logic for division.
/*******************************************************************/

module alu(
    input clk,
    
    // Control
    input            op_valid,      // Strobe to start a new operation (for division)
    input [2:0]      funct3,
    input            instr_30,       // To distinguish SUB/SRA from ADD/SRL
    input            instr_5,        // To distinguish ADD/SUB from ADDI
    input            is_mul_div,     // Is this a MUL/DIV operation (M-extension)
    input            is_divide,      // Is this a DIV/REM operation
    input            is_rem,         // Is this a REM operation
    input            is_unsigned,    // Is this an unsigned operation (DIVU/REMU/...)

    // Data
    input [31:0] in1,
    input [31:0] in2,

   // Outputs 
    output [31:0]    out,
    output           busy,
    output           eq,
    output           lt,
    output           ltu
);
    
    // One-hot funct3 for easier encoding
    (* onehot *)
    wire [7:0] funct3Is = 8'b00000001 << funct3;

    // adder and subtractor
    wire [31:0] aluPlus = in1 + in2;
    wire [32:0] aluMinus = {1'b1, ~in2} + {1'b0, in1} + 33'b1;

    // comparisons
    assign eq   = (aluMinus[31:0] == 0);
    assign lt   = (in1[31] ^ in2[31]) ? in1[31] : aluMinus[32];
    assign ltu  = aluMinus[32];

    // shifter
    wire [31:0] shifter_in = funct3Is[1] ?
        {in1[0], in1[1], in1[2], in1[3], in1[4], in1[5],
         in1[6], in1[7], in1[8], in1[9], in1[10], in1[11],
         in1[12], in1[13], in1[14], in1[15], in1[16], in1[17],
         in1[18], in1[19], in1[20], in1[21], in1[22], in1[23],
         in1[24], in1[25], in1[26], in1[27], in1[28], in1[29],
         in1[30], in1[31]} : in1;

    /* verilator lint_off WIDTH */ 
    wire [31:0] shifter = $signed({instr_30 & in1[31], shifter_in}) >>> in2[4:0];
    /* verilator lint_on WIDTH */ 

   wire [31:0] leftshift = {
     shifter[ 0], shifter[ 1], shifter[ 2], shifter[ 3], shifter[ 4], 
     shifter[ 5], shifter[ 6], shifter[ 7], shifter[ 8], shifter[ 9], 
     shifter[10], shifter[11], shifter[12], shifter[13], shifter[14], 
     shifter[15], shifter[16], shifter[17], shifter[18], shifter[19], 
     shifter[20], shifter[21], shifter[22], shifter[23], shifter[24], 
     shifter[25], shifter[26], shifter[27], shifter[28], shifter[29], 
     shifter[30], shifter[31]};

   // Multiplier
   wire isMULH                  = funct3Is[1];
   wire isMULHSU                = funct3Is[2];
   wire sign1                   = in1[31] & isMULH;
   wire sign2                   = in2[31] & (isMULH | isMULHSU);
   wire signed [32:0] signed1   = {sign1, in1};
   wire signed [32:0] signed2   = {sign2, in2};
   wire signed [63:0] multiply  = signed1 * signed2;

   // Divide (sequential)
   reg [31:0] dividend;
   reg [62:0] divisor;
   reg [31:0] quotient;
   reg [31:0] quotient_msk;

   assign busy = |quotient_msk;

   wire divstep_do          = divisor <= {31'b0, dividend};
   wire [31:0] dividendN    = divstep_do ? dividend - divisor[31:0] : dividend;
   wire [31:0] qoutientN    = divstep_do ? quotient | quotient_msk : quotient;
   wire div_sign = ~is_unsigned & (is_rem ? in1[31] : (in1[31] != in2[31]) & |in2);

   always @(posedge clk) begin
       if (is_divide & op_valid) begin
           dividend     <= ~is_unsigned & in1[31] ? -in1 : in1;
           divisor      <= {(~is_unsigned & in2[31] ? -in2 : in2), 31'b0};
           quotient     <= 0;
           quotient_msk <= 1 << 31;
       end else begin
           dividend     <= dividendN;
           divisor      <= divisor >> 1;
           quotient     <= qoutientN;
           quotient_msk <= quotient_msk >> 1;
       end
   end

   reg[31:0] divResult;
   always @(posedge clk) divResult <= is_rem ? dividendN : qoutientN;

   // result muxing
   wire [31:0] aluOut_base =
     (funct3Is[0]  ? instr_30 & instr_5 ? aluMinus[31:0] : aluPlus : 32'b0) |
     (funct3Is[1]  ? leftshift                                     : 32'b0) |
     (funct3Is[2]  ? {31'b0, lt}                                   : 32'b0) |
     (funct3Is[3]  ? {31'b0, ltu}                                  : 32'b0) |
     (funct3Is[4]  ? in1 ^ in2                                     : 32'b0) |
     (funct3Is[5]  ? shifter                                       : 32'b0) |
     (funct3Is[6]  ? in1 | in2                                     : 32'b0) |
     (funct3Is[7]  ? in1 & in2                                     : 32'b0) ;

   wire [31:0] aluOut_muldiv = 
     (  funct3Is[0]   ?  multiply[31: 0] : 32'b0) |                     // 0:MUL
     ( |funct3Is[3:1] ?  multiply[63:32] : 32'b0) |                     // 1:MULH, 2:MULHSU, 3:MULHU
     (  is_divide     ?  div_sign ? -divResult : divResult : 32'b0) ;   // 4:DIV, 5:DIVU, 6:REM, 7:REMU

   assign out = is_mul_div ? aluOut_muldiv : aluOut_base;

endmodule
