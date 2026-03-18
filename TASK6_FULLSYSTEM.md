# Task 6: Full-System Firmware Test

## Context

You are working in `~/Claude_sandbox/RISCV_SoC`. Tasks 1-5 are complete. The SoC is fully wired:
- CPU executing firmware through MMU (bypass) → crossbar → SRAM
- DMA + IOMMU on M2, register slaves on S3/S4
- GPIO, UART, Timer, PLIC all wired through peripheral bridge on S2

Your job is to write a comprehensive firmware program and testbench that exercises the entire SoC in a single simulation run, proving all subsystems work together.

## What to do

### Step 1: Understand the memory map and register layouts

Before writing firmware, confirm the exact register offsets by reading the peripheral source files. Print key information:

```bash
# GPIO registers
grep -n 'addr\|offset\|case\|REG\|reg_' ~/Claude_sandbox/RISCV_RV32IMC_5stage/rtl/periph/gpio.v | head -30

# UART registers
grep -n 'addr\|offset\|case\|REG\|reg_' ~/Claude_sandbox/RISCV_RV32IMC_5stage/rtl/periph/uart.v | head -30

# Timer registers
grep -n 'addr\|offset\|case\|REG\|reg_' ~/Claude_sandbox/RISCV_RV32IMC_5stage/rtl/periph/timer.v | head -30

# DMA registers — check the register map
grep -n 'offset\|REG\|CH_CTRL\|CH_SRC\|CH_DST\|CH_XFER' ~/Claude_sandbox/RISCV_DMA/rtl/dma_reg_file.sv | head -30

# PLIC registers — from our own module
grep -n 'offset\|case\|12.h' ~/Claude_sandbox/RISCV_SoC/rtl/plic.sv | head -20

# Check what's in soc_pkg for addresses
cat ~/Claude_sandbox/RISCV_SoC/rtl/soc_pkg.sv
```

Also check the existing firmware to understand the hex format:
```bash
cat ~/Claude_sandbox/RISCV_SoC/firmware/test_basic.hex
cat ~/Claude_sandbox/RISCV_SoC/firmware/gen_test_basic.py
```

### Step 2: Create `firmware/gen_fulltest.py`

Write a Python script that generates `firmware/fulltest.hex`. The firmware should be a sequence of RV32I instructions (no M or C extensions needed — keep it simple) that:

**Phase 1 — Memory test:**
1. Write a pattern (0xDEADBEEF) to data SRAM at 0x1000_0000
2. Read it back into a different register
3. Compare — if mismatch, write 0xFAIL0001 to a "result" address (e.g. 0x1000_0F00) and halt
4. Write 0x12345678 to a second data SRAM address (0x1000_0004)
5. Read back and verify

**Phase 2 — GPIO test:**
6. Write 0xFF to GPIO direction register (set lower 8 bits as output)
7. Write 0xAA to GPIO data register
8. (Testbench will verify gpio_out externally)

**Phase 3 — Timer test:**
9. Read current timer count
10. Write a compare value = current + small delta (e.g. 100)
11. Enable timer interrupt in PLIC (write to PLIC enable register at 0x2000_3004)
12. Set PLIC source 0 (timer) priority > 0 (write to 0x2000_3010)
13. Spin-wait briefly (a small loop) for the interrupt to fire
14. (Testbench will verify meip assertion externally)

**Phase 4 — Completion:**
15. Write 0x900D_900D ("good good") to the result address (0x1000_0F00)
16. Enter infinite loop

The firmware generator should:
- Encode each RV32I instruction as 4 bytes in hex format
- Use only base RV32I instructions: LUI, ADDI, SW, LW, BNE, JAL
- Output in the format expected by `$readmemh` (one 32-bit word per line)
- Include comments in the Python script explaining each instruction

**Keep the firmware SHORT** — under 30 instructions. The goal is to prove the path works, not to be exhaustive. If encoding complex sequences is error-prone, reduce scope: phases 1 and 2 are the minimum, phases 3-4 are stretch goals.

### Step 3: Create testbench `tb/sv/tb_fullsystem.sv`

This is the capstone testbench. It:

1. Instantiates `riscv_soc_top` with `cpu_enable=1`
2. Loads `firmware/fulltest.hex` into SRAM0
3. Connects GPIO and UART external pins
4. Releases reset
5. Waits for the CPU to execute (sufficient cycles — e.g. 2000-5000 depending on firmware length)
6. Checks the following at the end:

**Memory checks:**
- Read SRAM1 at 0x1000_0000 — expect 0xDEADBEEF
- Read SRAM1 at 0x1000_0004 — expect 0x12345678

**GPIO checks:**
- Verify `gpio_out[7:0]` == 0xAA (firmware wrote this)
- Verify `gpio_oe[7:0]` == 0xFF (firmware set direction)

**Completion check:**
- Read SRAM1 at 0x1000_0F00 — expect 0x900D_900D (firmware reached the end)

**Timer/interrupt check (stretch goal):**
- If firmware enabled timer interrupt, check that `meip` was asserted at some point during the run (sample it periodically, or register a flag)

Report each check as `[PASS]` or `[FAIL]`.

### Step 4: Run regression

After the new testbench passes, verify ALL existing testbenches still pass:

```bash
# Existing tests
echo "finish" | vvp sim_soc_top       # 8 tests
echo "finish" | vvp sim_mmu_int       # 5 tests
echo "finish" | vvp sim_dma_iommu     # 5 tests
echo "finish" | vvp sim_cpu_int       # 4 tests
echo "finish" | vvp sim_periph_int    # 7 tests
echo "finish" | vvp sim_fullsystem    # new test
```

If the existing sim binaries are stale or missing, recompile them using the compile commands from previous tasks. The important thing is that no existing test regresses.

### Step 5: Update README.md

Update `RISCV_SoC/README.md` to reflect the final state:

1. Update the test summary table with all testbenches and their pass counts
2. Note that the full system runs firmware autonomously
3. Mention the firmware generation script

Do NOT rewrite the README — merge updates into the existing content.

### Compilation

```bash
# Use the same compile list as Task 4, with the new testbench
iverilog -g2012 -Wall \
    -I ~/Claude_sandbox/RISCV_RV32IMC_5stage/rtl/pkg \
    -I ~/Claude_sandbox/RISCV_RV32IMC_5stage/rtl/core \
    -c filelist_full.txt -o sim_fullsystem
echo "finish" | vvp sim_fullsystem
```

The filelist should include ALL RTL sources (from all repos + local) plus `tb/sv/tb_fullsystem.sv`. Build on the filelist used in Task 4/5.

## Important notes

- Firmware encoding is the trickiest part. Double-check every instruction encoding against the RISC-V spec. Common mistakes: sign extension in ADDI immediates, LUI upper 20 bits, SW/LW offset encoding, branch offset encoding.
- If firmware execution doesn't produce expected results, add `$display` statements in the testbench to observe the CPU's PC, register writes, and AXI transactions. This helps debug whether the CPU is executing the right instructions.
- The CPU resets to PC=0x00000000, which maps to SRAM0 (Slave 0). Firmware must be loaded at address 0 in SRAM0.
- When running vvp: `echo "finish" | vvp <sim_file>`

## Conventions

- `always_ff` with synchronous active-high reset `srst`
- `snake_case` everywhere
- `// Brendan Lynskey 2025` author line
- MIT licence
- `iverilog -g2012 -Wall`
- Use `$stop` not `$finish`
- `always @(*)` for combinational blocks reading submodule outputs
- Do NOT modify any files in subsystem repos
- Do NOT delete existing files in `RISCV_SoC/`
- PRESERVE all existing content in README.md (merge, don't replace)

All tests must show `[PASS]`. Fix any compilation or simulation issues before finishing.
