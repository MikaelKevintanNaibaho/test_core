#
# Makefile for Verilating and simulating the modular FemtoRV32 core
#

# --- Configuration ---

# Name of the top-level Verilog module
TOP_MODULE      := sim_top

# Name of the final simulation executable
EXEC            := sim.out

# Directories
RTL_DIR         := rtl
TB_DIR          := tb
BUILD_DIR       := build

# --- Toolchain ---

# RISC-V toolchain prefix (change if yours is different, e.g., riscv32-...)
TOOLCHAIN_PREFIX := riscv64-unknown-elf-

# --- Source Files ---

# Automatically find all Verilog source files in the rtl directory
VERILOG_SOURCES := $(wildcard $(RTL_DIR)/*.v)

# C++ testbench source file
CPP_SOURCES     := $(TB_DIR)/sim_main.cpp

# Firmware source and output files
FIRMWARE_S      := firmware.s
FIRMWARE_ELF    := $(BUILD_DIR)/firmware.elf
FIRMWARE_HEX    := $(BUILD_DIR)/firmware.hex

# --- Flags and Commands ---

# Verilator flags
# --cc: Generate C++ code
# --exe: Create a C++ executable wrapper
# --build: Automatically compile the generated C++
# --trace: Enable waveform tracing (VCD)
VERILATOR_FLAGS := --cc --exe --build --trace -j 0 --language 1800-2017 -GINIT_FILE='"$(FIRMWARE_HEX)"'

# C++ compiler flags passed to Verilator
# We define INIT_FILE to pass the firmware path to our C++ testbench
# The escaped quotes are necessary for the shell
CPP_FLAGS       := -std=c++11 -O3
# RISC-V GCC flags for assembling firmware
# rv32im: Target architecture (I, M extensions)
# ilp32:  ABI
AS_FLAGS        := -march=rv32im -mabi=ilp32
LD_FLAGS        := -m elf32lriscv

# --- Build Rules ---

# Default target: build the simulation executable
all: $(BUILD_DIR)/$(EXEC)

# Rule to build the simulator
# It depends on all Verilog/C++ sources and the firmware
$(BUILD_DIR)/$(EXEC): $(VERILOG_SOURCES) $(CPP_SOURCES) $(FIRMWARE_HEX)
	@echo "### Verilating the design... ###"
	# Verilate the design and build the executable in the 'obj_dir' directory
	verilator $(VERILATOR_FLAGS) --top-module $(TOP_MODULE) \
		-I$(RTL_DIR) $(VERILOG_SOURCES) --exe $(CPP_SOURCES) \
		-CFLAGS "$(CPP_FLAGS)"

	@echo "### Copying executable to $(BUILD_DIR) ###"
	# Copy the final executable from Verilator's output directory to our build dir
	@mkdir -p $(BUILD_DIR)
	@cp obj_dir/V$(TOP_MODULE) $@

# Rule to build the firmware
$(FIRMWARE_HEX): $(FIRMWARE_S) linker.ld
	@echo "### Assembling firmware... ###"
	@mkdir -p $(BUILD_DIR)
	# Step 1: Assemble the .s file into an object file (.o)
	$(TOOLCHAIN_PREFIX)as $(AS_FLAGS) $(FIRMWARE_S) -o $(BUILD_DIR)/firmware.o
	# Step 2: Link the object file into an .elf file
	$(TOOLCHAIN_PREFIX)ld $(LD_FLAGS) -Tlinker.ld $(BUILD_DIR)/firmware.o -o $(FIRMWARE_ELF)
	# Step 3: Convert the .elf file into a Verilog hex file (this line stays the same)
	$(TOOLCHAIN_PREFIX)objcopy -O verilog --verilog-data-width 4 $(FIRMWARE_ELF) $@
	# Rule to run the simulation
run: all
	@echo "### Running simulation... ###"
	./$(BUILD_DIR)/$(EXEC)
	@echo "### Simulation finished. Waveform saved to waveform.vcd ###"

# Rule to clean up all generated files
clean:
	@echo "### Cleaning up... ###"
	@rm -rf $(BUILD_DIR) obj_dir *.vcd

# Phony targets are not files
.PHONY: all run clean
