#!/usr/bin/env python3
"""Generate fulltest.hex — full-system firmware for RISC-V SoC integration test.

Exercises: SRAM read/write, GPIO output, Timer + PLIC interrupt setup,
then writes a completion marker. Output: firmware/fulltest.hex
($readmemh format, one 32-bit word per line).
"""

import os


def encode_u(imm20, rd, opcode):
    """U-type: imm[31:12] | rd | opcode"""
    return ((imm20 & 0xFFFFF) << 12) | ((rd & 0x1F) << 7) | (opcode & 0x7F)


def encode_i(imm12, rs1, funct3, rd, opcode):
    """I-type: imm[11:0] | rs1 | funct3 | rd | opcode"""
    return ((imm12 & 0xFFF) << 20) | ((rs1 & 0x1F) << 15) | \
           ((funct3 & 0x7) << 12) | ((rd & 0x1F) << 7) | (opcode & 0x7F)


def encode_s(imm12, rs2, rs1, funct3, opcode):
    """S-type: imm[11:5] | rs2 | rs1 | funct3 | imm[4:0] | opcode"""
    imm_hi = (imm12 >> 5) & 0x7F
    imm_lo = imm12 & 0x1F
    return (imm_hi << 25) | ((rs2 & 0x1F) << 20) | ((rs1 & 0x1F) << 15) | \
           ((funct3 & 0x7) << 12) | (imm_lo << 7) | (opcode & 0x7F)


def encode_j(imm21, rd, opcode):
    """J-type: imm[20|10:1|11|19:12] | rd | opcode"""
    bit20 = (imm21 >> 20) & 0x1
    bits10_1 = (imm21 >> 1) & 0x3FF
    bit11 = (imm21 >> 11) & 0x1
    bits19_12 = (imm21 >> 12) & 0xFF
    imm_field = (bit20 << 19) | (bits10_1 << 9) | (bit11 << 8) | bits19_12
    return (imm_field << 12) | ((rd & 0x1F) << 7) | (opcode & 0x7F)


OP_LUI   = 0b0110111
OP_ADDI  = 0b0010011
OP_STORE = 0b0100011
OP_LOAD  = 0b0000011
OP_JAL   = 0b1101111

instructions = []

# ==========================================================================
# Phase 1 — Memory test (SRAM1 at 0x1000_0000)
# ==========================================================================

# x1 = 0xDEADBEEF  (LUI 0xDEADC + ADDI 0xEEF; 0xEEF sign-extends to -0x111)
instructions.append(encode_u(0xDEADC, 1, OP_LUI))          # lui x1, 0xDEADC
instructions.append(encode_i(0xEEF, 1, 0b000, 1, OP_ADDI)) # addi x1, x1, 0xEEF

# x2 = 0x10000000 (data SRAM base)
instructions.append(encode_u(0x10000, 2, OP_LUI))           # lui x2, 0x10000

# Store 0xDEADBEEF to 0x10000000
instructions.append(encode_s(0, 1, 2, 0b010, OP_STORE))     # sw x1, 0(x2)

# Read back into x3
instructions.append(encode_i(0, 2, 0b010, 3, OP_LOAD))     # lw x3, 0(x2)

# x4 = 0x12345678  (LUI 0x12345 + ADDI 0x678; bit 11 of 0x678 is 0, no fixup)
instructions.append(encode_u(0x12345, 4, OP_LUI))           # lui x4, 0x12345
instructions.append(encode_i(0x678, 4, 0b000, 4, OP_ADDI))  # addi x4, x4, 0x678

# Store 0x12345678 to 0x10000004
instructions.append(encode_s(4, 4, 2, 0b010, OP_STORE))     # sw x4, 4(x2)

# ==========================================================================
# Phase 2 — GPIO test (GPIO at 0x2000_0000)
# ==========================================================================

# x6 = 0x20000000 (GPIO base = periph base)
instructions.append(encode_u(0x20000, 6, OP_LUI))           # lui x6, 0x20000

# x7 = 0xFF (direction: lower 8 bits output)
instructions.append(encode_i(0xFF, 0, 0b000, 7, OP_ADDI))   # addi x7, x0, 0xFF

# Write GPIO direction register (offset 0x08)
instructions.append(encode_s(8, 7, 6, 0b010, OP_STORE))     # sw x7, 8(x6)

# x8 = 0xAA (output pattern)
instructions.append(encode_i(0xAA, 0, 0b000, 8, OP_ADDI))   # addi x8, x0, 0xAA

# Write GPIO data_out register (offset 0x00)
instructions.append(encode_s(0, 8, 6, 0b010, OP_STORE))     # sw x8, 0(x6)

# ==========================================================================
# Phase 3 — Timer + PLIC (Timer at 0x2000_2000, PLIC at 0x2000_3000)
# ==========================================================================

# x9 = 0x20002000 (Timer base)
instructions.append(encode_u(0x20002, 9, OP_LUI))           # lui x9, 0x20002

# x10 = 100 (compare value — timer fires after 100 ticks)
instructions.append(encode_i(100, 0, 0b000, 10, OP_ADDI))   # addi x10, x0, 100

# Write Timer COMPARE register (offset 0x08)
instructions.append(encode_s(8, 10, 9, 0b010, OP_STORE))    # sw x10, 8(x9)

# x11 = 1 (enable bit)
instructions.append(encode_i(1, 0, 0b000, 11, OP_ADDI))     # addi x11, x0, 1

# Write Timer CTRL = enable (offset 0x00)
instructions.append(encode_s(0, 11, 9, 0b010, OP_STORE))    # sw x11, 0(x9)

# x12 = 0x20003000 (PLIC base)
instructions.append(encode_u(0x20003, 12, OP_LUI))          # lui x12, 0x20003

# x13 = 2 (priority > default threshold of 0)
instructions.append(encode_i(2, 0, 0b000, 13, OP_ADDI))     # addi x13, x0, 2

# Write PLIC PRIORITY[0] = 2 (offset 0x10) — write priority BEFORE enable
instructions.append(encode_s(0x10, 13, 12, 0b010, OP_STORE)) # sw x13, 16(x12)

# x11 = 1 (reload — avoid pipeline/cache interaction from prior use)
instructions.append(encode_i(1, 0, 0b000, 11, OP_ADDI))     # addi x11, x0, 1

# Write PLIC IRQ_ENABLE = 1 (enable timer IRQ, source 0) (offset 0x04)
instructions.append(encode_s(4, 11, 12, 0b010, OP_STORE))   # sw x11, 4(x12)

# ==========================================================================
# Phase 4 — Completion marker
# ==========================================================================

# x14 = 0x900D900D  (LUI 0x900D9 + ADDI 0x00D; bit 11 of 0x00D is 0)
instructions.append(encode_u(0x900D9, 14, OP_LUI))          # lui x14, 0x900D9
instructions.append(encode_i(0x00D, 14, 0b000, 14, OP_ADDI)) # addi x14, x14, 0x00D

# x15 = 0x10000F00  (LUI 0x10001 + ADDI 0xF00; 0xF00 = -256 signed)
instructions.append(encode_u(0x10001, 15, OP_LUI))          # lui x15, 0x10001
instructions.append(encode_i(0xF00, 15, 0b000, 15, OP_ADDI)) # addi x15, x15, -256

# Store completion marker to 0x10000F00
instructions.append(encode_s(0, 14, 15, 0b010, OP_STORE))   # sw x14, 0(x15)

# Infinite loop (JAL x0, offset=0 → jumps to self)
instructions.append(encode_j(0, 0, OP_JAL))                 # jal x0, 0

# ==========================================================================
# Write hex file
# ==========================================================================
script_dir = os.path.dirname(os.path.abspath(__file__))
hex_path = os.path.join(script_dir, "fulltest.hex")

with open(hex_path, "w") as f:
    for instr in instructions:
        f.write(f"{instr:08X}\n")

print(f"Generated {hex_path} with {len(instructions)} instructions:")
for i, instr in enumerate(instructions):
    print(f"  [{i*4:04X}] {instr:08X}")
