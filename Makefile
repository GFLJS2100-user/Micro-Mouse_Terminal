# Makefile for building MMT.img from NASM assembly files in /src/

# NASM assembler
ASM = nasm

# NASM flags
ASMFLAGS = -f bin

# Source files (inside /src/)
BOOTLOADER_SRC = src/Bootloader.asm
LOAD_SRC       = src/Load.asm
KERNEL_SRC     = src/Kernel.asm

# Output binary files (same folder as Makefile)
BOOTLOADER_BIN = bootloader.bin
LOAD_BIN       = load.bin
KERNEL_BIN     = kernel.bin

# Final image
IMG = MMT.img

# Default target
all: $(IMG)

# Compile bootloader
$(BOOTLOADER_BIN): $(BOOTLOADER_SRC)
	$(ASM) $(ASMFLAGS) $< -o $@

# Compile loader
$(LOAD_BIN): $(LOAD_SRC)
	$(ASM) $(ASMFLAGS) $< -o $@

# Compile kernel
$(KERNEL_BIN): $(KERNEL_SRC)
	$(ASM) $(ASMFLAGS) $< -o $@

# Combine binaries into a single image
$(IMG): $(BOOTLOADER_BIN) $(LOAD_BIN) $(KERNEL_BIN)
	cat $(BOOTLOADER_BIN) $(LOAD_BIN) $(KERNEL_BIN) > $(IMG)

.PHONY: all