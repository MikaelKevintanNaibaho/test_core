# firmware.s - DCACHE & ALU Integration Test

.global _start

_start:
    # 1. Store an initial value into memory address 0x100
    li  x1, 0x100           # Address for first store/load
    li  x2, 0xABCD1234      # Data to store
    sw  x2, 0(x1)           # Store word: mem[0x100] = 0xABCD1234
    
    # 2. Load that value back into a register (x3)
    li  x3, 0               # Clear x3
    lw  x3, 0(x1)           # Load word: x3 = mem[0x100]
    
    # 3. Perform an arithmetic operation on the loaded value
    #    If lw worked, x5 = 0xABCD1234 + 1 = 0xABCD1235
    #    If lw failed, x5 = 0 + 1 = 1
    addi x5, x3, 1          # Add 1 to the loaded value
    
    # 4. Store the NEW value from x5 into a NEW memory address (0x200)
    li  x4, 0x200           # Address for the second store
    sw  x5, 0(x4)           # Store word: mem[0x200] = value from x5

done:
    j   done                # Infinite loop to halt
