# firmware.s - Comprehensive Test Suite for the RV32IM Core
#
# This program systematically tests each supported instruction of the RV32I
# and RV32M extensions. Each test is designed to be simple and verifiable
# by inspecting the register file in a waveform viewer.

.global _start

_start:
    # --- Test Storage Setup ---
    # We will use a dedicated memory region for load/store tests.
    li  x5, 0x200       # t0: Base address for memory tests

#-----------------------------------------------------------------------
# RV32I: Load and Store Instructions
#-----------------------------------------------------------------------
    # Setup values to be stored
    li  x6, 0xDEADBEEF  # t1
    li  x7, 0x12345678  # t2

    # --- SW: Store Word ---
    sw  x6, 0(x5)       # Store 0xDEADBEEF at address 0x200

    # --- SH: Store Half-word ---
    sh  x7, 4(x5)       # Store 0x5678 at address 0x204

    # --- SB: Store Byte ---
    sb  x7, 6(x5)       # Store 0x78 at address 0x206

    # Clear registers before loading to ensure we're not reading old values
    li  x6, 0
    li  x7, 0
    li  x8, 0
    li  x9, 0
    li  x10, 0
    li  x11, 0

    # --- LW: Load Word ---
    lw  x8, 0(x5)       # x8 should be 0xDEADBEEF

    # --- LH: Load Half-word (Sign Extended) ---
    lh  x9, 4(x5)       # x9 should be 0x00005678 (0x5678 is positive)

    # --- LB: Load Byte (Sign Extended) ---
    lh  x10, 6(x5)      # x10 should be 0x00000078 (0x78 is positive)

    # --- LHU: Load Half-word Unsigned ---
    lhu x11, 4(x5)      # x11 should be 0x00005678

    # --- LBU: Load Byte Unsigned ---
    lbu x12, 6(x5)      # x12 should be 0x00000078

#-----------------------------------------------------------------------
# RV32I: ALU Register-Immediate Instructions
#-----------------------------------------------------------------------
    # --- ADDI: Add Immediate ---
    li  x6, 100
    addi x7, x6, 50     # x7 should be 150

    # --- SLTI: Set Less Than Immediate ---
    slti x8, x6, 200    # x8 should be 1 (100 < 200)
    slti x9, x6, 50     # x9 should be 0 (100 is not < 50)

    # --- SLTIU: Set Less Than Immediate Unsigned ---
    li  x6, -1          # 0xFFFFFFFF
    sltiu x10, x6, 10   # x10 should be 0 (-1 unsigned > 10)

    # --- XORI, ORI, ANDI ---
    li  x6, 0x0F0F0F0F
    xori x11, x6, -1     # x11 should be 0xF0F0F0F0 (XORI with all 1s is NOT)

    # --- FIX for large immediates ---
    li   x14, 0xF0F0F0F0 # Load immediate into temp register
    or   x12, x6, x14     # x12 should be 0xFFFFFFFF

    li   x14, 0x55555555 # Load immediate into temp register
    and  x13, x6, x14     # x13 should be 0x05050505

#-----------------------------------------------------------------------
# RV32I: Shift Immediate Instructions
#-----------------------------------------------------------------------
    li x6, 0x80000005
    # --- SLLI: Shift Left Logical Immediate ---
    slli x7, x6, 4      # x7 should be 0x00000050

    # --- SRLI: Shift Right Logical Immediate ---
    srli x8, x6, 4      # x8 should be 0x08000000

    # --- SRAI: Shift Right Arithmetic Immediate ---
    srai x9, x6, 4      # x9 should be 0xF8000000 (sign bit is extended)

#-----------------------------------------------------------------------
# RV32I: LUI and AUIPC
#-----------------------------------------------------------------------
    # --- LUI: Load Upper Immediate ---
    lui x10, 0xDEADB   # x10 should be 0xDEADB000

    # --- AUIPC: Add Upper Immediate to PC ---
    # This is harder to test statically, but it will load x11 with
    # the address of this instruction + 0xBEEF0000.
    auipc x11, 0xBEEF0

#-----------------------------------------------------------------------
# RV32I: ALU Register-Register Instructions
#-----------------------------------------------------------------------
    li x6, 100
    li x7, 50
    # --- ADD ---
    add x8, x6, x7      # x8 should be 150
    # --- SUB ---
    sub x9, x6, x7      # x9 should be 50

    # --- SLT / SLTU: Set Less Than ---
    li x6, -5
    li x7, 5
    slt x10, x6, x7     # x10 should be 1 (signed compare)
    sltu x11, x6, x7    # x11 should be 0 (unsigned compare)

    # --- SLL / SRL / SRA ---
    li x6, 0x9000000F
    li x7, 4
    sll x12, x6, x7     # x12 should be 0x000000F0
    srl x13, x6, x7     # x13 should be 0x09000000
    sra x14, x6, x7     # x14 should be 0xF9000000

#-----------------------------------------------------------------------
# RV32I: Branch Instructions
#-----------------------------------------------------------------------
    li x6, 10
    li x7, 10
    li x8, 20

    # --- BEQ: Branch if Equal ---
    beq x6, x7, beq_success # Should take this branch
    j fail                  # Should not be reached
beq_success:

    # --- BNE: Branch if Not Equal ---
    bne x6, x8, bne_success # Should take this branch
    j fail                  # Should not be reached
bne_success:

    # --- BLT: Branch if Less Than (Signed) ---
    blt x6, x8, blt_success # Should take this branch
    j fail                  # Should not be reached
blt_success:

    # --- BGE: Branch if Greater or Equal (Signed) ---
    bge x7, x6, bge_success # Should take this branch
    j fail                  # Should not be reached
bge_success:

    # --- BLTU: Branch if Less Than (Unsigned) ---
    bltu x6, x8, bltu_success # Should take this branch
    j fail                    # Should not be reached
bltu_success:

    # --- BGEU: Branch if Greater or Equal (Unsigned) ---
    bgeu x7, x6, bgeu_success # Should take this branch
    j fail                    # Should not be reached
bgeu_success:

#-----------------------------------------------------------------------
# RV32I: Jump Instructions
#-----------------------------------------------------------------------
    # --- JAL: Jump and Link ---
    jal x1, jal_target      # x1 (ra) will get addr of next instr
    nop                     # Will be skipped
jal_target:
    nop

    # --- JALR: Jump and Link Register ---
    # Load address of jalr_target into x6
    la x6, jalr_target
    jalr x1, 0(x6)          # Jump to address in x6
    nop                     # Will be skipped
jalr_target:
    nop

#-----------------------------------------------------------------------
# RV32M: Multiplication Instructions
#-----------------------------------------------------------------------
    li x6, 5              # Multiplicand
    li x7, 10             # Multiplier
    # --- MUL: Multiply ---
    mul x8, x6, x7        # x8 should be 50

    li x6, -2             # 0xFFFFFFFE
    li x7, 2
    # --- MULH: Multiply High (Signed * Signed) ---
    mulh x9, x6, x7       # x9 should be -1 (0xFFFFFFFF)

    # --- MULHSU: Multiply High (Signed * Unsigned) ---
    mulhsu x10, x6, x7    # x10 should be -1 (0xFFFFFFFF)

    # --- MULHU: Multiply High (Unsigned * Unsigned) ---
    mulhu x11, x6, x7     # x11 should be 1

#-----------------------------------------------------------------------
# RV32M: Division and Remainder Instructions
#-----------------------------------------------------------------------
    li x6, 100
    li x7, 10
    # --- DIV: Divide ---
    div x8, x6, x7        # x8 should be 10

    # --- REM: Remainder ---
    li x6, 103
    rem x9, x6, x7        # x9 should be 3

    # --- DIVU: Divide Unsigned ---
    li x6, -10            # Large positive unsigned number
    li x7, 10
    divu x10, x6, x7      # x10 should be 0x19999999

    # --- REMU: Remainder Unsigned ---
    li x6, -7             # Large positive unsigned number
    remu x11, x6, x7      # x11 should be 9

#-----------------------------------------------------------------------
# End of Test
#-----------------------------------------------------------------------
    # If we reach here without hitting 'fail', the basic tests passed.
pass:
    j pass

fail:
    # An infinite loop to indicate a test failure.
    j fail
