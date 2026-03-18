# Task 3: Wire DMA and IOMMU into RISCV_SoC

## Context

You are working in `~/Claude_sandbox/RISCV_SoC`. Tasks 1 and 2 are complete:
- Task 1: AXI4 crossbar (3M x 5S) wired and tested
- Task 2: I-MMU and D-MMU on Masters 0 and 1, bypass mode tested

The DMA and IOMMU repos are at `~/Claude_sandbox/RISCV_DMA` and `~/Claude_sandbox/RISCV_IOMMU`. Clone them if not present.

Your job is to wire the DMA controller's AXI4 master through the IOMMU and onto crossbar Master 2, and connect the DMA and IOMMU register interfaces to crossbar Slaves 3 and 4.

## Prerequisites

```bash
cd ~/Claude_sandbox
git clone https://github.com/BrendanJamesLynskey/RISCV_DMA.git
git clone https://github.com/BrendanJamesLynskey/RISCV_IOMMU.git
```

## Understanding the interfaces

### DMA (dma_top.sv)

Read `~/Claude_sandbox/RISCV_DMA/rtl/dma_top.sv` and `dma_pkg.sv` carefully.

The DMA has:
- **AXI4 master port**: For DMA read/write transfers to memory (this goes through IOMMU → crossbar M2)
- **Register slave interface**: Memory-mapped config registers for CPU to program channels (this connects to crossbar Slave 3)
- **Interrupt outputs**: Per-channel transfer-complete and error interrupts

### IOMMU (iommu_axi_wrapper.sv)

Read `~/Claude_sandbox/RISCV_IOMMU/rtl/iommu_axi_wrapper.sv` and `iommu_pkg.sv` carefully.

The IOMMU has:
- **AXI4 slave port** (device side): Accepts DMA transactions with device virtual addresses
- **AXI4 master port** (memory side): Forwards translated transactions to memory (connects to crossbar M2)
- **Register interface**: Memory-mapped configuration registers (connects to crossbar Slave 4)
- **PTW memory reads**: The IOMMU's page table walker reads page tables from memory via its AXI4 master port

The data flow is: DMA AXI master → IOMMU AXI slave → (translate) → IOMMU AXI master → Crossbar Master 2

## What to do

### Step 1: Study the actual port signatures

Before writing any code, read the RTL files and note the EXACT port names and widths. Do not assume — the DMA and IOMMU may have their own parameter packages with different naming conventions. Print the port lists:

```bash
head -100 ~/Claude_sandbox/RISCV_DMA/rtl/dma_top.sv
head -100 ~/Claude_sandbox/RISCV_IOMMU/rtl/iommu_axi_wrapper.sv
```

### Step 2: Create `rtl/dma_iommu_bridge.sv`

Create a wrapper module that:

1. Instantiates `dma_top` from the DMA repo
2. Instantiates `iommu_axi_wrapper` from the IOMMU repo
3. Connects DMA's AXI4 master to IOMMU's AXI4 slave (device side)
4. Exposes the IOMMU's AXI4 master as the output (connects to crossbar M2)
5. Exposes the DMA's register interface as an AXI4 slave (for crossbar S3)
6. Exposes the IOMMU's register interface as an AXI4 slave (for crossbar S4)
7. Exposes DMA interrupt outputs
8. Handles any parameter or ID width mismatches between the subsystems

If the DMA and IOMMU use their own packages, import them. Handle any naming conflicts carefully.

### Step 3: Wire into riscv_soc_top.sv

In `rtl/riscv_soc_top.sv`:

1. Instantiate `dma_iommu_bridge`
2. Connect the IOMMU AXI master output to crossbar Master 2 (replacing the current M2 tie-off)
3. Connect the DMA register slave to crossbar Slave 3 (replacing the current S3 tie-off)
4. Connect the IOMMU register slave to crossbar Slave 4 (replacing the current S4 tie-off)
5. Connect DMA interrupts to the `dma_irq` signal that feeds the PLIC
6. Set IOMMU to bypass/passthrough mode by default (so DMA addresses pass through untranslated initially)

### Step 4: Write testbench `tb/sv/tb_dma_iommu_integration.sv`

Test the following scenarios with IOMMU in bypass mode:

1. **DMA register write/read**: Write a value to DMA channel 0 source address register via Slave 3, read it back, verify match
2. **IOMMU register write/read**: Write a value to an IOMMU register via Slave 4, read it back, verify match
3. **DMA simple transfer**: Program DMA channel 0 for a short memory-to-memory transfer (e.g. 4 words from SRAM0 to SRAM1), start it, wait for completion interrupt or status, verify destination data matches source
4. **DMA interrupt**: Verify DMA transfer-complete interrupt is asserted after a transfer completes
5. **Address passthrough**: Verify DMA transactions pass through the IOMMU untranslated when IOMMU is in bypass mode

If DMA transfer testing is too complex due to the DMA's internal FSM and register programming sequence, it is acceptable to simplify tests 3-5 to just verify that the DMA's AXI master port transactions reach the crossbar correctly. The key verification goal is that the signal path DMA → IOMMU → Crossbar M2 is wired correctly, and that register access to S3 and S4 works.

### Step 5: Verify compilation

The compilation line will be long. Build it incrementally:

```bash
# First verify the bridge compiles standalone
iverilog -g2012 -Wall -c /dev/stdin <<'EOF' -o sim_dma_iommu
~/Claude_sandbox/RISCV_DMA/rtl/dma_pkg.sv
~/Claude_sandbox/RISCV_DMA/rtl/dma_fifo.sv
~/Claude_sandbox/RISCV_DMA/rtl/dma_reg_file.sv
~/Claude_sandbox/RISCV_DMA/rtl/dma_axi_master.sv
~/Claude_sandbox/RISCV_DMA/rtl/dma_arbiter.sv
~/Claude_sandbox/RISCV_DMA/rtl/dma_channel.sv
~/Claude_sandbox/RISCV_DMA/rtl/dma_top.sv
~/Claude_sandbox/RISCV_IOMMU/rtl/iommu_pkg.sv
~/Claude_sandbox/RISCV_IOMMU/rtl/lru_tracker.sv
~/Claude_sandbox/RISCV_IOMMU/rtl/iotlb.sv
~/Claude_sandbox/RISCV_IOMMU/rtl/device_context_cache.sv
~/Claude_sandbox/RISCV_IOMMU/rtl/io_ptw.sv
~/Claude_sandbox/RISCV_IOMMU/rtl/io_permission_checker.sv
~/Claude_sandbox/RISCV_IOMMU/rtl/fault_handler.sv
~/Claude_sandbox/RISCV_IOMMU/rtl/iommu_reg_file.sv
~/Claude_sandbox/RISCV_IOMMU/rtl/iommu_core.sv
~/Claude_sandbox/RISCV_IOMMU/rtl/iommu_axi_wrapper.sv
rtl/soc_pkg.sv
rtl/soc_xbar_pkg.sv
rtl/soc_xbar_wrapper.sv
rtl/axi_sram.sv
rtl/axi_periph_bridge.sv
rtl/plic.sv
rtl/sys_reset.sv
rtl/mmu_axi_bridge.sv
rtl/cpu_axi_adapter.sv
rtl/dma_iommu_bridge.sv
rtl/riscv_soc_top.sv
~/Claude_sandbox/AXI4_Crossbar/rtl/axi_addr_decoder.sv
~/Claude_sandbox/AXI4_Crossbar/rtl/axi_arbiter.sv
~/Claude_sandbox/AXI4_Crossbar/rtl/axi_err_slave.sv
~/Claude_sandbox/AXI4_Crossbar/rtl/axi_w_path.sv
~/Claude_sandbox/AXI4_Crossbar/rtl/axi_r_path.sv
~/Claude_sandbox/AXI4_Crossbar/rtl/axi_xbar_top.sv
~/Claude_sandbox/MMU/rtl/mmu_pkg.sv
~/Claude_sandbox/MMU/rtl/lru_tracker.sv
~/Claude_sandbox/MMU/rtl/tlb.sv
~/Claude_sandbox/MMU/rtl/permission_checker.sv
~/Claude_sandbox/MMU/rtl/page_table_walker.sv
~/Claude_sandbox/MMU/rtl/mmu_top.sv
tb/sv/tb_dma_iommu_integration.sv
EOF
echo "finish" | vvp sim_dma_iommu
```

If there are duplicate module names (e.g. `lru_tracker` exists in both MMU and IOMMU repos), you'll need to handle this. Options:
- If the modules are identical, include only one copy
- If they differ, one repo may need a wrapper with a renamed module — create that wrapper in `RISCV_SoC/rtl/` (do NOT modify the original repos)

## Conventions

- `always_ff` with synchronous active-high reset `srst`
- `snake_case` everywhere
- `// Brendan Lynskey 2025` author line
- MIT licence
- `iverilog -g2012 -Wall`
- Use `$stop` not `$finish`
- `always @(*)` for combinational blocks reading submodule outputs (iverilog compatibility)
- When running vvp: `echo "finish" | vvp <sim_file>`
- Do NOT modify any files in `~/Claude_sandbox/RISCV_DMA/`, `~/Claude_sandbox/RISCV_IOMMU/`, `~/Claude_sandbox/MMU/`, or `~/Claude_sandbox/AXI4_Crossbar/`
- Do NOT delete or rename any existing files in `RISCV_SoC/`
- PRESERVE all existing module instantiations in `riscv_soc_top.sv`

All tests must show `[PASS]`. Fix any compilation or simulation issues before finishing.
