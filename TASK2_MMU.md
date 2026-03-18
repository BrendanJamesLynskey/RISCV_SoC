# Task 2: Wire MMU into RISCV_SoC

## Context

You are working in `~/Claude_sandbox/RISCV_SoC`. Task 1 is complete — the AXI4 crossbar wrapper (`rtl/soc_xbar_wrapper.sv`) connects 3 masters to 5 slaves with all tests passing.

The MMU repo is at `~/Claude_sandbox/MMU` (clone it if not present).

Your job is to create AXI4 wrappers for the MMU and wire two instances (I-MMU and D-MMU) between the CPU stub ports and crossbar masters 0 and 1.

## Prerequisites

```bash
cd ~/Claude_sandbox
git clone https://github.com/BrendanJamesLynskey/MMU.git
```

## Understanding the MMU interface

Read `~/Claude_sandbox/MMU/rtl/mmu_top.sv` carefully before writing any code. The MMU has a **custom request/response interface** on the CPU side and a **memory read interface** for page table walks. It does NOT speak AXI4 natively. You need to bridge both sides.

The MMU's key ports (from mmu_top.sv):
- **CPU side**: `req_valid`, `req_ready`, `req_vaddr`, `req_access_type`, `req_priv_mode` → `resp_valid`, `resp_paddr`, `resp_fault`, `resp_fault_cause`
- **Memory side** (PTW): `mem_req_valid`, `mem_req_ready`, `mem_req_addr` → `mem_resp_valid`, `mem_resp_data`
- **Control**: `satp`, `sfence_valid`, `sfence_asid`, `sfence_vaddr`, `status_sum`, `status_mxr`

## What to do

### Step 1: Create `rtl/mmu_axi_bridge.sv`

This module wraps one `mmu_top` instance and presents:
- **CPU-facing side**: A simple valid/ready address translation interface (virtual address in → physical address out)
- **Bus-facing side**: An AXI4 master interface (for PTW memory reads)

The bridge must:
1. Accept a virtual address + access type from the CPU
2. Pass it to `mmu_top` for translation
3. If TLB hits, return the physical address in 1 cycle
4. If TLB misses, the PTW issues memory reads — the bridge converts these to AXI4 AR/R transactions on its master port
5. Support **bypass mode**: when `satp[31]` (MODE bit) is 0, pass the address through untranslated with no latency

The PTW memory reads are single-beat 32-bit reads. The AXI4 master port only needs to support:
- AR channel (read address)
- R channel (read data)
- No write channels needed (PTW is read-only) — tie AW/W/B to inactive

### Step 2: Create `rtl/cpu_axi_adapter.sv`

The CPU core (BRV32P) has AXI4-Lite miss ports from its L1 caches. In the full SoC, the data path is:

```
CPU I-cache miss → virtual address → I-MMU → physical address → Crossbar M0
CPU D-cache miss → virtual address → D-MMU → physical address → Crossbar M1
```

For now (without the actual CPU core wired in), create a simple adapter that:
1. Accepts an AXI4 master interface (from CPU or testbench)
2. Extracts the address, sends it through `mmu_axi_bridge` for translation
3. Re-issues the AXI4 transaction with the translated physical address to the crossbar
4. Passes read data / write responses back to the CPU

For initial testing, operate in **bypass mode** (satp.MODE = 0) so addresses pass through unchanged. This lets us verify the wiring without needing page tables.

### Step 3: Wire into riscv_soc_top.sv

In `rtl/riscv_soc_top.sv`:
1. Instantiate two `mmu_axi_bridge` instances (I-MMU and D-MMU)
2. Connect their AXI4 master ports to crossbar Masters 0 and 1 via `soc_xbar_wrapper`
3. Add `satp` register input (directly from a port for now, CPU will drive it later)
4. Default `satp` to 0 (bypass mode)
5. The PTW AXI read ports need access to memory — route them through the same crossbar master port (the translated address goes to the crossbar, and the PTW reads also go through the same port since the PTW reads physical addresses that don't need further translation)

### Step 4: Write testbench `tb/sv/tb_mmu_integration.sv`

Test the following scenarios:

1. **Bypass mode read**: satp=0, issue a read to virtual address 0x0000_0010 via M0, verify it arrives at SRAM0 (Slave 0) untranslated
2. **Bypass mode write**: satp=0, issue a write to virtual address 0x1000_0020 via M1, verify data arrives at SRAM1 (Slave 1)
3. **Bypass mode peripheral**: satp=0, issue a read to 0x2000_0000 via M1, verify it reaches Slave 2
4. **Both ports concurrent**: Issue reads on M0 and M1 simultaneously in bypass mode, verify both complete
5. **Address passthrough**: Verify the physical address output equals the virtual address input when in bypass mode

Do NOT test page table walks yet — that requires populated page tables in SRAM. Bypass mode testing is sufficient for this task.

### Compilation

```bash
iverilog -g2012 -Wall -o sim_mmu_int \
    ~/Claude_sandbox/MMU/rtl/mmu_pkg.sv \
    ~/Claude_sandbox/MMU/rtl/lru_tracker.sv \
    ~/Claude_sandbox/MMU/rtl/tlb.sv \
    ~/Claude_sandbox/MMU/rtl/permission_checker.sv \
    ~/Claude_sandbox/MMU/rtl/page_table_walker.sv \
    ~/Claude_sandbox/MMU/rtl/mmu_top.sv \
    ~/Claude_sandbox/AXI4_Crossbar/rtl/axi_xbar_pkg.sv \
    ~/Claude_sandbox/AXI4_Crossbar/rtl/axi_addr_decoder.sv \
    ~/Claude_sandbox/AXI4_Crossbar/rtl/axi_arbiter.sv \
    ~/Claude_sandbox/AXI4_Crossbar/rtl/axi_err_slave.sv \
    ~/Claude_sandbox/AXI4_Crossbar/rtl/axi_w_path.sv \
    ~/Claude_sandbox/AXI4_Crossbar/rtl/axi_r_path.sv \
    ~/Claude_sandbox/AXI4_Crossbar/rtl/axi_xbar_top.sv \
    rtl/soc_pkg.sv \
    rtl/soc_xbar_pkg.sv \
    rtl/soc_xbar_wrapper.sv \
    rtl/axi_sram.sv \
    rtl/mmu_axi_bridge.sv \
    rtl/cpu_axi_adapter.sv \
    rtl/riscv_soc_top.sv \
    tb/sv/tb_mmu_integration.sv
```

If there are package conflicts between `soc_xbar_pkg` and `axi_xbar_pkg`, use ONLY `rtl/soc_xbar_pkg.sv` (our local override) and do NOT include the original `AXI4_Crossbar/rtl/axi_xbar_pkg.sv`.

### Important notes

When running `vvp`, pipe quit to avoid hanging at the interactive prompt:

```bash
echo "quit" | vvp sim_mmu_int
```

## Conventions

- `always_ff` with synchronous active-high reset `srst`
- `snake_case` everywhere
- `// Brendan Lynskey 2025` author line
- MIT licence
- `iverilog -g2012 -Wall`
- Use `$stop` not `$finish`
- `always @(*)` for combinational blocks reading submodule outputs (iverilog compatibility)
- Do NOT modify any files in `~/Claude_sandbox/MMU/` or `~/Claude_sandbox/AXI4_Crossbar/`
- Do NOT delete or rename any existing files in `RISCV_SoC/`
- PRESERVE all existing module instantiations and signal declarations in `riscv_soc_top.sv` — add to them, don't replace

All tests must show `[PASS]`. Fix any compilation or simulation issues before finishing.
