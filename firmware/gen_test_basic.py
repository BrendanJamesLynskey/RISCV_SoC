#!/usr/bin/env python3
"""Generate test_basic.hex — minimal RV32I firmware for SoC integration test.

Writes 0xCAFEBABE to data SRAM (0x1000_0000), reads it back,
writes it to peripheral space (0x2000_0000), then loops forever.

Output: firmware/test_basic.hex (one 32-bit word per line, $readmemh format)
"""

import struct
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

# To load 0xCAFEBABE into x1:
# Since ADDI sign-extends, 0xABE has bit 11 set → sign-extends to 0xFFFFFABE
# So LUI must load 0xCAFEC (= 0xCAFEB + 1) to compensate
# 0xCAFEC000 + 0xFFFFFABE = 0xCAFEBABE
instructions.append(encode_u(0xCAFEC, 1, OP_LUI))       # lui x1, 0xCAFEC
instructions.append(encode_i(0xABE, 1, 0b000, 1, OP_ADDI))  # addi x1, x1, 0xABE (-1346 signed)

# x2 = 0x10000000 (data SRAM base)
instructions.append(encode_u(0x10000, 2, OP_LUI))       # lui x2, 0x10000

# Store 0xCAFEBABE to data SRAM
instructions.append(encode_s(0, 1, 2, 0b010, OP_STORE)) # sw x1, 0(x2)

# Load it back into x3
instructions.append(encode_i(0, 2, 0b010, 3, OP_LOAD))  # lw x3, 0(x2)

# x4 = 0x20000000 (peripheral base)
instructions.append(encode_u(0x20000, 4, OP_LUI))       # lui x4, 0x20000

# Store to peripheral space (observable by testbench)
instructions.append(encode_s(0, 3, 4, 0b010, OP_STORE)) # sw x3, 0(x4)

# Infinite loop: j self (offset = 0)
instructions.append(encode_j(0, 0, OP_JAL))             # jal x0, 0

# Write hex file
script_dir = os.path.dirname(os.path.abspath(__file__))
hex_path = os.path.join(script_dir, "test_basic.hex")

with open(hex_path, "w") as f:
    for instr in instructions:
        f.write(f"{instr:08X}\n")

print(f"Generated {hex_path} with {len(instructions)} instructions:")
for i, instr in enumerate(instructions):
    print(f"  [{i*4:04X}] {instr:08X}")
