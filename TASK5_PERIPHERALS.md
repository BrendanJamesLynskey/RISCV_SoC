# Task 5: Wire Peripherals and PLIC Interrupts

## Context

You are working in `~/Claude_sandbox/RISCV_SoC`. Tasks 1-4 are complete:
- Task 1: AXI4 crossbar (3M x 5S)
- Task 2: I-MMU and D-MMU on Masters 0/1
- Task 3: DMA + IOMMU on Master 2, Slaves 3/4
- Task 4: BRV32P CPU core executing firmware through the full path

Currently, peripherals (GPIO, UART, Timer) are stubbed out — `periph_rdata` is tied to zero, interrupt signals are tied low. The peripheral bridge (Slave 2, `axi_periph_bridge.sv`) is wired to the crossbar but has no actual peripherals behind it.

The CPU repo at `~/Claude_sandbox/RISCV_RV32IMC_5stage` contains GPIO, UART, and Timer modules in `rtl/periph/`. Your job is to wire these through the peripheral bridge and connect their interrupts to the PLIC.

## Prerequisites

The CPU repo should already be cloned from Task 4:
```bash
ls ~/Claude_sandbox/RISCV_RV32IMC_5stage/rtl/periph/
```

## Understanding the peripherals

**CRITICAL: Read all three peripheral modules before writing any code.**

```bash
cat ~/Claude_sandbox/RISCV_RV32IMC_5stage/rtl/periph/gpio.v
cat ~/Claude_sandbox/RISCV_RV32IMC_5stage/rtl/periph/uart.v
cat ~/Claude_sandbox/RISCV_RV32IMC_5stage/rtl/periph/timer.v
```

Also re-read our peripheral bridge to understand its output interface:
```bash
cat ~/Claude_sandbox/RISCV_SoC/rtl/axi_periph_bridge.sv
```

The bridge exposes: `periph_wr_en`, `periph_rd_en`, `periph_addr`, `periph_wdata`, `periph_wstrb`, `periph_rdata`.

The peripherals from the CPU repo use a simple register interface. You need to understand their exact port names, address offsets, and interrupt outputs.

## Address sub-decoding within the peripheral space

The peripheral bridge occupies `0x2000_0000` to `0x2000_FFFF`. Within that space:

| Peripheral | Base           | Size  | Offset from periph base |
|-----------|----------------|-------|------------------------|
| GPIO      | 0x2000_0000    | 4 KB  | 0x0000                 |
| UART      | 0x2000_1000    | 4 KB  | 0x1000                 |
| Timer     | 0x2000_2000    | 4 KB  | 0x2000                 |
| PLIC      | 0x2000_3000    | 4 KB  | 0x3000                 |

## What to do

### Step 1: Create `rtl/periph_subsystem.sv`

Create a module that:

1. Accepts the peripheral bridge's register interface (wr_en, rd_en, addr, wdata, wstrb → rdata)
2. Sub-decodes the address to route transactions to the correct peripheral
3. Instantiates `gpio`, `uart`, and `timer` from the CPU repo
4. Instantiates `plic` from our repo (moving its register interface from the stub in riscv_soc_top to here)
5. Muxes `rdata` from the active peripheral back to the bridge
6. Exposes interrupt outputs from each peripheral
7. Exposes GPIO external pins (gpio_in, gpio_out, gpio_oe)
8. Exposes UART external pins (uart_rx, uart_tx)
9. Exposes PLIC's `meip` output

The sub-decode logic uses address bits [13:12] to select the peripheral:
- 2'b00 → GPIO  (offset 0x0000)
- 2'b01 → UART  (offset 0x1000)
- 2'b10 → Timer (offset 0x2000)
- 2'b11 → PLIC  (offset 0x3000)

The CPU repo peripherals are Verilog-2001. Your wrapper is SystemVerilog. Handle the interface adaptation — the peripherals likely use simple `we`, `addr`, `wdata`, `rdata` style ports, which map directly to the bridge's register interface.

### Step 2: Wire into riscv_soc_top.sv

Modify `rtl/riscv_soc_top.sv`:

1. Instantiate `periph_subsystem`
2. Connect it to the peripheral bridge's register interface (replacing the `periph_rdata = '0` tie-off)
3. Connect GPIO external pins to the top-level ports
4. Connect UART external pins to the top-level ports
5. Connect peripheral interrupts to the `irq_sources` signal feeding the PLIC:
   - Timer interrupt → IRQ 0
   - UART TX interrupt → IRQ 1
   - UART RX interrupt → IRQ 2
   - GPIO interrupt → IRQ 3
6. Connect PLIC `meip` to the CPU (this may already be wired from Task 4 — verify and adjust)
7. Remove the stub tie-offs for `timer_irq`, `uart_tx_irq`, `uart_rx_irq`, `gpio_irq`, `gpio_out`, `gpio_oe`, `uart_tx`, and `periph_rdata`

### Step 3: Write testbench `tb/sv/tb_periph_integration.sv`

Test with `cpu_enable=0` (external AXI driving, no CPU) so we can precisely control register accesses:

1. **GPIO write/read**: Write to GPIO data register via peripheral address space (0x2000_0000 + gpio_data_offset), read back, verify
2. **GPIO output**: Write to GPIO direction register (set output), write data, verify `gpio_out` top-level pin reflects the value
3. **Timer write/read**: Write to timer compare register, read back, verify
4. **Timer interrupt**: Set timer compare to a small value, wait, verify timer interrupt fires and PLIC `meip` asserts (requires PLIC enable + priority setup)
5. **UART status read**: Read UART status register, verify it returns a valid value (TX ready, etc.)
6. **PLIC register access**: Write to PLIC enable register at 0x2000_3004, read back, verify
7. **Address decode isolation**: Write to GPIO space, read from UART space — verify no cross-contamination

If the exact register maps of the peripherals are unclear from the source, tests 1-3 and 6-7 are the minimum. Timer interrupt testing (test 4) is a stretch goal.

Drive the tests by issuing AXI transactions to crossbar Slave 2 at the appropriate addresses. You can either drive M1 (CPU D-port) through the external AXI ports, or directly drive the slave port if simpler.

### Compilation

Add the peripheral source files to the compile list:

```bash
iverilog -g2012 -Wall \
    -I ~/Claude_sandbox/RISCV_RV32IMC_5stage/rtl/pkg \
    -I ~/Claude_sandbox/RISCV_RV32IMC_5stage/rtl/core \
    -c filelist.txt -o sim_periph_int
echo "finish" | vvp sim_periph_int
```

Create `filelist.txt` (or use inline heredoc) including all existing sources plus:
```
~/Claude_sandbox/RISCV_RV32IMC_5stage/rtl/periph/gpio.v
~/Claude_sandbox/RISCV_RV32IMC_5stage/rtl/periph/uart.v
~/Claude_sandbox/RISCV_RV32IMC_5stage/rtl/periph/timer.v
rtl/periph_subsystem.sv
```

## Conventions

- `always_ff` with synchronous active-high reset `srst` (for new SV code)
- CPU repo peripherals are Verilog-2001 — do NOT modify them
- `snake_case` everywhere in new code
- `// Brendan Lynskey 2025` author line
- MIT licence
- `iverilog -g2012 -Wall`
- Use `$stop` not `$finish`
- `always @(*)` for combinational blocks reading submodule outputs
- When running vvp: `echo "finish" | vvp <sim_file>`
- Do NOT modify any files in subsystem repos
- Do NOT delete or rename any existing files in `RISCV_SoC/`
- PRESERVE all existing module instantiations in `riscv_soc_top.sv`

All tests must show `[PASS]`. Fix any compilation or simulation issues before finishing.
