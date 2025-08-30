# Micro Mouse Terminal (MMT)

MMT is a simple 16-bit operating system written in NASM assembly. It boots from a FAT12-formatted floppy disk image and provides a basic interactive terminal.

## Features

*   **Simple Shell:** An interactive command-line interface.
*   **Built-in Commands:**
    *   `help`: Displays a list of available commands.
    *   `cls`: Clears the terminal screen.
    *   `dir`: Lists files in the root directory of the boot disk.
    *   `reboot`: Reboots the computer.
    *   `shutdown`: Attempts to shut down the computer via APM.
*   **FAT12 Filesystem:** The bootloader can read the kernel from a FAT12-formatted disk.

## Building from Source

### Prerequisites

To build MMT, you will need the following tools:
*   `nasm`: The Netwide Assembler.
*   `make`: The build automation tool.
*   `mtools`: For manipulating MS-DOS filesystems.

### Build Instructions

Simply run the `make` command in the root of the repository:

```sh
make
```

This will produce a bootable floppy disk image named `build/MMT.img`.

## Running

You can run the operating system using an emulator like QEMU:

```sh
qemu-system-i386 -fda build/MMT.img
```

## Credits

---
anujrmohite for bootloader

LevelPack1218 for Micro Mouse Terminal
