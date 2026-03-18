# RISC-V SoC Integration — Technical Report

**Author**: Brendan Lynskey 2025

## 1. Introduction

This report documents the design and integration of a RISC-V System-on-Chip that unifies six independently developed and verified subsystem repositories into a complete, bus-connected system. The SoC targets the RV32IMC instruction set and includes virtual memory, cache coherence infrastructure, DMA with I/O address translation, and a standard peripheral set.

The primary goal is to demonstrate system-level integration skills — the ability to take individually verified IP blocks, define a coherent address map and bus topology, implement the necessary glue logic, and verify the assembled system end-to-end.

## 2. Subsystem Analysis

### 2.1 CPU Core (RISCV_RV32IMC_5stage)

The BRV32P is a 5-stage in-order pipelined processor implementing the RV32IMC instruction set. It includes 2-way set-associative L1 instruction and data caches (2 KB each), an AXI4-Lite bus interface for cache miss handling, a 2-bit branch predictor with BTB, full data forwarding, and machine-mode CSRs. The existing SoC wrapper (`brv32p_soc.v`) includes a simple 2-master AXI4-Lite interconnect, 32 KB unified SRAM, and GPIO/UART/Timer peripherals.

For this integration, the CPU core is extracted from its local SoC wrapper and connected to the system-level AXI4 crossbar through MMU translation units. The CPU's I-cache and D-cache AXI miss ports become the first two masters on the crossbar.

### 2.2 AXI4 Crossbar (AXI4_Crossbar)

A fully parameterised NxM AXI4 crossbar with independent read and write routing paths, per-slave round-robin arbitration, ID-based response routing (master index prepended to transaction IDs), error slave for unmapped addresses, write path locking until WLAST, and full backpressure propagation. The crossbar is configured for 3 masters and 5 slaves in this SoC, with a system address map defined in `soc_pkg.sv`.

### 2.3 MMU (MMU)

An Sv32 Memory Management Unit with a fully-associative 16-entry TLB (true LRU), hardware two-level page table walker, per-page permission checking (R/W/X, U/S), SFENCE.VMA support, and megapage (4 MiB) support. Two instances are used in the SoC — one for the instruction path and one for the data path. When `satp.MODE = 0` (bare mode), the MMU passes addresses through untranslated, allowing the system to boot without page tables configured.

### 2.4 Cache Controller with MESI Coherence (Cache_Controller_MESI)

A 4-way set-associative cache controller (8 KB default) with full MESI coherence protocol, write-back/write-allocate policy, snoop interface for interconnect coherence, single-entry writeback buffer, and non-cacheable passthrough for MMIO regions. In this single-core SoC, the MESI cache can serve as an optional L2 between the MMU and crossbar. Its true value emerges when a second core is added — the snoop interface enables hardware cache coherence without software intervention.

### 2.5 DMA Controller (RISCV_DMA)

A 4-channel DMA controller with AXI4 master interface, scatter-gather descriptor chains, INCR burst support (up to 16 beats), memory-mapped register interface for CPU configuration, per-channel transfer-complete and error interrupts, and round-robin or fixed-priority channel arbitration. The DMA's AXI master port routes through the IOMMU before reaching the crossbar, and its register interface is accessible as crossbar Slave 3.

### 2.6 IOMMU (RISCV_IOMMU)

An I/O Memory Management Unit implementing Sv32 address translation for DMA device isolation. Features include a fully-associative IOTLB (16 entries), device context cache, hardware page table walker (reusing the Sv32 format), AXI4 slave (device side) and AXI4 master (memory side), register-based fault queue with interrupt, and memory-mapped configuration registers. The IOMMU sits between the DMA controller and crossbar Master 2, translating DMA virtual addresses to physical addresses using per-device page tables.

## 3. Gap Analysis — Missing Pieces

Analysing the six subsystem repos revealed several components needed for a complete SoC that were not present in any individual repo:

### 3.1 System-Level Glue

**AXI SRAM Slaves**: The existing CPU SoC uses a simple `axi_sram.v` module, but the system-level integration needs parameterised SRAM slaves compatible with the full AXI4 protocol (not just AXI4-Lite) and the crossbar's extended ID width. New `axi_sram.sv` supports configurable depth, ID width, burst transfers, and byte-lane writes.

**AXI Peripheral Bridge**: The CPU's peripherals (GPIO, UART, Timer) use a simple register interface, but the crossbar speaks AXI4. The `axi_periph_bridge.sv` module translates AXI4 write/read transactions to a simple valid/ready register bus, handling the AXI handshake protocol and single-beat peripheral accesses.

**Platform-Level Interrupt Controller (PLIC)**: The CPU core supports `meip` (machine external interrupt pending) but needs an interrupt controller to arbitrate between multiple sources. The `plic.sv` module implements a simplified PLIC with 8 sources, software-configurable priorities and enable masks, threshold-based suppression, and claim/complete protocol.

**System Reset Controller**: The subsystem repos assume a synchronous reset signal. The `sys_reset.sv` module provides async-assert/sync-deassert reset generation from an external active-low reset pin, using a 3-stage synchroniser pipeline.

**SoC Package**: A centralised `soc_pkg.sv` defines the system address map, crossbar configuration, interrupt assignments, and global parameters. This ensures consistency across all integration modules and testbenches.

### 3.2 Interface Adaptation

The CPU's AXI4-Lite ports need adaptation to the crossbar's full AXI4 interface. The key differences are burst support (AXI4-Lite is single-beat only) and ID width. The MMU's memory read interface also needs wrapping to generate AXI4 transactions for page table walks.

### 3.3 Not Implemented (Future Work)

The following are identified as desirable but not yet implemented: RISC-V Debug Module (JTAG TAP), Watchdog Timer, SPI/I2C controller, Power Management Unit, Boot ROM (currently using writable SRAM), and PMP (Physical Memory Protection).

## 4. Integration Architecture

### 4.1 Bus Topology

The SoC uses a 3-master, 5-slave AXI4 crossbar as its central interconnect. This topology was chosen because it provides concurrent access paths (CPU instruction fetch, CPU data access, and DMA can all proceed simultaneously to different slaves), the crossbar's per-slave arbitration handles contention when multiple masters target the same slave, and the ID-based response routing eliminates lookup tables.

### 4.2 Memory Map Design

The address map places instruction memory at address zero (standard RISC-V reset vector), data memory at a 256 MB offset to clearly separate code and data spaces, peripherals at 512 MB, and DMA/IOMMU configuration at 768 MB. The MMIO regions (peripherals, DMA regs, IOMMU regs) fall in the non-cacheable address range of the MESI cache controller, ensuring that device register accesses bypass the cache.

### 4.3 Interrupt Architecture

All external interrupt sources (Timer, UART, GPIO, DMA channels) feed into the PLIC, which presents a single `meip` signal to the CPU. Software manages interrupt priorities and masking through the PLIC's memory-mapped registers. The IOMMU's fault interrupt could be added as a ninth source in a future revision.

### 4.4 Data Flow Paths

**Instruction fetch**: CPU IF stage → I-cache → (miss) → I-MMU → AXI4 Crossbar → SRAM0.

**Data access**: CPU MEM stage → D-cache → (miss) → D-MMU → AXI4 Crossbar → SRAM1 or Peripheral Bridge.

**DMA transfer**: DMA channel → IOMMU → AXI4 Crossbar → SRAM0 or SRAM1.

**Peripheral access**: CPU D-port → Crossbar → Peripheral Bridge → GPIO/UART/Timer.

**Page table walk (CPU)**: MMU PTW → memory read → Crossbar → SRAM1 (page tables in data memory).

**Page table walk (IOMMU)**: IOMMU PTW → AXI4 master → Crossbar → SRAM1 (device page tables).

## 5. Verification Strategy

### 5.1 Unit-Level (Subsystem Repos)

Each subsystem repository contains its own comprehensive test suites — both SystemVerilog self-checking testbenches and CocoTB Python tests. These are not duplicated in this repo. Total counts across subsystem repos: approximately 500+ SV tests and 280+ CocoTB tests.

### 5.2 Glue Module Tests

New modules in this repo have dedicated unit testbenches:

| Module | SV Tests | CocoTB Tests | Coverage |
|--------|----------|-------------|----------|
| `sys_reset` | 5 | 3 | Assert, deassert, re-assert, sync stages |
| `plic` | 8 | 6 | Enable/disable, priority, threshold, claim |
| `axi_sram` | 6 | 6 | Write/read, byte-lanes, burst, uninit memory |
| **Glue total** | **19** | **15** | |

### 5.3 Integration Tests

The top-level testbench (`tb_riscv_soc_top.sv`) verifies end-to-end operation: reset synchronisation, SRAM write/read via AXI slave ports, peripheral bridge access, PLIC interrupt assertion, and GPIO/UART tie-off correctness.

## 6. Module Summary

| Module | File | Lines | Purpose |
|--------|------|-------|---------|
| `soc_pkg` | `soc_pkg.sv` | ~60 | Parameters, address map, types |
| `riscv_soc_top` | `riscv_soc_top.sv` | ~300 | Top-level SoC wiring |
| `axi_sram` | `axi_sram.sv` | ~160 | AXI4 SRAM slave |
| `axi_periph_bridge` | `axi_periph_bridge.sv` | ~130 | AXI4 to register bridge |
| `plic` | `plic.sv` | ~120 | Interrupt controller |
| `sys_reset` | `sys_reset.sv` | ~20 | Reset synchroniser |

## 7. Recommendations

### 7.1 Immediate Next Steps

1. **Add subsystem repos as git submodules** under `deps/` and update build scripts to reference them.
2. **Wire the CPU core** by replacing the stub master port assignments in `riscv_soc_top.sv` with actual `brv32p_core` instantiation.
3. **Run full-system simulation** with a firmware .hex file loaded into SRAM0 that exercises all peripherals and DMA.
4. **Add FPGA constraints** for a target board (e.g. Arty A7) and synthesise.

### 7.2 Multi-Core Extension

The MESI cache controller is designed for multi-core use. Adding a second core requires: instantiating a second BRV32P with its own MMU, adding it as Master 3 on a 4-master crossbar, placing MESI cache controllers on both cores' data paths, and connecting the snoop interfaces through the crossbar.

### 7.3 Debug and Production

Adding a RISC-V Debug Module with JTAG TAP would enable GDB-based debugging. A proper boot ROM (read-only memory with bootloader) should replace the writable SRAM0 for production use.

## 8. Conclusion

This integration project demonstrates that the six subsystem repositories compose cleanly into a coherent SoC. The address map, bus topology, and interrupt architecture are designed to be extensible — adding cores, peripherals, or external memory requires only crossbar reconfiguration and address map updates. The modular structure means each subsystem can continue to be developed and verified independently, with integration-level testing catching interface mismatches.
