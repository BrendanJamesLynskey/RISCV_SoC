// Brendan Lynskey 2025
// RISC-V SoC — Top-level package
// MIT License

package soc_pkg;

    // =========================================================================
    // Global SoC parameters
    // =========================================================================
    parameter ADDR_W       = 32;
    parameter DATA_W       = 32;
    parameter STRB_W       = DATA_W / 8;
    parameter ID_W         = 4;

    // =========================================================================
    // AXI4 Crossbar configuration
    // =========================================================================
    // Masters: CPU I-port, CPU D-port, DMA
    parameter N_MASTERS    = 3;
    // Slaves:  Boot ROM/SRAM, Main SRAM, Peripheral bridge, DMA regs, IOMMU regs
    parameter N_SLAVES     = 5;
    parameter SID_W        = ID_W + $clog2(N_MASTERS);

    // =========================================================================
    // Address map
    // =========================================================================
    // Slave 0: Boot ROM / SRAM (instruction memory)
    parameter [31:0] SRAM0_BASE = 32'h0000_0000;
    parameter [31:0] SRAM0_MASK = 32'h0000_FFFF;  // 64 KB
    parameter        SRAM0_SIZE = 16384;           // 16K words

    // Slave 1: Main SRAM (data memory)
    parameter [31:0] SRAM1_BASE = 32'h1000_0000;
    parameter [31:0] SRAM1_MASK = 32'h0001_FFFF;  // 128 KB
    parameter        SRAM1_SIZE = 32768;           // 32K words

    // Slave 2: Peripheral bridge (GPIO, UART, Timer)
    parameter [31:0] PERIPH_BASE = 32'h2000_0000;
    parameter [31:0] PERIPH_MASK = 32'h0000_FFFF;  // 64 KB
    // Sub-regions within peripheral space
    parameter [31:0] GPIO_BASE   = 32'h2000_0000;
    parameter [31:0] UART_BASE   = 32'h2000_1000;
    parameter [31:0] TIMER_BASE  = 32'h2000_2000;

    // Slave 3: DMA configuration registers
    parameter [31:0] DMA_BASE    = 32'h3000_0000;
    parameter [31:0] DMA_MASK    = 32'h0000_0FFF;  // 4 KB

    // Slave 4: IOMMU configuration registers
    parameter [31:0] IOMMU_BASE  = 32'h3000_1000;
    parameter [31:0] IOMMU_MASK  = 32'h0000_0FFF;  // 4 KB

    // =========================================================================
    // Interrupt map
    // =========================================================================
    parameter N_EXT_IRQ    = 8;
    parameter IRQ_TIMER    = 0;
    parameter IRQ_UART_TX  = 1;
    parameter IRQ_UART_RX  = 2;
    parameter IRQ_GPIO     = 3;
    parameter IRQ_DMA_CH0  = 4;
    parameter IRQ_DMA_CH1  = 5;
    parameter IRQ_DMA_CH2  = 6;
    parameter IRQ_DMA_CH3  = 7;

    // =========================================================================
    // CPU configuration
    // =========================================================================
    parameter RESET_ADDR   = 32'h0000_0000;

    // =========================================================================
    // Cache configuration (used by Cache_Controller_MESI in L2 role)
    // =========================================================================
    parameter L2_NUM_WAYS  = 4;
    parameter L2_NUM_SETS  = 64;
    parameter L2_LINE_BYTES = 32;

    // =========================================================================
    // MMU configuration
    // =========================================================================
    parameter TLB_ENTRIES  = 16;

endpackage
