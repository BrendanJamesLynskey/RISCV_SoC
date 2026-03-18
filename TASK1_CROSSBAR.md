# Task 1: Wire AXI4 Crossbar into RISCV_SoC

## Context

You are working in the `RISCV_SoC` repository. The `AXI4_Crossbar` repo has already been cloned alongside this one. Your job is to integrate the crossbar into `riscv_soc_top.sv` so that the three master ports and five slave ports are physically wired through it.

## Prerequisites

Clone the crossbar repo as a sibling directory if not already present:

```bash
cd ~/Claude_sandbox
git clone https://github.com/BrendanJamesLynskey/AXI4_Crossbar.git
```

## What to do

### Step 1: Adapt the crossbar address map

The crossbar's `axi_xbar_pkg.sv` has a default 4-slave address map. You need to make it work with our 5-slave SoC address map from `rtl/soc_pkg.sv`:

| Slave | Base         | Mask           | Description        |
|-------|-------------|----------------|--------------------|
| 0     | 0x0000_0000 | 0x0000_FFFF    | Instruction SRAM   |
| 1     | 0x1000_0000 | 0x0001_FFFF    | Data SRAM          |
| 2     | 0x2000_0000 | 0x0000_FFFF    | Peripheral bridge  |
| 3     | 0x3000_0000 | 0x0000_0FFF    | DMA registers      |
| 4     | 0x3000_1000 | 0x0000_0FFF    | IOMMU registers    |

**Do NOT modify** the original `AXI4_Crossbar/rtl/` files. Instead, create a local wrapper or override file in `RISCV_SoC/rtl/` that parameterises the crossbar instantiation with N_MASTERS=3, N_SLAVES=5, and the correct address map.

### Step 2: Create `soc_xbar_wrapper.sv`

Create `rtl/soc_xbar_wrapper.sv` that:

1. Instantiates `axi_xbar_top` from the crossbar repo
2. Sets N_MASTERS=3, N_SLAVES=5
3. Passes the address map from soc_pkg
4. Exposes clean per-master and per-slave AXI4 interfaces (not packed arrays — individual signal bundles for each port)
5. Uses `soc_pkg::SID_W` for slave-side ID width

### Step 3: Wire the wrapper into riscv_soc_top.sv

Replace the direct slave port connections in `riscv_soc_top.sv` with the crossbar wrapper. The master ports should connect to the existing master signal arrays. The slave ports should connect to the SRAM, peripheral bridge, and tie-off modules already instantiated.

### Step 4: Write a testbench

Create `tb/sv/tb_soc_xbar_wrapper.sv` that:

1. Instantiates the wrapper with simple AXI slave BFMs on all 5 slave ports
2. Tests that a write from Master 0 to address 0x0000_0000 reaches Slave 0
3. Tests that a write from Master 1 to address 0x1000_0000 reaches Slave 1
4. Tests that a write from Master 1 to address 0x2000_0000 reaches Slave 2
5. Tests that a write from Master 2 to address 0x3000_0000 reaches Slave 3
6. Tests that an unmapped address gets DECERR
7. Uses `[PASS]`/`[FAIL]` markers and `$stop`

## Conventions

- `always_ff` with synchronous active-high reset `srst`
- `snake_case` everywhere
- `// Brendan Lynskey 2025` author line
- MIT licence
- `iverilog -g2012 -Wall`
- `$stop` not `$finish`
- `always @(*)` for combinational blocks reading submodule outputs
- Do NOT modify any files in `AXI4_Crossbar/` — treat it as read-only
- Do NOT delete or rename any existing files in `RISCV_SoC/`

## Compilation

The testbench should compile with:

```bash
iverilog -g2012 -Wall -o sim_xbar \
    ~/Claude_sandbox/AXI4_Crossbar/rtl/axi_xbar_pkg.sv \
    ~/Claude_sandbox/AXI4_Crossbar/rtl/axi_addr_decoder.sv \
    ~/Claude_sandbox/AXI4_Crossbar/rtl/axi_arbiter.sv \
    ~/Claude_sandbox/AXI4_Crossbar/rtl/axi_err_slave.sv \
    ~/Claude_sandbox/AXI4_Crossbar/rtl/axi_w_path.sv \
    ~/Claude_sandbox/AXI4_Crossbar/rtl/axi_r_path.sv \
    ~/Claude_sandbox/AXI4_Crossbar/rtl/axi_xbar_top.sv \
    rtl/soc_pkg.sv \
    rtl/soc_xbar_wrapper.sv \
    tb/sv/tb_soc_xbar_wrapper.sv
vvp sim_xbar
```

All tests must show `[PASS]`. Fix any issues before finishing.
