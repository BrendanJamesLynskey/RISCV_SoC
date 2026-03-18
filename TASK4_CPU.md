# Task 4: Wire BRV32P CPU Core into RISCV_SoC

## Context

You are working in `~/Claude_sandbox/RISCV_SoC`. Tasks 1-3 are complete:
- Task 1: AXI4 crossbar (3M x 5S)
- Task 2: I-MMU and D-MMU on Masters 0 and 1 (bypass mode)
- Task 3: DMA + IOMMU on Master 2, register slaves on S3/S4

Currently, Masters 0 and 1 have external AXI4 ports on `riscv_soc_top.sv` that a testbench drives. Your job is to instantiate the actual BRV32P CPU core so the SoC can execute firmware autonomously.

The CPU repo is at `~/Claude_sandbox/RISCV_RV32IMC_5stage`. Clone it if not present.

## Prerequisites

```bash
cd ~/Claude_sandbox
git clone https://github.com/BrendanJamesLynskey/RISCV_RV32IMC_5stage.git
```

## Understanding the CPU repo structure

The BRV32P repo contains a COMPLETE SoC (`brv32p_soc.v`) with its own AXI interconnect, SRAM, and peripherals. We do NOT want the full SoC — we want to extract just the CPU core and its L1 caches, then connect their AXI miss ports to our crossbar through the MMU.

**CRITICAL: Read all files in the CPU repo before writing any code.**

```bash
ls -la ~/Claude_sandbox/RISCV_RV32IMC_5stage/rtl/core/
ls -la ~/Claude_sandbox/RISCV_RV32IMC_5stage/rtl/cache/
ls -la ~/Claude_sandbox/RISCV_RV32IMC_5stage/rtl/bus/
ls -la ~/Claude_sandbox/RISCV_RV32IMC_5stage/rtl/periph/
cat ~/Claude_sandbox/RISCV_RV32IMC_5stage/rtl/brv32p_soc.v
cat ~/Claude_sandbox/RISCV_RV32IMC_5stage/rtl/pkg/brv32p_defs.vh
```

Study `brv32p_soc.v` to understand:
1. How the core is instantiated
2. What signals connect the core to the caches
3. What signals connect the caches to the AXI bus
4. What the core's interrupt inputs are
5. How the existing AXI interconnect is wired

The CPU is written in **Verilog-2001** (`.v` files), not SystemVerilog. The includes use `.vh` files. Compilation must use `-g2005` compatible constructs or `-g2012` with Verilog compatibility.

## What to do

### Step 1: Study the CPU's AXI interface

The BRV32P's caches have AXI miss ports. Find the EXACT port names by reading the cache modules and the top-level SoC. The key signals you need are:

- I-cache AXI master: AR/R channels (instruction fetches are read-only)
- D-cache AXI master: AW/W/B/AR/R channels (data can be read or written)
- Core interrupt inputs: `meip` (machine external interrupt pending) from the PLIC
- Reset and clock

### Step 2: Create `rtl/cpu_subsystem.sv`

Create a SystemVerilog wrapper that:

1. Instantiates `brv32p_core` (the pipeline) with its caches
2. Exposes the I-cache AXI miss port as Master 0 interface (connects to I-MMU adapter)
3. Exposes the D-cache AXI miss port as Master 1 interface (connects to D-MMU adapter)
4. Accepts `meip` interrupt input from the PLIC
5. Accepts `satp` output from the CSR file (for MMU configuration — if the core has a satp CSR; if not, expose a port)
6. Includes the `brv32p_defs.vh` definitions

**Important**: The CPU uses Verilog-2001. Your wrapper is SystemVerilog. Include paths must be set correctly:
```
-I ~/Claude_sandbox/RISCV_RV32IMC_5stage/rtl/pkg
```

If the CPU core's existing SoC wrapper (`brv32p_soc.v`) already bundles the core + caches + AXI interface into a convenient package, you may instantiate a subset of that hierarchy rather than re-wiring everything from scratch. The goal is to extract the CPU's AXI master ports cleanly.

**Alternative approach**: If extracting the core from its SoC wrapper proves too complex (too many internal signals to reconnect), it is acceptable to:
1. Instantiate the entire `brv32p_soc` module
2. Leave its internal SRAM and peripherals connected but unused
3. ALSO connect its AXI master ports (the cache miss paths) to our crossbar
4. The CPU will fetch from our SRAM0 via the crossbar, and we can disable its internal SRAM

Choose whichever approach compiles cleanly. Document your choice.

### Step 3: Wire into riscv_soc_top.sv

Modify `rtl/riscv_soc_top.sv`:

1. Instantiate `cpu_subsystem`
2. Connect I-cache AXI to the existing `cpu_i_*` ports that feed `u_immu_adapter`
3. Connect D-cache AXI to the existing `cpu_d_*` ports that feed `u_dmmu_adapter`
4. Connect `meip` from the PLIC to the CPU
5. Connect clock and reset
6. Remove or gate the external CPU AXI ports — the CPU now drives them internally

If the external testbench AXI ports on `riscv_soc_top` are still needed for testing (driving M0/M1 from outside), add a MUX controlled by a `cpu_enable` port: when high, the CPU drives M0/M1; when low, the external ports drive them. Default `cpu_enable` to 1.

### Step 4: Create test firmware

Create `firmware/test_basic.hex` — a minimal RV32I program in hex format that:

1. Writes a known pattern (e.g. 0xCAFEBABE) to a data SRAM address (0x1000_0000)
2. Reads it back
3. Writes a pass/fail indicator to a GPIO or known memory address
4. Enters an infinite loop (or executes `wfi`)

Use the firmware generation approach from the CPU repo if available (`firmware/gen_firmware.py`), or hand-assemble a few instructions:

```
# Example minimal firmware (RV32I assembly)
# Loads immediate, stores to data SRAM, reads back, loops
_start:
    lui   x1, 0xCAFEB        # x1 = 0xCAFEB000
    addi  x1, x1, 0xABE      # x1 = 0xCAFEBABE (note: sign extension — may need adjustment)
    lui   x2, 0x10000         # x2 = 0x10000000 (data SRAM base)
    sw    x1, 0(x2)           # store to data SRAM
    lw    x3, 0(x2)           # load back
    lui   x4, 0x20000         # x4 = 0x20000000 (peripheral base)
    sw    x3, 0(x4)           # write to GPIO (observable)
loop:
    j     loop                # spin
```

Encode this to hex. If hand-encoding is error-prone, write a Python script `firmware/gen_test_basic.py` that produces the hex file.

### Step 5: Write testbench `tb/sv/tb_cpu_integration.sv`

This testbench:

1. Instantiates `riscv_soc_top` with `cpu_enable=1` (or however the CPU is enabled)
2. Loads `firmware/test_basic.hex` into SRAM0
3. Releases reset
4. Waits a reasonable number of cycles (e.g. 1000) for the CPU to execute the firmware
5. Reads back the data SRAM address (0x1000_0000) via the slave port and verifies the pattern
6. Reports `[PASS]` or `[FAIL]`

If full CPU execution testing is too fragile at this stage (timing issues, cache warmup, etc.), an acceptable alternative is:

1. Verify that the CPU subsystem compiles cleanly with all dependencies
2. Verify that the CPU's AXI master ports are connected and can be observed
3. A "smoke test" that releases reset and verifies the CPU's program counter advances (read via a debug signal or CSR)

### Compilation

```bash
iverilog -g2012 -Wall \
    -I ~/Claude_sandbox/RISCV_RV32IMC_5stage/rtl/pkg \
    -I ~/Claude_sandbox/RISCV_RV32IMC_5stage/rtl/core \
    -c /dev/stdin <<'EOF' -o sim_cpu_int
rtl/soc_pkg.sv
rtl/soc_xbar_pkg.sv
~/Claude_sandbox/MMU/rtl/mmu_pkg.sv
rtl/lru_tracker.sv
~/Claude_sandbox/MMU/rtl/tlb.sv
~/Claude_sandbox/MMU/rtl/permission_checker.sv
~/Claude_sandbox/MMU/rtl/page_table_walker.sv
~/Claude_sandbox/MMU/rtl/mmu_top.sv
~/Claude_sandbox/AXI4_Crossbar/rtl/axi_addr_decoder.sv
~/Claude_sandbox/AXI4_Crossbar/rtl/axi_arbiter.sv
~/Claude_sandbox/AXI4_Crossbar/rtl/axi_err_slave.sv
~/Claude_sandbox/AXI4_Crossbar/rtl/axi_w_path.sv
~/Claude_sandbox/AXI4_Crossbar/rtl/axi_r_path.sv
~/Claude_sandbox/AXI4_Crossbar/rtl/axi_xbar_top.sv
~/Claude_sandbox/RISCV_DMA/rtl/dma_pkg.sv
~/Claude_sandbox/RISCV_DMA/rtl/dma_fifo.sv
~/Claude_sandbox/RISCV_DMA/rtl/dma_reg_file.sv
~/Claude_sandbox/RISCV_DMA/rtl/dma_axi_master.sv
~/Claude_sandbox/RISCV_DMA/rtl/dma_arbiter.sv
~/Claude_sandbox/RISCV_DMA/rtl/dma_channel.sv
~/Claude_sandbox/RISCV_DMA/rtl/dma_top.sv
~/Claude_sandbox/RISCV_IOMMU/rtl/iommu_pkg.sv
~/Claude_sandbox/RISCV_IOMMU/rtl/iotlb.sv
~/Claude_sandbox/RISCV_IOMMU/rtl/device_context_cache.sv
~/Claude_sandbox/RISCV_IOMMU/rtl/io_ptw.sv
~/Claude_sandbox/RISCV_IOMMU/rtl/io_permission_checker.sv
~/Claude_sandbox/RISCV_IOMMU/rtl/fault_handler.sv
~/Claude_sandbox/RISCV_IOMMU/rtl/iommu_reg_file.sv
~/Claude_sandbox/RISCV_IOMMU/rtl/iommu_core.sv
~/Claude_sandbox/RISCV_IOMMU/rtl/iommu_axi_wrapper.sv
rtl/soc_xbar_wrapper.sv
rtl/axi_sram.sv
rtl/axi_periph_bridge.sv
rtl/plic.sv
rtl/sys_reset.sv
rtl/mmu_axi_bridge.sv
rtl/cpu_axi_adapter.sv
rtl/dma_iommu_bridge.sv
~/Claude_sandbox/RISCV_RV32IMC_5stage/rtl/core/brv32p_core.v
~/Claude_sandbox/RISCV_RV32IMC_5stage/rtl/core/decoder.v
~/Claude_sandbox/RISCV_RV32IMC_5stage/rtl/core/compressed_decoder.v
~/Claude_sandbox/RISCV_RV32IMC_5stage/rtl/core/alu.v
~/Claude_sandbox/RISCV_RV32IMC_5stage/rtl/core/regfile.v
~/Claude_sandbox/RISCV_RV32IMC_5stage/rtl/core/muldiv.v
~/Claude_sandbox/RISCV_RV32IMC_5stage/rtl/core/branch_predictor.v
~/Claude_sandbox/RISCV_RV32IMC_5stage/rtl/core/hazard_unit.v
~/Claude_sandbox/RISCV_RV32IMC_5stage/rtl/core/csr.v
~/Claude_sandbox/RISCV_RV32IMC_5stage/rtl/cache/icache.v
~/Claude_sandbox/RISCV_RV32IMC_5stage/rtl/cache/dcache.v
rtl/cpu_subsystem.sv
rtl/riscv_soc_top.sv
tb/sv/tb_cpu_integration.sv
EOF
echo "finish" | vvp sim_cpu_int
```

Adjust the file list based on what you find in the CPU repo — some modules may have different names or there may be additional dependencies. The `-I` flags handle the include paths for `.vh` files.

## Conventions

- `always_ff` with synchronous active-high reset `srst` (for new SV code)
- The CPU repo uses Verilog-2001 — do NOT modify its coding style
- `snake_case` everywhere in new code
- `// Brendan Lynskey 2025` author line
- MIT licence
- `iverilog -g2012 -Wall`
- Use `$stop` not `$finish`
- `always @(*)` for combinational blocks reading submodule outputs
- When running vvp: `echo "finish" | vvp <sim_file>`
- Do NOT modify any files in `~/Claude_sandbox/RISCV_RV32IMC_5stage/` or other subsystem repos
- Do NOT delete or rename any existing files in `RISCV_SoC/`
- PRESERVE all existing module instantiations in `riscv_soc_top.sv`

All tests must show `[PASS]`. Fix any compilation or simulation issues before finishing.
