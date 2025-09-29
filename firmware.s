# firmware.s - Calculates the 10th Fibonacci number (F(10) = 55)
# and uses load/store operations to test the dcache.

.global _start

_start:
    # --- Initialization ---
    # We will store the Fibonacci sequence starting at memory address 0x100.
    li  x5, 0x100    # x5: Base address for storing Fibonacci numbers

    # Initialize the first two numbers of the sequence in memory
    li  x2, 0        # F(0) = 0
    li  x3, 1        # F(1) = 1
    sw  x2, 0(x5)    # Store F(0) at address 0x100
    sw  x3, 4(x5)    # Store F(1) at address 0x104

    # Initialize loop counter. We want to calculate up to F(10), 
    # and since we already have F(0) and F(1), we need 8 more iterations.
    li  x1, 8        # x1: loop counter

# --- Main Loop ---
# In each iteration, we load the previous two numbers, calculate the next,
# and store the result back into memory.
loop:
    # Check if the loop is finished
    beq x1, x0, done # If counter (x1) is zero, jump to done

    # Load the previous two Fibonacci numbers from memory
    lw  x2, 0(x5)    # Load F(n-2)
    lw  x3, 4(x5)    # Load F(n-1)

    # Calculate the next number in the sequence
    add x4, x2, x3   # F(n) = F(n-2) + F(n-1)

    # Store the new result. We advance the base address by 4 bytes.
    addi x5, x5, 4   # Move to the next word in memory
    sw  x4, 0(x5)    # Store F(n)

    # Decrement the loop counter
    addi x1, x1, -1  # counter--

    j   loop         # Jump back to the start of the loop

# --- Halt ---
# An infinite loop to halt the processor after the calculation is complete.
# The final result (F(10) = 55) will be at memory address 0x128.
done:
    j   done
