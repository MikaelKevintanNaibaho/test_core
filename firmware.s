# firmware.s - Calculates the 10th Fibonacci number (F(10) = 55)

.global _start

_start:
    # Initialize registers
    # We want to calculate F(10). The loop will run 9 times to get from F(1) to F(10).
    li  x1, 9        # x1: loop counter, starts at 9
    li  x2, 0        # x2: stores F(n-2), starts with F(0)
    li  x3, 1        # x3: stores F(n-1), starts with F(1)
    # x4 will store the result F(n)

# --- Main Loop ---
# On each iteration, we calculate the next Fibonacci number
# and update the registers for the subsequent iteration.
loop:
    # Check if the loop is finished
    beq x1, x0, done # If counter (x1) is zero, jump to done

    # Calculate the next number in the sequence
    add x4, x2, x3   # F(n) = F(n-2) + F(n-1)

    # Update the values for the next iteration
    mv  x2, x3       # The old F(n-1) becomes the new F(n-2)
    mv  x3, x4       # The current result F(n) becomes the new F(n-1)

    # Decrement the loop counter
    addi x1, x1, -1  # counter--

    j   loop         # Jump back to the start of the loop

# --- Halt ---
# An infinite loop to halt the processor after the calculation is complete.
done:
    j   done
