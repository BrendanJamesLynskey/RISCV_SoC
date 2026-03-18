# RISC-V SoC — System-on-Chip Integration

A complete RISC-V System-on-Chip integrating six independently verified subsystem repositories into a unified, bus-connected SoC with CPU, caches, virtual memory, DMA, IOMMU, and peripherals.

**Author**: Brendan Lynskey 2025
**Simulator**: Icarus Verilog (`iverilog -g2012`)
**Verification**: SystemVerilog self-checking testbenches + CocoTB

## Architecture

```
                ┌──────────────────────────────────────────────────────────────┐
                │                         RISC-V SoC                          │
                │                                                              │
  ┌──────────┐  │  ┌─────────┐   ┌────────────────┐   ┌────────────────────┐  │
  │ BRV32P   │  │  │  I-MMU  │   │                │   │ SRAM0 (64KB)       │  │
  │ RV32IMC  ├──I─►│  Sv32   ├──►│                ├──►│ Instruction Mem    │  │
  │ 5-stage  │  │  └─────────┘   │                │   └────────────────────┘  │
  │ Pipeline ├──D─►┌─────────┐   │   AXI4 Xbar   │   ┌────────────────────┐  │
  └──────────┘  │  │  D-MMU  │   │   (3M x 5S)   ├──►│ SRAM1 (128KB)      │  │
                │  │  Sv32   ├──►│                │   │ Data Memory        │  │
  ┌──────────┐  │  └─────────┘   │                │   └────────────────────┘  │
  │ DMA      │  │  ┌─────────┐   │                │   ┌────────────────────┐  │
  │ 4-chan   ├────►│ IOMMU   ├──►│                ├──►│ Periph Bridge      │  │
  │ scatter- │  │  │ Sv32    │   │                │   │  ├─ GPIO           │  │
  │ gather   │  │  └─────────┘   │                │   │  ├─ UART           │  │
  └──────────┘  │                │                │   │  └─ Timer          │  │
                │                │                │   └────────────────────┘  │
  ┌──────────┐  │                │                │   ┌────────────────────┐  │
  │ PLIC     ├──── meip ──► CPU  │                ├──►│ DMA Registers      │  │
  │ 8-source │  │                │                │   └────────────────────┘  │
  └──────────┘  │                │                │   ┌────────────────────┐  │
                │                │                ├──►│ IOMMU Registers    │  │
                │                └────────────────┘   └────────────────────┘  │
                └──────────────────────────────────────────────────────────────┘
```

## Subsystem Repositories

This SoC integrates the following independently developed and verified repos:

| Subsystem | Repository | Role in SoC |
|-----------|-----------|-------------|
| CPU Core | [RISCV_RV32IMC_5stage](https://github.com/BrendanJamesLynskey/RISCV_RV32IMC_5stage) | 5-stage pipelined RV32IMC processor with L1 caches |
| Interconnect | [AXI4_Crossbar](https://github.com/BrendanJamesLynskey/AXI4_Crossbar) | NxM AXI4 crossbar with round-robin arbitration |
| MMU | [MMU](https://github.com/BrendanJamesLynskey/MMU) | Sv32 virtual memory with TLB and hardware PTW |
| Cache | [Cache_Controller_MESI](https://github.com/BrendanJamesLynskey/Cache_Controller_MESI) | L2 cache with MESI coherence protocol |
| DMA | [RISCV_DMA](https://github.com/BrendanJamesLynskey/RISCV_DMA) | 4-channel DMA with scatter-gather |
| IOMMU | [RISCV_IOMMU](https://github.com/BrendanJamesLynskey/RISCV_IOMMU) | I/O address translation for DMA isolation |

## Glue Logic (New in This Repo)

The following modules are new integration components not found in the subsystem repos:

| Module | File | Purpose |
|--------|------|---------|
| `soc_pkg` | `rtl/soc_pkg.sv` | Global address map, parameters, interrupt assignments |
| `riscv_soc_top` | `rtl/riscv_soc_top.sv` | Top-level integration wiring all subsystems |
| `axi_sram` | `rtl/axi_sram.sv` | AXI4 SRAM slave (instruction and data memories) |
| `axi_periph_bridge` | `rtl/axi_periph_bridge.sv` | AXI4-to-register bridge for peripherals |
| `plic` | `rtl/plic.sv` | Platform-Level Interrupt Controller (8 sources) |
| `sys_reset` | `rtl/sys_reset.sv` | Async-assert, sync-deassert reset controller |

## Address Map

| Region | Base | Size | Slave | Description |
|--------|------|------|-------|-------------|
| Instruction SRAM | `0x0000_0000` | 64 KB | 0 | Boot ROM / firmware |
| Data SRAM | `0x1000_0000` | 128 KB | 1 | Stack, heap, data |
| Peripherals | `0x2000_0000` | 64 KB | 2 | GPIO, UART, Timer |
| DMA Registers | `0x3000_0000` | 4 KB | 3 | DMA channel config |
| IOMMU Registers | `0x3000_1000` | 4 KB | 4 | IOMMU configuration |

## Interrupt Map

| IRQ | Source | Priority (default) |
|-----|--------|--------------------|
| 0 | Timer | 1 |
| 1 | UART TX | 1 |
| 2 | UART RX | 1 |
| 3 | GPIO | 1 |
| 4–7 | DMA Ch0–3 | 1 |

## Directory Structure

```
RISCV_SoC/
├── rtl/
│   ├── soc_pkg.sv              # SoC parameters and address map
│   ├── riscv_soc_top.sv        # Top-level integration
│   ├── axi_sram.sv             # AXI4 SRAM slave
│   ├── axi_periph_bridge.sv    # AXI4 to peripheral bridge
│   ├── plic.sv                 # Platform-Level Interrupt Controller
│   └── sys_reset.sv            # Reset synchroniser
├── tb/
│   ├── sv/
│   │   ├── tb_riscv_soc_top.sv # Top-level integration TB
│   │   ├── tb_axi_sram.sv      # SRAM unit TB (6 tests)
│   │   ├── tb_plic.sv          # PLIC unit TB (8 tests)
│   │   ├── tb_sys_reset.sv     # Reset unit TB (5 tests)
│   │   ├── tb_cpu_integration.sv    # CPU firmware TB (4 tests)
│   │   ├── tb_mmu_integration.sv    # MMU bypass TB (5 tests)
│   │   ├── tb_dma_iommu_integration.sv # DMA+IOMMU TB (5 tests)
│   │   ├── tb_periph_integration.sv # Peripheral TB (7 tests)
│   │   └── tb_fullsystem.sv        # Full-system firmware TB (7 tests)
│   └── cocotb/
│       ├── test_axi_sram/      # 6 CocoTB tests
│       ├── test_plic/          # 6 CocoTB tests
│       └── test_sys_reset/     # 3 CocoTB tests
├── scripts/
│   ├── run_all_sv.sh           # Run all SV testbenches
│   ├── run_all_cocotb.sh       # Run all CocoTB tests
│   └── run_all.sh              # Run everything
├── firmware/
│   ├── gen_fulltest.py         # Full-system firmware generator
│   ├── fulltest.hex            # Generated firmware (29 RV32I instructions)
│   ├── gen_test_basic.py       # Basic test firmware generator
│   └── test_basic.hex          # Basic test firmware
├── filelist_full.txt           # Iverilog compile file list
├── docs/
│   └── RISCV_SoC_Integration_Report.md
├── CLAUDE_CODE_INSTRUCTIONS.md
├── .gitignore
└── README.md
```

## Building and Running Tests

### Prerequisites

- Icarus Verilog >= 10.0 with `-g2012` support
- Python 3.8+ with cocotb (`pip install cocotb`)

### Run All Tests

```bash
./scripts/run_all.sh
```

### Run SV Tests Only

```bash
./scripts/run_all_sv.sh
```

### Run a Single Module

```bash
./scripts/run_all_sv.sh plic
```

## Test Summary

| Testbench | Sim Binary | Tests | Description |
|-----------|-----------|-------|-------------|
| `tb_riscv_soc_top` | `sim_soc_top` | 8 | Reset, SRAM, PLIC, GPIO, UART tie-offs |
| `tb_cpu_integration` | `sim_cpu_int` | 4 | CPU firmware execution, SRAM write-back |
| `tb_mmu_integration` | `sim_mmu_int` | 5 | MMU bypass mode, AXI read/write paths |
| `tb_dma_iommu_integration` | `sim_dma_iommu` | 5 | DMA transfer, IOMMU passthrough, IRQ |
| `tb_periph_integration` | `sim_periph_int` | 7 | GPIO, UART, Timer, PLIC register access |
| `tb_fullsystem` | `sim_fullsystem` | 7 | Full firmware: SRAM, GPIO, Timer, PLIC, completion marker |
| **Total** | | **36** | |

The full-system test boots the CPU autonomously, executing 29 RV32I instructions that exercise SRAM read/write, GPIO output, timer interrupt generation through the PLIC, and a completion marker — proving all subsystems work together in a single simulation run.

### Firmware Generation

```bash
python3 firmware/gen_fulltest.py   # Generates firmware/fulltest.hex (29 instructions)
```

### Full Build and Run

```bash
iverilog -g2012 -Wall \
    -I ~/Claude_sandbox/RISCV_RV32IMC_5stage/rtl/pkg \
    -I ~/Claude_sandbox/RISCV_RV32IMC_5stage/rtl/core \
    -c filelist_full.txt -o sim_fullsystem
echo "finish" | vvp sim_fullsystem
```

## Integration Strategy

This repo serves as the **system-level integration** layer. Each subsystem repository remains independently maintained and verified. The integration approach:

1. **Git submodules** (recommended): Add each subsystem repo as a git submodule under `deps/`.
2. **Flat copy** (alternative): Copy RTL files from each subsystem into a `deps/` directory.
3. **Build scripts**: The simulation scripts reference subsystem RTL via relative paths.

### Full Build Command (with submodules)

```bash
# After cloning with submodules
iverilog -g2012 -Wall -o sim_soc \
    deps/AXI4_Crossbar/rtl/*.sv \
    deps/MMU/rtl/*.sv \
    deps/Cache_Controller_MESI/rtl/*.sv \
    deps/RISCV_DMA/rtl/*.sv \
    deps/RISCV_IOMMU/rtl/*.sv \
    deps/RISCV_RV32IMC_5stage/rtl/**/*.v \
    rtl/*.sv \
    tb/sv/tb_riscv_soc_top.sv
vvp sim_soc
```

## Design Decisions

- **3 AXI masters**: CPU I-port, CPU D-port, DMA — provides concurrent instruction fetch, data access, and DMA without contention.
- **5 AXI slaves**: Separate instruction and data SRAM allows Harvard-style access. DMA and IOMMU registers are memory-mapped for CPU configuration.
- **MMU on CPU paths**: Both I-port and D-port pass through the Sv32 MMU, enabling full virtual memory for user-mode code.
- **IOMMU on DMA path**: DMA transactions are address-translated by the IOMMU, providing device isolation and enabling safe DMA from user-space page tables.
- **PLIC for interrupts**: Simple priority-based interrupt controller with 8 sources. Software-configurable priorities and enable masks.
- **MESI cache optional**: The Cache_Controller_MESI can be inserted between the MMU and crossbar as an L2. For single-core, the CPU's built-in L1 caches may suffice; the MESI controller demonstrates multi-core readiness.

## Future Extensions

- **Multi-core**: Add a second BRV32P core with MESI cache coherence via the crossbar snoop interface.
- **External memory controller**: Replace SRAM1 with a DDR/PSRAM controller for larger memory.
- **Debug module**: Add RISC-V debug module (dm) with JTAG TAP.
- **Boot ROM**: Replace SRAM0 with a true ROM containing bootloader code.
- **Watchdog timer**: Add a watchdog for system reliability.
- **SPI/I2C**: Extend peripheral bridge with additional interfaces.

## Licence

MIT
