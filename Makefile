# Makefile for building MMT.img from NASM assembly files in /src/

# NASM assembler
ASM = nasm
ASMFLAGS = -f bin

# Directories
SRC_DIR   = src
BUILD_DIR = build

# Source files
BOOTLOADER_SRC = $(SRC_DIR)/bootloader/Bootloader.asm
KERNEL_SRC     = $(SRC_DIR)/Kernel.asm
HELLO_SRC      = $(SRC_DIR)/hello.asm

# Output binaries
BOOTLOADER_BIN = $(BUILD_DIR)/bootloader.bin
KERNEL_BIN     = $(BUILD_DIR)/kernel.bin
HELLO_COM      = $(BUILD_DIR)/hello.com

# Final floppy image
IMG = $(BUILD_DIR)/MMT.img

# Default target
all: $(IMG)

# Compile bootloader
$(BOOTLOADER_BIN): $(BOOTLOADER_SRC)
	mkdir -p $(BUILD_DIR)
	$(ASM) $(ASMFLAGS) $< -o $@

# Compile kernel
$(KERNEL_BIN): $(KERNEL_SRC) $(SRC_DIR)/FAT12.asm
	mkdir -p $(BUILD_DIR)
	$(ASM) $(ASMFLAGS) $(KERNEL_SRC) -o $@

# Compile hello.com
$(HELLO_COM): $(HELLO_SRC)
	mkdir -p $(BUILD_DIR)
	$(ASM) $(ASMFLAGS) $< -o $@

# Create floppy image and copy binaries
$(IMG): $(BOOTLOADER_BIN) $(KERNEL_BIN) $(HELLO_COM)
	# Create empty 1.44 MB floppy image
	dd if=/dev/zero of=$(IMG) bs=512 count=2880
	# Write bootloader to first sector
	dd if=$(BOOTLOADER_BIN) of=$(IMG) bs=512 count=1 conv=notrunc
	# Copy kernel and hello.com into image using mtools
	mcopy -i $(IMG) $(KERNEL_BIN) ::
	mcopy -i $(IMG) $(HELLO_COM) ::

# Clean generated files
.PHONY: clean all
clean:
	rm -f $(BUILD_DIR)/*.bin $(IMG)
