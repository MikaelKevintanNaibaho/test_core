# firmware.s - Test Suite for the Branch Target Buffer (BTB)
#
# This program tests the functionality of the 4-entry BTB.

.global _start

_start:
    # Use x30 as a status register. 0 = success so far.
    li  x30, 0

#-----------------------------------------------------------------------
# Test 1: Simple Loop (BTB Miss then Hit)
# A `bne` instruction will be taken 3 times.
# 1st time: BTB miss, branch taken -> BTB gets updated.
# 2nd, 3rd time: BTB hit, branch taken -> Correct prediction.
#-----------------------------------------------------------------------
    li  x5, 3           # Loop counter
loop1_start:
    addi x5, x5, -1     # Decrement counter
    nop                 # Some work
    nop
    bne x5, x0, loop1_start # Branch back if counter is not zero

# If we fall through, the test passed.

#-----------------------------------------------------------------------
# Test 2: Branch Misprediction (BTB Hit, Branch NOT Taken)
# We execute a branch that is TAKEN to get it into the BTB.
# Then we change the condition and execute it again, but this time
# it is NOT taken. The BTB will predict "taken", causing a mispredict.
# We verify by checking if the fall-through code is executed.
#-----------------------------------------------------------------------
    li  x6, 10
    li  x7, 10
    # Set a flag register x29 to 1. If the branch is incorrectly taken,
    # it will skip the instruction that sets it to 2.
    li  x29, 1

    beq x6, x7, test2_target # First run: Branch IS taken. This loads the BTB.
    j   fail                 # Should not be reached.

test2_target:
    # Now, change the condition so the branch is NOT taken
    li  x7, 11
    beq x6, x7, test2_fail   # Second run: Branch is NOT taken.
                             # BTB predicts it IS taken (to test2_fail).
                             # This should trigger a misprediction and pipeline flush.
                             # The core should recover and execute the next instruction.

    # This is the fall-through path. If the misprediction recovery worked,
    # we will execute this instruction.
    li  x29, 2               # Set flag to 2, indicating success.
    j   test2_check

test2_fail:
    # If we get here on the second run, the misprediction flush failed.
    li  x29, 0
    j   test2_check

test2_check:
    # Check if the flag is 2. If not, the test failed.
    li  x10, 2
    bne x29, x10, fail

#-----------------------------------------------------------------------
# Test 3: BTB Capacity and Replacement
# The BTB has 4 entries. We will execute 5 unique taken branches to
# fill it up and force the first entry to be evicted.
#-----------------------------------------------------------------------
    jal x1, cap1
    jal x1, cap2
    jal x1, cap3
    jal x1, cap4
    jal x1, cap5         # This jump should evict the 'jal x1, cap1' entry.

    # By running these 5 jumps, we have exercised the BTB's replacement
    # logic. In a waveform, you would see the first entry being overwritten.
    j test3_end

cap1: jalr x0, 0(x1)
cap2: jalr x0, 0(x1)
cap3: jalr x0, 0(x1)
cap4: jalr x0, 0(x1)
cap5: jalr x0, 0(x1)

test3_end:

#-----------------------------------------------------------------------
# End of Test
# If we reach here, all tests have passed.
#-----------------------------------------------------------------------
pass:
    j pass  # Infinite loop for success

fail:
    j fail  # Infinite loop for failure
