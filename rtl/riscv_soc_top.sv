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

module riscv_soc_top
    import soc_pkg::*;
#(
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
    output logic        uart_tx,

    // SATP register (CPU will drive this later; default to 0 for bypass)
    input  logic [31:0] satp,

    // CPU I-port AXI4 (pre-MMU, virtual addresses)
    input  logic              cpu_i_awvalid,
    output logic              cpu_i_awready,
    input  logic [ADDR_W-1:0] cpu_i_awaddr,
    input  logic [ID_W-1:0]   cpu_i_awid,
    input  logic [7:0]        cpu_i_awlen,
    input  logic [2:0]        cpu_i_awsize,
    input  logic [1:0]        cpu_i_awburst,
    input  logic              cpu_i_wvalid,
    output logic              cpu_i_wready,
    input  logic [DATA_W-1:0] cpu_i_wdata,
    input  logic [STRB_W-1:0] cpu_i_wstrb,
    input  logic              cpu_i_wlast,
    output logic              cpu_i_bvalid,
    input  logic              cpu_i_bready,
    output logic [ID_W-1:0]   cpu_i_bid,
    output logic [1:0]        cpu_i_bresp,
    input  logic              cpu_i_arvalid,
    output logic              cpu_i_arready,
    input  logic [ADDR_W-1:0] cpu_i_araddr,
    input  logic [ID_W-1:0]   cpu_i_arid,
    input  logic [7:0]        cpu_i_arlen,
    input  logic [2:0]        cpu_i_arsize,
    input  logic [1:0]        cpu_i_arburst,
    output logic              cpu_i_rvalid,
    input  logic              cpu_i_rready,
    output logic [DATA_W-1:0] cpu_i_rdata,
    output logic [ID_W-1:0]   cpu_i_rid,
    output logic [1:0]        cpu_i_rresp,
    output logic              cpu_i_rlast,

    // CPU D-port AXI4 (pre-MMU, virtual addresses)
    input  logic              cpu_d_awvalid,
    output logic              cpu_d_awready,
    input  logic [ADDR_W-1:0] cpu_d_awaddr,
    input  logic [ID_W-1:0]   cpu_d_awid,
    input  logic [7:0]        cpu_d_awlen,
    input  logic [2:0]        cpu_d_awsize,
    input  logic [1:0]        cpu_d_awburst,
    input  logic              cpu_d_wvalid,
    output logic              cpu_d_wready,
    input  logic [DATA_W-1:0] cpu_d_wdata,
    input  logic [STRB_W-1:0] cpu_d_wstrb,
    input  logic              cpu_d_wlast,
    output logic              cpu_d_bvalid,
    input  logic              cpu_d_bready,
    output logic [ID_W-1:0]   cpu_d_bid,
    output logic [1:0]        cpu_d_bresp,
    input  logic              cpu_d_arvalid,
    output logic              cpu_d_arready,
    input  logic [ADDR_W-1:0] cpu_d_araddr,
    input  logic [ID_W-1:0]   cpu_d_arid,
    input  logic [7:0]        cpu_d_arlen,
    input  logic [2:0]        cpu_d_arsize,
    input  logic [1:0]        cpu_d_arburst,
    output logic              cpu_d_rvalid,
    input  logic              cpu_d_rready,
    output logic [DATA_W-1:0] cpu_d_rdata,
    output logic [ID_W-1:0]   cpu_d_rid,
    output logic [1:0]        cpu_d_rresp,
    output logic              cpu_d_rlast,

    // CPU enable: 1 = internal CPU drives M0/M1, 0 = external ports drive M0/M1
    input  logic              cpu_enable
);

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
    // CPU Subsystem (BRV32P core + L1 caches + AXI bridges)
    // =========================================================================
    // When cpu_enable=1, the internal CPU drives M0 (I-cache) and M1 (D-cache).
    // When cpu_enable=0, external ports drive them (for testbench use).

    // Internal CPU subsystem AXI signals
    logic              int_i_awvalid, int_i_wvalid, int_i_bready;
    logic              int_i_arvalid, int_i_rready;
    logic [ADDR_W-1:0] int_i_awaddr, int_i_araddr;
    logic [ID_W-1:0]   int_i_awid, int_i_arid;
    logic [7:0]        int_i_awlen, int_i_arlen;
    logic [2:0]        int_i_awsize, int_i_arsize;
    logic [1:0]        int_i_awburst, int_i_arburst;
    logic [DATA_W-1:0] int_i_wdata;
    logic [STRB_W-1:0] int_i_wstrb;
    logic              int_i_wlast;

    logic              int_d_awvalid, int_d_wvalid, int_d_bready;
    logic              int_d_arvalid, int_d_rready;
    logic [ADDR_W-1:0] int_d_awaddr, int_d_araddr;
    logic [ID_W-1:0]   int_d_awid, int_d_arid;
    logic [7:0]        int_d_awlen, int_d_arlen;
    logic [2:0]        int_d_awsize, int_d_arsize;
    logic [1:0]        int_d_awburst, int_d_arburst;
    logic [DATA_W-1:0] int_d_wdata;
    logic [STRB_W-1:0] int_d_wstrb;
    logic              int_d_wlast;

    cpu_subsystem u_cpu_subsystem (
        .clk        (clk),
        .srst       (srst),
        // I-cache AXI master
        .ic_awvalid (int_i_awvalid),
        .ic_awready (cpu_i_awready),
        .ic_awaddr  (int_i_awaddr),
        .ic_awid    (int_i_awid),
        .ic_awlen   (int_i_awlen),
        .ic_awsize  (int_i_awsize),
        .ic_awburst (int_i_awburst),
        .ic_wvalid  (int_i_wvalid),
        .ic_wready  (cpu_i_wready),
        .ic_wdata   (int_i_wdata),
        .ic_wstrb   (int_i_wstrb),
        .ic_wlast   (int_i_wlast),
        .ic_bvalid  (cpu_i_bvalid),
        .ic_bready  (int_i_bready),
        .ic_bid     (cpu_i_bid),
        .ic_bresp   (cpu_i_bresp),
        .ic_arvalid (int_i_arvalid),
        .ic_arready (cpu_i_arready),
        .ic_araddr  (int_i_araddr),
        .ic_arid    (int_i_arid),
        .ic_arlen   (int_i_arlen),
        .ic_arsize  (int_i_arsize),
        .ic_arburst (int_i_arburst),
        .ic_rvalid  (cpu_i_rvalid),
        .ic_rready  (int_i_rready),
        .ic_rdata   (cpu_i_rdata),
        .ic_rid     (cpu_i_rid),
        .ic_rresp   (cpu_i_rresp),
        .ic_rlast   (cpu_i_rlast),
        // D-cache AXI master
        .dc_awvalid (int_d_awvalid),
        .dc_awready (cpu_d_awready),
        .dc_awaddr  (int_d_awaddr),
        .dc_awid    (int_d_awid),
        .dc_awlen   (int_d_awlen),
        .dc_awsize  (int_d_awsize),
        .dc_awburst (int_d_awburst),
        .dc_wvalid  (int_d_wvalid),
        .dc_wready  (cpu_d_wready),
        .dc_wdata   (int_d_wdata),
        .dc_wstrb   (int_d_wstrb),
        .dc_wlast   (int_d_wlast),
        .dc_bvalid  (cpu_d_bvalid),
        .dc_bready  (int_d_bready),
        .dc_bid     (cpu_d_bid),
        .dc_bresp   (cpu_d_bresp),
        .dc_arvalid (int_d_arvalid),
        .dc_arready (cpu_d_arready),
        .dc_araddr  (int_d_araddr),
        .dc_arid    (int_d_arid),
        .dc_arlen   (int_d_arlen),
        .dc_arsize  (int_d_arsize),
        .dc_arburst (int_d_arburst),
        .dc_rvalid  (cpu_d_rvalid),
        .dc_rready  (int_d_rready),
        .dc_rdata   (cpu_d_rdata),
        .dc_rid     (cpu_d_rid),
        .dc_rresp   (cpu_d_rresp),
        .dc_rlast   (cpu_d_rlast),
        // Interrupts
        .meip       (meip),
        .timer_irq  (timer_irq)
    );

    // Muxed I-port signals: cpu_enable selects internal CPU vs external ports
    logic              sel_i_awvalid, sel_i_wvalid, sel_i_bready;
    logic              sel_i_arvalid, sel_i_rready;
    logic [ADDR_W-1:0] sel_i_awaddr, sel_i_araddr;
    logic [ID_W-1:0]   sel_i_awid, sel_i_arid;
    logic [7:0]        sel_i_awlen, sel_i_arlen;
    logic [2:0]        sel_i_awsize, sel_i_arsize;
    logic [1:0]        sel_i_awburst, sel_i_arburst;
    logic [DATA_W-1:0] sel_i_wdata;
    logic [STRB_W-1:0] sel_i_wstrb;
    logic              sel_i_wlast;

    assign sel_i_awvalid = cpu_enable ? int_i_awvalid : cpu_i_awvalid;
    assign sel_i_awaddr  = cpu_enable ? int_i_awaddr  : cpu_i_awaddr;
    assign sel_i_awid    = cpu_enable ? int_i_awid    : cpu_i_awid;
    assign sel_i_awlen   = cpu_enable ? int_i_awlen   : cpu_i_awlen;
    assign sel_i_awsize  = cpu_enable ? int_i_awsize  : cpu_i_awsize;
    assign sel_i_awburst = cpu_enable ? int_i_awburst : cpu_i_awburst;
    assign sel_i_wvalid  = cpu_enable ? int_i_wvalid  : cpu_i_wvalid;
    assign sel_i_wdata   = cpu_enable ? int_i_wdata   : cpu_i_wdata;
    assign sel_i_wstrb   = cpu_enable ? int_i_wstrb   : cpu_i_wstrb;
    assign sel_i_wlast   = cpu_enable ? int_i_wlast   : cpu_i_wlast;
    assign sel_i_bready  = cpu_enable ? int_i_bready  : cpu_i_bready;
    assign sel_i_arvalid = cpu_enable ? int_i_arvalid : cpu_i_arvalid;
    assign sel_i_araddr  = cpu_enable ? int_i_araddr  : cpu_i_araddr;
    assign sel_i_arid    = cpu_enable ? int_i_arid    : cpu_i_arid;
    assign sel_i_arlen   = cpu_enable ? int_i_arlen   : cpu_i_arlen;
    assign sel_i_arsize  = cpu_enable ? int_i_arsize  : cpu_i_arsize;
    assign sel_i_arburst = cpu_enable ? int_i_arburst : cpu_i_arburst;
    assign sel_i_rready  = cpu_enable ? int_i_rready  : cpu_i_rready;

    // Muxed D-port signals
    logic              sel_d_awvalid, sel_d_wvalid, sel_d_bready;
    logic              sel_d_arvalid, sel_d_rready;
    logic [ADDR_W-1:0] sel_d_awaddr, sel_d_araddr;
    logic [ID_W-1:0]   sel_d_awid, sel_d_arid;
    logic [7:0]        sel_d_awlen, sel_d_arlen;
    logic [2:0]        sel_d_awsize, sel_d_arsize;
    logic [1:0]        sel_d_awburst, sel_d_arburst;
    logic [DATA_W-1:0] sel_d_wdata;
    logic [STRB_W-1:0] sel_d_wstrb;
    logic              sel_d_wlast;

    assign sel_d_awvalid = cpu_enable ? int_d_awvalid : cpu_d_awvalid;
    assign sel_d_awaddr  = cpu_enable ? int_d_awaddr  : cpu_d_awaddr;
    assign sel_d_awid    = cpu_enable ? int_d_awid    : cpu_d_awid;
    assign sel_d_awlen   = cpu_enable ? int_d_awlen   : cpu_d_awlen;
    assign sel_d_awsize  = cpu_enable ? int_d_awsize  : cpu_d_awsize;
    assign sel_d_awburst = cpu_enable ? int_d_awburst : cpu_d_awburst;
    assign sel_d_wvalid  = cpu_enable ? int_d_wvalid  : cpu_d_wvalid;
    assign sel_d_wdata   = cpu_enable ? int_d_wdata   : cpu_d_wdata;
    assign sel_d_wstrb   = cpu_enable ? int_d_wstrb   : cpu_d_wstrb;
    assign sel_d_wlast   = cpu_enable ? int_d_wlast   : cpu_d_wlast;
    assign sel_d_bready  = cpu_enable ? int_d_bready  : cpu_d_bready;
    assign sel_d_arvalid = cpu_enable ? int_d_arvalid : cpu_d_arvalid;
    assign sel_d_araddr  = cpu_enable ? int_d_araddr  : cpu_d_araddr;
    assign sel_d_arid    = cpu_enable ? int_d_arid    : cpu_d_arid;
    assign sel_d_arlen   = cpu_enable ? int_d_arlen   : cpu_d_arlen;
    assign sel_d_arsize  = cpu_enable ? int_d_arsize  : cpu_d_arsize;
    assign sel_d_arburst = cpu_enable ? int_d_arburst : cpu_d_arburst;
    assign sel_d_rready  = cpu_enable ? int_d_rready  : cpu_d_rready;

    // =========================================================================
    // I-MMU (Master 0): CPU I-port → MMU → Crossbar
    // =========================================================================
    // Translation interface wires (I-MMU)
    logic        immu_trans_req_valid;
    logic        immu_trans_req_ready;
    logic [31:0] immu_trans_vaddr;
    logic [1:0]  immu_trans_access_type;
    logic        immu_trans_priv_mode;
    logic        immu_trans_resp_valid;
    logic [31:0] immu_trans_paddr;
    logic        immu_trans_fault;
    logic [1:0]  immu_trans_fault_type;

    // PTW AXI wires (I-MMU)
    logic              immu_ptw_arvalid;
    logic              immu_ptw_arready;
    logic [ADDR_W-1:0] immu_ptw_araddr;
    logic [ID_W-1:0]   immu_ptw_arid;
    logic [7:0]        immu_ptw_arlen;
    logic [2:0]        immu_ptw_arsize;
    logic [1:0]        immu_ptw_arburst;
    logic              immu_ptw_rvalid;
    logic              immu_ptw_rready;
    logic [DATA_W-1:0] immu_ptw_rdata;
    logic [ID_W-1:0]   immu_ptw_rid;
    logic [1:0]        immu_ptw_rresp;
    logic              immu_ptw_rlast;

    // Unused PTW write channel wires (I-MMU)
    logic              immu_ptw_awvalid;
    logic              immu_ptw_awready;
    logic [ADDR_W-1:0] immu_ptw_awaddr;
    logic [ID_W-1:0]   immu_ptw_awid;
    logic [7:0]        immu_ptw_awlen;
    logic [2:0]        immu_ptw_awsize;
    logic [1:0]        immu_ptw_awburst;
    logic              immu_ptw_wvalid;
    logic              immu_ptw_wready;
    logic [DATA_W-1:0] immu_ptw_wdata;
    logic [STRB_W-1:0] immu_ptw_wstrb;
    logic              immu_ptw_wlast;
    logic              immu_ptw_bvalid;
    logic              immu_ptw_bready;
    logic [ID_W-1:0]   immu_ptw_bid;
    logic [1:0]        immu_ptw_bresp;

    mmu_axi_bridge #(.AXI_ID_W(ID_W)) u_immu_bridge (
        .clk              (clk),
        .srst             (srst),
        .trans_req_valid  (immu_trans_req_valid),
        .trans_req_ready  (immu_trans_req_ready),
        .trans_vaddr      (immu_trans_vaddr),
        .trans_access_type(immu_trans_access_type),
        .trans_priv_mode  (immu_trans_priv_mode),
        .trans_resp_valid (immu_trans_resp_valid),
        .trans_paddr      (immu_trans_paddr),
        .trans_fault      (immu_trans_fault),
        .trans_fault_type (immu_trans_fault_type),
        .ptw_arvalid      (immu_ptw_arvalid),
        .ptw_arready      (immu_ptw_arready),
        .ptw_araddr       (immu_ptw_araddr),
        .ptw_arid         (immu_ptw_arid),
        .ptw_arlen        (immu_ptw_arlen),
        .ptw_arsize       (immu_ptw_arsize),
        .ptw_arburst      (immu_ptw_arburst),
        .ptw_rvalid       (immu_ptw_rvalid),
        .ptw_rready       (immu_ptw_rready),
        .ptw_rdata        (immu_ptw_rdata),
        .ptw_rid          (immu_ptw_rid),
        .ptw_rresp        (immu_ptw_rresp),
        .ptw_rlast        (immu_ptw_rlast),
        .ptw_awvalid      (immu_ptw_awvalid),
        .ptw_awready      (1'b0),
        .ptw_awaddr       (immu_ptw_awaddr),
        .ptw_awid         (immu_ptw_awid),
        .ptw_awlen        (immu_ptw_awlen),
        .ptw_awsize       (immu_ptw_awsize),
        .ptw_awburst      (immu_ptw_awburst),
        .ptw_wvalid       (immu_ptw_wvalid),
        .ptw_wready       (1'b0),
        .ptw_wdata        (immu_ptw_wdata),
        .ptw_wstrb        (immu_ptw_wstrb),
        .ptw_wlast        (immu_ptw_wlast),
        .ptw_bvalid       (1'b0),
        .ptw_bready       (immu_ptw_bready),
        .ptw_bid          ('0),
        .ptw_bresp        ('0),
        .satp             (satp),
        .sfence_valid     (1'b0),
        .sfence_vaddr     ('0),
        .sfence_asid      ('0),
        .mxr              (1'b0),
        .sum              (1'b0)
    );

    cpu_axi_adapter #(.IS_IPORT(1'b1)) u_immu_adapter (
        .clk              (clk),
        .srst             (srst),
        // CPU side (muxed: internal CPU or external ports)
        .cpu_awvalid      (sel_i_awvalid),
        .cpu_awready      (cpu_i_awready),
        .cpu_awaddr       (sel_i_awaddr),
        .cpu_awid         (sel_i_awid),
        .cpu_awlen        (sel_i_awlen),
        .cpu_awsize       (sel_i_awsize),
        .cpu_awburst      (sel_i_awburst),
        .cpu_wvalid       (sel_i_wvalid),
        .cpu_wready       (cpu_i_wready),
        .cpu_wdata        (sel_i_wdata),
        .cpu_wstrb        (sel_i_wstrb),
        .cpu_wlast        (sel_i_wlast),
        .cpu_bvalid       (cpu_i_bvalid),
        .cpu_bready       (sel_i_bready),
        .cpu_bid          (cpu_i_bid),
        .cpu_bresp        (cpu_i_bresp),
        .cpu_arvalid      (sel_i_arvalid),
        .cpu_arready      (cpu_i_arready),
        .cpu_araddr       (sel_i_araddr),
        .cpu_arid         (sel_i_arid),
        .cpu_arlen        (sel_i_arlen),
        .cpu_arsize       (sel_i_arsize),
        .cpu_arburst      (sel_i_arburst),
        .cpu_rvalid       (cpu_i_rvalid),
        .cpu_rready       (sel_i_rready),
        .cpu_rdata        (cpu_i_rdata),
        .cpu_rid          (cpu_i_rid),
        .cpu_rresp        (cpu_i_rresp),
        .cpu_rlast        (cpu_i_rlast),
        // Translation
        .trans_req_valid  (immu_trans_req_valid),
        .trans_req_ready  (immu_trans_req_ready),
        .trans_vaddr      (immu_trans_vaddr),
        .trans_access_type(immu_trans_access_type),
        .trans_priv_mode  (immu_trans_priv_mode),
        .trans_resp_valid (immu_trans_resp_valid),
        .trans_paddr      (immu_trans_paddr),
        .trans_fault      (immu_trans_fault),
        .trans_fault_type (immu_trans_fault_type),
        // PTW AXI
        .ptw_arvalid      (immu_ptw_arvalid),
        .ptw_arready      (immu_ptw_arready),
        .ptw_araddr       (immu_ptw_araddr),
        .ptw_arid         (immu_ptw_arid),
        .ptw_arlen        (immu_ptw_arlen),
        .ptw_arsize       (immu_ptw_arsize),
        .ptw_arburst      (immu_ptw_arburst),
        .ptw_rvalid       (immu_ptw_rvalid),
        .ptw_rready       (immu_ptw_rready),
        .ptw_rdata        (immu_ptw_rdata),
        .ptw_rid          (immu_ptw_rid),
        .ptw_rresp        (immu_ptw_rresp),
        .ptw_rlast        (immu_ptw_rlast),
        // Crossbar M0
        .xbar_awvalid     (m_awvalid[0]),
        .xbar_awready     (m_awready[0]),
        .xbar_awaddr      (m_awaddr[0*ADDR_W +: ADDR_W]),
        .xbar_awid        (m_awid[0*ID_W +: ID_W]),
        .xbar_awlen       (m_awlen[0*8 +: 8]),
        .xbar_awsize      (m_awsize[0*3 +: 3]),
        .xbar_awburst     (m_awburst[0*2 +: 2]),
        .xbar_wvalid      (m_wvalid[0]),
        .xbar_wready      (m_wready[0]),
        .xbar_wdata       (m_wdata[0*DATA_W +: DATA_W]),
        .xbar_wstrb       (m_wstrb[0*STRB_W +: STRB_W]),
        .xbar_wlast       (m_wlast[0]),
        .xbar_bvalid      (m_bvalid[0]),
        .xbar_bready      (m_bready[0]),
        .xbar_bid         (m_bid[0*ID_W +: ID_W]),
        .xbar_bresp       (m_bresp[0*2 +: 2]),
        .xbar_arvalid     (m_arvalid[0]),
        .xbar_arready     (m_arready[0]),
        .xbar_araddr      (m_araddr[0*ADDR_W +: ADDR_W]),
        .xbar_arid        (m_arid[0*ID_W +: ID_W]),
        .xbar_arlen       (m_arlen[0*8 +: 8]),
        .xbar_arsize      (m_arsize[0*3 +: 3]),
        .xbar_arburst     (m_arburst[0*2 +: 2]),
        .xbar_rvalid      (m_rvalid[0]),
        .xbar_rready      (m_rready[0]),
        .xbar_rdata       (m_rdata[0*DATA_W +: DATA_W]),
        .xbar_rid         (m_rid[0*ID_W +: ID_W]),
        .xbar_rresp       (m_rresp[0*2 +: 2]),
        .xbar_rlast       (m_rlast[0])
    );

    // =========================================================================
    // D-MMU (Master 1): CPU D-port → MMU → Crossbar
    // =========================================================================
    // Translation interface wires (D-MMU)
    logic        dmmu_trans_req_valid;
    logic        dmmu_trans_req_ready;
    logic [31:0] dmmu_trans_vaddr;
    logic [1:0]  dmmu_trans_access_type;
    logic        dmmu_trans_priv_mode;
    logic        dmmu_trans_resp_valid;
    logic [31:0] dmmu_trans_paddr;
    logic        dmmu_trans_fault;
    logic [1:0]  dmmu_trans_fault_type;

    // PTW AXI wires (D-MMU)
    logic              dmmu_ptw_arvalid;
    logic              dmmu_ptw_arready;
    logic [ADDR_W-1:0] dmmu_ptw_araddr;
    logic [ID_W-1:0]   dmmu_ptw_arid;
    logic [7:0]        dmmu_ptw_arlen;
    logic [2:0]        dmmu_ptw_arsize;
    logic [1:0]        dmmu_ptw_arburst;
    logic              dmmu_ptw_rvalid;
    logic              dmmu_ptw_rready;
    logic [DATA_W-1:0] dmmu_ptw_rdata;
    logic [ID_W-1:0]   dmmu_ptw_rid;
    logic [1:0]        dmmu_ptw_rresp;
    logic              dmmu_ptw_rlast;

    // Unused PTW write channel wires (D-MMU)
    logic              dmmu_ptw_awvalid;
    logic              dmmu_ptw_awready;
    logic [ADDR_W-1:0] dmmu_ptw_awaddr;
    logic [ID_W-1:0]   dmmu_ptw_awid;
    logic [7:0]        dmmu_ptw_awlen;
    logic [2:0]        dmmu_ptw_awsize;
    logic [1:0]        dmmu_ptw_awburst;
    logic              dmmu_ptw_wvalid;
    logic              dmmu_ptw_wready;
    logic [DATA_W-1:0] dmmu_ptw_wdata;
    logic [STRB_W-1:0] dmmu_ptw_wstrb;
    logic              dmmu_ptw_wlast;
    logic              dmmu_ptw_bvalid;
    logic              dmmu_ptw_bready;
    logic [ID_W-1:0]   dmmu_ptw_bid;
    logic [1:0]        dmmu_ptw_bresp;

    mmu_axi_bridge #(.AXI_ID_W(ID_W)) u_dmmu_bridge (
        .clk              (clk),
        .srst             (srst),
        .trans_req_valid  (dmmu_trans_req_valid),
        .trans_req_ready  (dmmu_trans_req_ready),
        .trans_vaddr      (dmmu_trans_vaddr),
        .trans_access_type(dmmu_trans_access_type),
        .trans_priv_mode  (dmmu_trans_priv_mode),
        .trans_resp_valid (dmmu_trans_resp_valid),
        .trans_paddr      (dmmu_trans_paddr),
        .trans_fault      (dmmu_trans_fault),
        .trans_fault_type (dmmu_trans_fault_type),
        .ptw_arvalid      (dmmu_ptw_arvalid),
        .ptw_arready      (dmmu_ptw_arready),
        .ptw_araddr       (dmmu_ptw_araddr),
        .ptw_arid         (dmmu_ptw_arid),
        .ptw_arlen        (dmmu_ptw_arlen),
        .ptw_arsize       (dmmu_ptw_arsize),
        .ptw_arburst      (dmmu_ptw_arburst),
        .ptw_rvalid       (dmmu_ptw_rvalid),
        .ptw_rready       (dmmu_ptw_rready),
        .ptw_rdata        (dmmu_ptw_rdata),
        .ptw_rid          (dmmu_ptw_rid),
        .ptw_rresp        (dmmu_ptw_rresp),
        .ptw_rlast        (dmmu_ptw_rlast),
        .ptw_awvalid      (dmmu_ptw_awvalid),
        .ptw_awready      (1'b0),
        .ptw_awaddr       (dmmu_ptw_awaddr),
        .ptw_awid         (dmmu_ptw_awid),
        .ptw_awlen        (dmmu_ptw_awlen),
        .ptw_awsize       (dmmu_ptw_awsize),
        .ptw_awburst      (dmmu_ptw_awburst),
        .ptw_wvalid       (dmmu_ptw_wvalid),
        .ptw_wready       (1'b0),
        .ptw_wdata        (dmmu_ptw_wdata),
        .ptw_wstrb        (dmmu_ptw_wstrb),
        .ptw_wlast        (dmmu_ptw_wlast),
        .ptw_bvalid       (1'b0),
        .ptw_bready       (dmmu_ptw_bready),
        .ptw_bid          ('0),
        .ptw_bresp        ('0),
        .satp             (satp),
        .sfence_valid     (1'b0),
        .sfence_vaddr     ('0),
        .sfence_asid      ('0),
        .mxr              (1'b0),
        .sum              (1'b0)
    );

    cpu_axi_adapter #(.IS_IPORT(1'b0)) u_dmmu_adapter (
        .clk              (clk),
        .srst             (srst),
        // CPU side (muxed: internal CPU or external ports)
        .cpu_awvalid      (sel_d_awvalid),
        .cpu_awready      (cpu_d_awready),
        .cpu_awaddr       (sel_d_awaddr),
        .cpu_awid         (sel_d_awid),
        .cpu_awlen        (sel_d_awlen),
        .cpu_awsize       (sel_d_awsize),
        .cpu_awburst      (sel_d_awburst),
        .cpu_wvalid       (sel_d_wvalid),
        .cpu_wready       (cpu_d_wready),
        .cpu_wdata        (sel_d_wdata),
        .cpu_wstrb        (sel_d_wstrb),
        .cpu_wlast        (sel_d_wlast),
        .cpu_bvalid       (cpu_d_bvalid),
        .cpu_bready       (sel_d_bready),
        .cpu_bid          (cpu_d_bid),
        .cpu_bresp        (cpu_d_bresp),
        .cpu_arvalid      (sel_d_arvalid),
        .cpu_arready      (cpu_d_arready),
        .cpu_araddr       (sel_d_araddr),
        .cpu_arid         (sel_d_arid),
        .cpu_arlen        (sel_d_arlen),
        .cpu_arsize       (sel_d_arsize),
        .cpu_arburst      (sel_d_arburst),
        .cpu_rvalid       (cpu_d_rvalid),
        .cpu_rready       (sel_d_rready),
        .cpu_rdata        (cpu_d_rdata),
        .cpu_rid          (cpu_d_rid),
        .cpu_rresp        (cpu_d_rresp),
        .cpu_rlast        (cpu_d_rlast),
        // Translation
        .trans_req_valid  (dmmu_trans_req_valid),
        .trans_req_ready  (dmmu_trans_req_ready),
        .trans_vaddr      (dmmu_trans_vaddr),
        .trans_access_type(dmmu_trans_access_type),
        .trans_priv_mode  (dmmu_trans_priv_mode),
        .trans_resp_valid (dmmu_trans_resp_valid),
        .trans_paddr      (dmmu_trans_paddr),
        .trans_fault      (dmmu_trans_fault),
        .trans_fault_type (dmmu_trans_fault_type),
        // PTW AXI
        .ptw_arvalid      (dmmu_ptw_arvalid),
        .ptw_arready      (dmmu_ptw_arready),
        .ptw_araddr       (dmmu_ptw_araddr),
        .ptw_arid         (dmmu_ptw_arid),
        .ptw_arlen        (dmmu_ptw_arlen),
        .ptw_arsize       (dmmu_ptw_arsize),
        .ptw_arburst      (dmmu_ptw_arburst),
        .ptw_rvalid       (dmmu_ptw_rvalid),
        .ptw_rready       (dmmu_ptw_rready),
        .ptw_rdata        (dmmu_ptw_rdata),
        .ptw_rid          (dmmu_ptw_rid),
        .ptw_rresp        (dmmu_ptw_rresp),
        .ptw_rlast        (dmmu_ptw_rlast),
        // Crossbar M1
        .xbar_awvalid     (m_awvalid[1]),
        .xbar_awready     (m_awready[1]),
        .xbar_awaddr      (m_awaddr[1*ADDR_W +: ADDR_W]),
        .xbar_awid        (m_awid[1*ID_W +: ID_W]),
        .xbar_awlen       (m_awlen[1*8 +: 8]),
        .xbar_awsize      (m_awsize[1*3 +: 3]),
        .xbar_awburst     (m_awburst[1*2 +: 2]),
        .xbar_wvalid      (m_wvalid[1]),
        .xbar_wready      (m_wready[1]),
        .xbar_wdata       (m_wdata[1*DATA_W +: DATA_W]),
        .xbar_wstrb       (m_wstrb[1*STRB_W +: STRB_W]),
        .xbar_wlast       (m_wlast[1]),
        .xbar_bvalid      (m_bvalid[1]),
        .xbar_bready      (m_bready[1]),
        .xbar_bid         (m_bid[1*ID_W +: ID_W]),
        .xbar_bresp       (m_bresp[1*2 +: 2]),
        .xbar_arvalid     (m_arvalid[1]),
        .xbar_arready     (m_arready[1]),
        .xbar_araddr      (m_araddr[1*ADDR_W +: ADDR_W]),
        .xbar_arid        (m_arid[1*ID_W +: ID_W]),
        .xbar_arlen       (m_arlen[1*8 +: 8]),
        .xbar_arsize      (m_arsize[1*3 +: 3]),
        .xbar_arburst     (m_arburst[1*2 +: 2]),
        .xbar_rvalid      (m_rvalid[1]),
        .xbar_rready      (m_rready[1]),
        .xbar_rdata       (m_rdata[1*DATA_W +: DATA_W]),
        .xbar_rid         (m_rid[1*ID_W +: ID_W]),
        .xbar_rresp       (m_rresp[1*2 +: 2]),
        .xbar_rlast       (m_rlast[1])
    );

    // =========================================================================
    // DMA + IOMMU Bridge (Master 2, Slaves 3 & 4)
    // =========================================================================
    logic bridge_dma_irq;
    logic bridge_iommu_fault_irq;

    dma_iommu_bridge u_dma_iommu_bridge (
        .clk             (clk),
        .srst            (srst),
        // AXI master → crossbar M2
        .m2_awvalid      (m_awvalid[2]),
        .m2_awready      (m_awready[2]),
        .m2_awaddr       (m_awaddr[2*ADDR_W +: ADDR_W]),
        .m2_awid         (m_awid[2*ID_W +: ID_W]),
        .m2_awlen        (m_awlen[2*8 +: 8]),
        .m2_awsize       (m_awsize[2*3 +: 3]),
        .m2_awburst      (m_awburst[2*2 +: 2]),
        .m2_wvalid       (m_wvalid[2]),
        .m2_wready       (m_wready[2]),
        .m2_wdata        (m_wdata[2*DATA_W +: DATA_W]),
        .m2_wstrb        (m_wstrb[2*STRB_W +: STRB_W]),
        .m2_wlast        (m_wlast[2]),
        .m2_bvalid       (m_bvalid[2]),
        .m2_bready       (m_bready[2]),
        .m2_bid          (m_bid[2*ID_W +: ID_W]),
        .m2_bresp        (m_bresp[2*2 +: 2]),
        .m2_arvalid      (m_arvalid[2]),
        .m2_arready      (m_arready[2]),
        .m2_araddr       (m_araddr[2*ADDR_W +: ADDR_W]),
        .m2_arid         (m_arid[2*ID_W +: ID_W]),
        .m2_arlen        (m_arlen[2*8 +: 8]),
        .m2_arsize       (m_arsize[2*3 +: 3]),
        .m2_arburst      (m_arburst[2*2 +: 2]),
        .m2_rvalid       (m_rvalid[2]),
        .m2_rready       (m_rready[2]),
        .m2_rdata        (m_rdata[2*DATA_W +: DATA_W]),
        .m2_rid          (m_rid[2*ID_W +: ID_W]),
        .m2_rresp        (m_rresp[2*2 +: 2]),
        .m2_rlast        (m_rlast[2]),
        // AXI slave ← crossbar S3 (DMA regs)
        .s3_awvalid      (s_awvalid[3]),
        .s3_awready      (s_awready[3]),
        .s3_awaddr       (s_awaddr[3*ADDR_W +: ADDR_W]),
        .s3_awid         (s_awid[3*SID_W +: SID_W]),
        .s3_awlen        (s_awlen[3*8 +: 8]),
        .s3_awsize       (s_awsize[3*3 +: 3]),
        .s3_awburst      (s_awburst[3*2 +: 2]),
        .s3_wvalid       (s_wvalid[3]),
        .s3_wready       (s_wready[3]),
        .s3_wdata        (s_wdata[3*DATA_W +: DATA_W]),
        .s3_wstrb        (s_wstrb[3*STRB_W +: STRB_W]),
        .s3_wlast        (s_wlast[3]),
        .s3_bvalid       (s_bvalid[3]),
        .s3_bready       (s_bready[3]),
        .s3_bid          (s_bid[3*SID_W +: SID_W]),
        .s3_bresp        (s_bresp[3*2 +: 2]),
        .s3_arvalid      (s_arvalid[3]),
        .s3_arready      (s_arready[3]),
        .s3_araddr       (s_araddr[3*ADDR_W +: ADDR_W]),
        .s3_arid         (s_arid[3*SID_W +: SID_W]),
        .s3_arlen        (s_arlen[3*8 +: 8]),
        .s3_arsize       (s_arsize[3*3 +: 3]),
        .s3_arburst      (s_arburst[3*2 +: 2]),
        .s3_rvalid       (s_rvalid[3]),
        .s3_rready       (s_rready[3]),
        .s3_rdata        (s_rdata[3*DATA_W +: DATA_W]),
        .s3_rid          (s_rid[3*SID_W +: SID_W]),
        .s3_rresp        (s_rresp[3*2 +: 2]),
        .s3_rlast        (s_rlast[3]),
        // AXI slave ← crossbar S4 (IOMMU regs)
        .s4_awvalid      (s_awvalid[4]),
        .s4_awready      (s_awready[4]),
        .s4_awaddr       (s_awaddr[4*ADDR_W +: ADDR_W]),
        .s4_awid         (s_awid[4*SID_W +: SID_W]),
        .s4_awlen        (s_awlen[4*8 +: 8]),
        .s4_awsize       (s_awsize[4*3 +: 3]),
        .s4_awburst      (s_awburst[4*2 +: 2]),
        .s4_wvalid       (s_wvalid[4]),
        .s4_wready       (s_wready[4]),
        .s4_wdata        (s_wdata[4*DATA_W +: DATA_W]),
        .s4_wstrb        (s_wstrb[4*STRB_W +: STRB_W]),
        .s4_wlast        (s_wlast[4]),
        .s4_bvalid       (s_bvalid[4]),
        .s4_bready       (s_bready[4]),
        .s4_bid          (s_bid[4*SID_W +: SID_W]),
        .s4_bresp        (s_bresp[4*2 +: 2]),
        .s4_arvalid      (s_arvalid[4]),
        .s4_arready      (s_arready[4]),
        .s4_araddr       (s_araddr[4*ADDR_W +: ADDR_W]),
        .s4_arid         (s_arid[4*SID_W +: SID_W]),
        .s4_arlen        (s_arlen[4*8 +: 8]),
        .s4_arsize       (s_arsize[4*3 +: 3]),
        .s4_arburst      (s_arburst[4*2 +: 2]),
        .s4_rvalid       (s_rvalid[4]),
        .s4_rready       (s_rready[4]),
        .s4_rdata        (s_rdata[4*DATA_W +: DATA_W]),
        .s4_rid          (s_rid[4*SID_W +: SID_W]),
        .s4_rresp        (s_rresp[4*2 +: 2]),
        .s4_rlast        (s_rlast[4]),
        // DMA peripheral handshake (no external DMA requests)
        .dreq            (4'b0),
        .dack            (),
        // Interrupts
        .dma_irq         (bridge_dma_irq),
        .iommu_fault_irq (bridge_iommu_fault_irq)
    );

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
    assign dma_irq     = {3'b0, bridge_dma_irq};
    assign gpio_out    = '0;
    assign gpio_oe     = '0;
    assign uart_tx     = 1'b1;  // idle high
    assign periph_rdata = '0;

    // Slaves 3 and 4 are now connected to dma_iommu_bridge above.

endmodule
