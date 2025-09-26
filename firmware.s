# Simple program to add 10 and 20, storing the result (30) in register x3.
.global _start

_start:
    li  x1, 10      # Load immediate value 10 into register x1
    li  x2, 20      # Load immediate value 20 into register x2
    add x3, x1, x2  # x3 = x1 + x2

done:
    j   done        # Infinite loop to halt the processor
