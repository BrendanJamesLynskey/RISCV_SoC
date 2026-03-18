// Brendan Lynskey 2025
// RISC-V SoC Top-Level Integration
// MIT License
//
// Integrates the following subsystem repositories:
//   - RISCV_RV32IMC_5stage  (CPU core)
//   - AXI4_Crossbar         (on-chip interconnect)
//   - MMU                   (Sv32 address translation)
//   - Cache_Controller_MESI (L2 cache with coherence)
//   - RISCV_DMA             (multi-channel DMA controller)
//   - RISCV_IOMMU           (I/O address translation)
//
// Missing pieces provided by this repo:
//   - AXI SRAM slaves       (instruction + data memory)
//   - AXI Peripheral bridge (GPIO, UART, Timer access)
//   - PLIC                  (interrupt controller)
//   - System reset          (async-to-sync reset)
//   - SoC-level wiring      (this file)
//
// Architecture:
//
//   CPU I-port ──► MMU ──► [Master 0]──┐
//                                      │
//   CPU D-port ──► MMU ──► [Master 1]──┤──► AXI4 Crossbar ──┬─► SRAM0 (Instr)
//                                      │                     ├─► SRAM1 (Data)
//   DMA ──► IOMMU ──────► [Master 2]──┘                     ├─► Periph Bridge
//                                                            ├─► DMA Regs
//                                                            └─► IOMMU Regs
//
//   Periph Bridge ──► GPIO, UART, Timer
//   PLIC ◄── GPIO_irq, UART_irq, Timer_irq, DMA_irq[3:0]
//   PLIC ──► CPU meip
//

module riscv_soc_top #(
    parameter INIT_FILE = "firmware.hex"
)(
    input  logic        clk,
    input  logic        ext_rst_n,

    // GPIO external pins
    input  logic [31:0] gpio_in,
    output logic [31:0] gpio_out,
    output logic [31:0] gpio_oe,

    // UART external pins
    input  logic        uart_rx,
    output logic        uart_tx
);

    import soc_pkg::*;

    // =========================================================================
    // Reset synchroniser
    // =========================================================================
    logic srst;
    sys_reset u_sys_reset (
        .clk       (clk),
        .ext_rst_n (ext_rst_n),
        .srst      (srst)
    );

    // =========================================================================
    // Signal declarations
    // =========================================================================

    // CPU core outputs (instruction port — AXI4-Lite from BRV32P)
    // In the full integration, the CPU's I-cache and D-cache AXI ports
    // connect through the MMU before reaching the crossbar.
    // For this integration wrapper, we define the AXI master interfaces
    // that connect to the crossbar.

    // Master AXI interfaces [N_MASTERS-1:0] — after MMU/IOMMU translation
    // Master 0: CPU I-port (post-MMU)
    // Master 1: CPU D-port (post-MMU)
    // Master 2: DMA (post-IOMMU)

    // Crossbar master-side signals (arrays)
    logic [N_MASTERS-1:0]                m_awvalid;
    logic [N_MASTERS-1:0]                m_awready;
    logic [N_MASTERS*ADDR_W-1:0]         m_awaddr;
    logic [N_MASTERS*ID_W-1:0]           m_awid;
    logic [N_MASTERS*8-1:0]              m_awlen;
    logic [N_MASTERS*3-1:0]              m_awsize;
    logic [N_MASTERS*2-1:0]              m_awburst;

    logic [N_MASTERS-1:0]                m_wvalid;
    logic [N_MASTERS-1:0]                m_wready;
    logic [N_MASTERS*DATA_W-1:0]         m_wdata;
    logic [N_MASTERS*STRB_W-1:0]         m_wstrb;
    logic [N_MASTERS-1:0]                m_wlast;

    logic [N_MASTERS-1:0]                m_bvalid;
    logic [N_MASTERS-1:0]                m_bready;
    logic [N_MASTERS*ID_W-1:0]           m_bid;
    logic [N_MASTERS*2-1:0]              m_bresp;

    logic [N_MASTERS-1:0]                m_arvalid;
    logic [N_MASTERS-1:0]                m_arready;
    logic [N_MASTERS*ADDR_W-1:0]         m_araddr;
    logic [N_MASTERS*ID_W-1:0]           m_arid;
    logic [N_MASTERS*8-1:0]              m_arlen;
    logic [N_MASTERS*3-1:0]              m_arsize;
    logic [N_MASTERS*2-1:0]              m_arburst;

    logic [N_MASTERS-1:0]                m_rvalid;
    logic [N_MASTERS-1:0]                m_rready;
    logic [N_MASTERS*DATA_W-1:0]         m_rdata;
    logic [N_MASTERS*ID_W-1:0]           m_rid;
    logic [N_MASTERS*2-1:0]              m_rresp;
    logic [N_MASTERS-1:0]                m_rlast;

    // Crossbar slave-side signals (arrays)
    logic [N_SLAVES-1:0]                 s_awvalid;
    logic [N_SLAVES-1:0]                 s_awready;
    logic [N_SLAVES*ADDR_W-1:0]          s_awaddr;
    logic [N_SLAVES*SID_W-1:0]           s_awid;
    logic [N_SLAVES*8-1:0]               s_awlen;
    logic [N_SLAVES*3-1:0]               s_awsize;
    logic [N_SLAVES*2-1:0]               s_awburst;

    logic [N_SLAVES-1:0]                 s_wvalid;
    logic [N_SLAVES-1:0]                 s_wready;
    logic [N_SLAVES*DATA_W-1:0]          s_wdata;
    logic [N_SLAVES*STRB_W-1:0]          s_wstrb;
    logic [N_SLAVES-1:0]                 s_wlast;

    logic [N_SLAVES-1:0]                 s_bvalid;
    logic [N_SLAVES-1:0]                 s_bready;
    logic [N_SLAVES*SID_W-1:0]           s_bid;
    logic [N_SLAVES*2-1:0]               s_bresp;

    logic [N_SLAVES-1:0]                 s_arvalid;
    logic [N_SLAVES-1:0]                 s_arready;
    logic [N_SLAVES*ADDR_W-1:0]          s_araddr;
    logic [N_SLAVES*SID_W-1:0]           s_arid;
    logic [N_SLAVES*8-1:0]               s_arlen;
    logic [N_SLAVES*3-1:0]               s_arsize;
    logic [N_SLAVES*2-1:0]               s_arburst;

    logic [N_SLAVES-1:0]                 s_rvalid;
    logic [N_SLAVES-1:0]                 s_rready;
    logic [N_SLAVES*DATA_W-1:0]          s_rdata;
    logic [N_SLAVES*SID_W-1:0]           s_rid;
    logic [N_SLAVES*2-1:0]               s_rresp;
    logic [N_SLAVES-1:0]                 s_rlast;

    // Peripheral bridge signals
    logic                periph_wr_en;
    logic                periph_rd_en;
    logic [ADDR_W-1:0]   periph_addr;
    logic [DATA_W-1:0]   periph_wdata;
    logic [STRB_W-1:0]   periph_wstrb;
    logic [DATA_W-1:0]   periph_rdata;

    // Interrupt signals
    logic [N_EXT_IRQ-1:0] irq_sources;
    logic                  meip;
    logic                  timer_irq;
    logic                  uart_tx_irq, uart_rx_irq;
    logic                  gpio_irq;
    logic [3:0]            dma_irq;

    assign irq_sources[IRQ_TIMER]   = timer_irq;
    assign irq_sources[IRQ_UART_TX] = uart_tx_irq;
    assign irq_sources[IRQ_UART_RX] = uart_rx_irq;
    assign irq_sources[IRQ_GPIO]    = gpio_irq;
    assign irq_sources[IRQ_DMA_CH0] = dma_irq[0];
    assign irq_sources[IRQ_DMA_CH1] = dma_irq[1];
    assign irq_sources[IRQ_DMA_CH2] = dma_irq[2];
    assign irq_sources[IRQ_DMA_CH3] = dma_irq[3];

    // =========================================================================
    // CPU Core (BRV32P — 5-stage pipelined RV32IMC)
    // =========================================================================
    // The CPU core from RISCV_RV32IMC_5stage provides:
    //   - Instruction AXI4-Lite port (I-cache miss path)
    //   - Data AXI4-Lite port (D-cache miss path)
    //
    // In the full SoC, these would be wired through the MMU for virtual
    // address translation before reaching the crossbar. For simulation
    // without the full CPU instantiation, we provide stub master ports.
    //
    // INTEGRATION NOTE: Replace the stub assignments below with actual
    // CPU core instantiation when assembling the final build:
    //
    //   brv32p_soc u_cpu (
    //       .clk       (clk),
    //       .srst      (srst),
    //       .meip      (meip),
    //       // I-port AXI → m_*[0]
    //       // D-port AXI → m_*[1]
    //       ...
    //   );

    // Stub: CPU I-port (Master 0) — driven by testbench in simulation
    // Stub: CPU D-port (Master 1) — driven by testbench in simulation
    // Stub: DMA master (Master 2) — driven by DMA controller

    // =========================================================================
    // AXI4 Crossbar (from AXI4_Crossbar repo)
    // =========================================================================
    axi_xbar_top u_xbar (
        .clk            (clk),
        .srst           (srst),
        // Master side
        .m_awvalid      (m_awvalid),
        .m_awready      (m_awready),
        .m_awid_flat    (m_awid),
        .m_awaddr_flat  (m_awaddr),
        .m_awlen_flat   (m_awlen),
        .m_awsize_flat  (m_awsize),
        .m_awburst_flat (m_awburst),
        .m_wvalid       (m_wvalid),
        .m_wready       (m_wready),
        .m_wdata_flat   (m_wdata),
        .m_wstrb_flat   (m_wstrb),
        .m_wlast        (m_wlast),
        .m_bvalid       (m_bvalid),
        .m_bready       (m_bready),
        .m_bid_flat     (m_bid),
        .m_bresp_flat   (m_bresp),
        .m_arvalid      (m_arvalid),
        .m_arready      (m_arready),
        .m_arid_flat    (m_arid),
        .m_araddr_flat  (m_araddr),
        .m_arlen_flat   (m_arlen),
        .m_arsize_flat  (m_arsize),
        .m_arburst_flat (m_arburst),
        .m_rvalid       (m_rvalid),
        .m_rready       (m_rready),
        .m_rid_flat     (m_rid),
        .m_rdata_flat   (m_rdata),
        .m_rresp_flat   (m_rresp),
        .m_rlast        (m_rlast),
        // Slave side
        .s_awvalid      (s_awvalid),
        .s_awready      (s_awready),
        .s_awid_flat    (s_awid),
        .s_awaddr_flat  (s_awaddr),
        .s_awlen_flat   (s_awlen),
        .s_awsize_flat  (s_awsize),
        .s_awburst_flat (s_awburst),
        .s_wvalid       (s_wvalid),
        .s_wready       (s_wready),
        .s_wdata_flat   (s_wdata),
        .s_wstrb_flat   (s_wstrb),
        .s_wlast        (s_wlast),
        .s_bvalid       (s_bvalid),
        .s_bready       (s_bready),
        .s_bid_flat     (s_bid),
        .s_bresp_flat   (s_bresp),
        .s_arvalid      (s_arvalid),
        .s_arready      (s_arready),
        .s_arid_flat    (s_arid),
        .s_araddr_flat  (s_araddr),
        .s_arlen_flat   (s_arlen),
        .s_arsize_flat  (s_arsize),
        .s_arburst_flat (s_arburst),
        .s_rvalid       (s_rvalid),
        .s_rready       (s_rready),
        .s_rid_flat     (s_rid),
        .s_rdata_flat   (s_rdata),
        .s_rresp_flat   (s_rresp),
        .s_rlast        (s_rlast)
    );

    // =========================================================================
    // Instruction SRAM (Slave 0)
    // =========================================================================
    axi_sram #(
        .ADDR_W    (ADDR_W),
        .DATA_W    (DATA_W),
        .ID_W      (SID_W),
        .DEPTH     (SRAM0_SIZE),
        .INIT_FILE (INIT_FILE)
    ) u_sram0 (
        .clk     (clk),
        .srst    (srst),
        .awvalid (s_awvalid[0]),
        .awready (s_awready[0]),
        .awaddr  (s_awaddr[0*ADDR_W +: ADDR_W]),
        .awid    (s_awid[0*SID_W +: SID_W]),
        .awlen   (s_awlen[0*8 +: 8]),
        .awsize  (s_awsize[0*3 +: 3]),
        .awburst (s_awburst[0*2 +: 2]),
        .wvalid  (s_wvalid[0]),
        .wready  (s_wready[0]),
        .wdata   (s_wdata[0*DATA_W +: DATA_W]),
        .wstrb   (s_wstrb[0*STRB_W +: STRB_W]),
        .wlast   (s_wlast[0]),
        .bvalid  (s_bvalid[0]),
        .bready  (s_bready[0]),
        .bid     (s_bid[0*SID_W +: SID_W]),
        .bresp   (s_bresp[0*2 +: 2]),
        .arvalid (s_arvalid[0]),
        .arready (s_arready[0]),
        .araddr  (s_araddr[0*ADDR_W +: ADDR_W]),
        .arid    (s_arid[0*SID_W +: SID_W]),
        .arlen   (s_arlen[0*8 +: 8]),
        .arsize  (s_arsize[0*3 +: 3]),
        .arburst (s_arburst[0*2 +: 2]),
        .rvalid  (s_rvalid[0]),
        .rready  (s_rready[0]),
        .rdata   (s_rdata[0*DATA_W +: DATA_W]),
        .rid     (s_rid[0*SID_W +: SID_W]),
        .rresp   (s_rresp[0*2 +: 2]),
        .rlast   (s_rlast[0])
    );

    // =========================================================================
    // Data SRAM (Slave 1)
    // =========================================================================
    axi_sram #(
        .ADDR_W    (ADDR_W),
        .DATA_W    (DATA_W),
        .ID_W      (SID_W),
        .DEPTH     (SRAM1_SIZE),
        .INIT_FILE ("")
    ) u_sram1 (
        .clk     (clk),
        .srst    (srst),
        .awvalid (s_awvalid[1]),
        .awready (s_awready[1]),
        .awaddr  (s_awaddr[1*ADDR_W +: ADDR_W]),
        .awid    (s_awid[1*SID_W +: SID_W]),
        .awlen   (s_awlen[1*8 +: 8]),
        .awsize  (s_awsize[1*3 +: 3]),
        .awburst (s_awburst[1*2 +: 2]),
        .wvalid  (s_wvalid[1]),
        .wready  (s_wready[1]),
        .wdata   (s_wdata[1*DATA_W +: DATA_W]),
        .wstrb   (s_wstrb[1*STRB_W +: STRB_W]),
        .wlast   (s_wlast[1]),
        .bvalid  (s_bvalid[1]),
        .bready  (s_bready[1]),
        .bid     (s_bid[1*SID_W +: SID_W]),
        .bresp   (s_bresp[1*2 +: 2]),
        .arvalid (s_arvalid[1]),
        .arready (s_arready[1]),
        .araddr  (s_araddr[1*ADDR_W +: ADDR_W]),
        .arid    (s_arid[1*SID_W +: SID_W]),
        .arlen   (s_arlen[1*8 +: 8]),
        .arsize  (s_arsize[1*3 +: 3]),
        .arburst (s_arburst[1*2 +: 2]),
        .rvalid  (s_rvalid[1]),
        .rready  (s_rready[1]),
        .rdata   (s_rdata[1*DATA_W +: DATA_W]),
        .rid     (s_rid[1*SID_W +: SID_W]),
        .rresp   (s_rresp[1*2 +: 2]),
        .rlast   (s_rlast[1])
    );

    // =========================================================================
    // Peripheral Bridge (Slave 2)
    // =========================================================================
    axi_periph_bridge #(
        .ADDR_W (ADDR_W),
        .DATA_W (DATA_W),
        .ID_W   (SID_W)
    ) u_periph_bridge (
        .clk         (clk),
        .srst        (srst),
        .awvalid     (s_awvalid[2]),
        .awready     (s_awready[2]),
        .awaddr      (s_awaddr[2*ADDR_W +: ADDR_W]),
        .awid        (s_awid[2*SID_W +: SID_W]),
        .awlen       (s_awlen[2*8 +: 8]),
        .awsize      (s_awsize[2*3 +: 3]),
        .awburst     (s_awburst[2*2 +: 2]),
        .wvalid      (s_wvalid[2]),
        .wready      (s_wready[2]),
        .wdata       (s_wdata[2*DATA_W +: DATA_W]),
        .wstrb       (s_wstrb[2*STRB_W +: STRB_W]),
        .wlast       (s_wlast[2]),
        .bvalid      (s_bvalid[2]),
        .bready      (s_bready[2]),
        .bid         (s_bid[2*SID_W +: SID_W]),
        .bresp       (s_bresp[2*2 +: 2]),
        .arvalid     (s_arvalid[2]),
        .arready     (s_arready[2]),
        .araddr      (s_araddr[2*ADDR_W +: ADDR_W]),
        .arid        (s_arid[2*SID_W +: SID_W]),
        .arlen       (s_arlen[2*8 +: 8]),
        .arsize      (s_arsize[2*3 +: 3]),
        .arburst     (s_arburst[2*2 +: 2]),
        .rvalid      (s_rvalid[2]),
        .rready      (s_rready[2]),
        .rdata       (s_rdata[2*DATA_W +: DATA_W]),
        .rid         (s_rid[2*SID_W +: SID_W]),
        .rresp       (s_rresp[2*2 +: 2]),
        .rlast       (s_rlast[2]),
        .periph_wr_en(periph_wr_en),
        .periph_rd_en(periph_rd_en),
        .periph_addr (periph_addr),
        .periph_wdata(periph_wdata),
        .periph_wstrb(periph_wstrb),
        .periph_rdata(periph_rdata)
    );

    // =========================================================================
    // PLIC — Platform-Level Interrupt Controller
    // =========================================================================
    plic #(
        .N_SOURCES (N_EXT_IRQ),
        .ADDR_W    (ADDR_W),
        .DATA_W    (DATA_W)
    ) u_plic (
        .clk         (clk),
        .srst        (srst),
        .irq_sources (irq_sources),
        .meip        (meip),
        .reg_wr_en   (1'b0),   // TODO: connect via peripheral bridge sub-decode
        .reg_rd_en   (1'b0),
        .reg_addr    ('0),
        .reg_wdata   ('0),
        .reg_rdata   ()
    );

    // =========================================================================
    // Peripheral stubs (GPIO, UART, Timer IRQ sources)
    // =========================================================================
    // In the full build, these are instantiated from the BRV32P repo's
    // periph/ directory. Here we provide tie-offs for standalone simulation.
    assign timer_irq   = 1'b0;
    assign uart_tx_irq = 1'b0;
    assign uart_rx_irq = 1'b0;
    assign gpio_irq    = 1'b0;
    assign dma_irq     = 4'b0;
    assign gpio_out    = '0;
    assign gpio_oe     = '0;
    assign uart_tx     = 1'b1;  // idle high
    assign periph_rdata = '0;

    // =========================================================================
    // Default slave tie-offs (Slaves 3, 4 — DMA regs, IOMMU regs)
    // =========================================================================
    // These will be connected to DMA and IOMMU register interfaces in full build.
    genvar si;
    generate
        for (si = 3; si < N_SLAVES; si++) begin : gen_slave_tieoff
            assign s_awready[si] = 1'b1;
            assign s_wready[si]  = 1'b1;
            assign s_bvalid[si]  = 1'b0;
            assign s_bid[si*SID_W +: SID_W] = '0;
            assign s_bresp[si*2 +: 2] = 2'b00;
            assign s_arready[si] = 1'b1;
            assign s_rvalid[si]  = 1'b0;
            assign s_rdata[si*DATA_W +: DATA_W] = '0;
            assign s_rid[si*SID_W +: SID_W] = '0;
            assign s_rresp[si*2 +: 2] = 2'b00;
            assign s_rlast[si]   = 1'b0;
        end
    endgenerate

endmodule
