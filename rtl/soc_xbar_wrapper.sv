// Brendan Lynskey 2025
// SoC AXI4 Crossbar Wrapper
// MIT License
//
// Wraps axi_xbar_top (N_MASTERS=3, N_SLAVES=5) and exposes clean
// per-master and per-slave AXI4 signal bundles instead of packed arrays.

module soc_xbar_wrapper
    import soc_pkg::*;
(
    input  logic clk,
    input  logic srst,

    // =====================================================================
    // Master 0 — CPU I-port (post-MMU)
    // =====================================================================
    input  logic              m0_awvalid,
    output logic              m0_awready,
    input  logic [ADDR_W-1:0] m0_awaddr,
    input  logic [ID_W-1:0]   m0_awid,
    input  logic [7:0]        m0_awlen,
    input  logic [2:0]        m0_awsize,
    input  logic [1:0]        m0_awburst,
    input  logic              m0_wvalid,
    output logic              m0_wready,
    input  logic [DATA_W-1:0] m0_wdata,
    input  logic [STRB_W-1:0] m0_wstrb,
    input  logic              m0_wlast,
    output logic              m0_bvalid,
    input  logic              m0_bready,
    output logic [ID_W-1:0]   m0_bid,
    output logic [1:0]        m0_bresp,
    input  logic              m0_arvalid,
    output logic              m0_arready,
    input  logic [ADDR_W-1:0] m0_araddr,
    input  logic [ID_W-1:0]   m0_arid,
    input  logic [7:0]        m0_arlen,
    input  logic [2:0]        m0_arsize,
    input  logic [1:0]        m0_arburst,
    output logic              m0_rvalid,
    input  logic              m0_rready,
    output logic [DATA_W-1:0] m0_rdata,
    output logic [ID_W-1:0]   m0_rid,
    output logic [1:0]        m0_rresp,
    output logic              m0_rlast,

    // =====================================================================
    // Master 1 — CPU D-port (post-MMU)
    // =====================================================================
    input  logic              m1_awvalid,
    output logic              m1_awready,
    input  logic [ADDR_W-1:0] m1_awaddr,
    input  logic [ID_W-1:0]   m1_awid,
    input  logic [7:0]        m1_awlen,
    input  logic [2:0]        m1_awsize,
    input  logic [1:0]        m1_awburst,
    input  logic              m1_wvalid,
    output logic              m1_wready,
    input  logic [DATA_W-1:0] m1_wdata,
    input  logic [STRB_W-1:0] m1_wstrb,
    input  logic              m1_wlast,
    output logic              m1_bvalid,
    input  logic              m1_bready,
    output logic [ID_W-1:0]   m1_bid,
    output logic [1:0]        m1_bresp,
    input  logic              m1_arvalid,
    output logic              m1_arready,
    input  logic [ADDR_W-1:0] m1_araddr,
    input  logic [ID_W-1:0]   m1_arid,
    input  logic [7:0]        m1_arlen,
    input  logic [2:0]        m1_arsize,
    input  logic [1:0]        m1_arburst,
    output logic              m1_rvalid,
    input  logic              m1_rready,
    output logic [DATA_W-1:0] m1_rdata,
    output logic [ID_W-1:0]   m1_rid,
    output logic [1:0]        m1_rresp,
    output logic              m1_rlast,

    // =====================================================================
    // Master 2 — DMA (post-IOMMU)
    // =====================================================================
    input  logic              m2_awvalid,
    output logic              m2_awready,
    input  logic [ADDR_W-1:0] m2_awaddr,
    input  logic [ID_W-1:0]   m2_awid,
    input  logic [7:0]        m2_awlen,
    input  logic [2:0]        m2_awsize,
    input  logic [1:0]        m2_awburst,
    input  logic              m2_wvalid,
    output logic              m2_wready,
    input  logic [DATA_W-1:0] m2_wdata,
    input  logic [STRB_W-1:0] m2_wstrb,
    input  logic              m2_wlast,
    output logic              m2_bvalid,
    input  logic              m2_bready,
    output logic [ID_W-1:0]   m2_bid,
    output logic [1:0]        m2_bresp,
    input  logic              m2_arvalid,
    output logic              m2_arready,
    input  logic [ADDR_W-1:0] m2_araddr,
    input  logic [ID_W-1:0]   m2_arid,
    input  logic [7:0]        m2_arlen,
    input  logic [2:0]        m2_arsize,
    input  logic [1:0]        m2_arburst,
    output logic              m2_rvalid,
    input  logic              m2_rready,
    output logic [DATA_W-1:0] m2_rdata,
    output logic [ID_W-1:0]   m2_rid,
    output logic [1:0]        m2_rresp,
    output logic              m2_rlast,

    // =====================================================================
    // Slave 0 — Instruction SRAM
    // =====================================================================
    output logic              s0_awvalid,
    input  logic              s0_awready,
    output logic [ADDR_W-1:0] s0_awaddr,
    output logic [SID_W-1:0]  s0_awid,
    output logic [7:0]        s0_awlen,
    output logic [2:0]        s0_awsize,
    output logic [1:0]        s0_awburst,
    output logic              s0_wvalid,
    input  logic              s0_wready,
    output logic [DATA_W-1:0] s0_wdata,
    output logic [STRB_W-1:0] s0_wstrb,
    output logic              s0_wlast,
    input  logic              s0_bvalid,
    output logic              s0_bready,
    input  logic [SID_W-1:0]  s0_bid,
    input  logic [1:0]        s0_bresp,
    output logic              s0_arvalid,
    input  logic              s0_arready,
    output logic [ADDR_W-1:0] s0_araddr,
    output logic [SID_W-1:0]  s0_arid,
    output logic [7:0]        s0_arlen,
    output logic [2:0]        s0_arsize,
    output logic [1:0]        s0_arburst,
    input  logic              s0_rvalid,
    output logic              s0_rready,
    input  logic [DATA_W-1:0] s0_rdata,
    input  logic [SID_W-1:0]  s0_rid,
    input  logic [1:0]        s0_rresp,
    input  logic              s0_rlast,

    // =====================================================================
    // Slave 1 — Data SRAM
    // =====================================================================
    output logic              s1_awvalid,
    input  logic              s1_awready,
    output logic [ADDR_W-1:0] s1_awaddr,
    output logic [SID_W-1:0]  s1_awid,
    output logic [7:0]        s1_awlen,
    output logic [2:0]        s1_awsize,
    output logic [1:0]        s1_awburst,
    output logic              s1_wvalid,
    input  logic              s1_wready,
    output logic [DATA_W-1:0] s1_wdata,
    output logic [STRB_W-1:0] s1_wstrb,
    output logic              s1_wlast,
    input  logic              s1_bvalid,
    output logic              s1_bready,
    input  logic [SID_W-1:0]  s1_bid,
    input  logic [1:0]        s1_bresp,
    output logic              s1_arvalid,
    input  logic              s1_arready,
    output logic [ADDR_W-1:0] s1_araddr,
    output logic [SID_W-1:0]  s1_arid,
    output logic [7:0]        s1_arlen,
    output logic [2:0]        s1_arsize,
    output logic [1:0]        s1_arburst,
    input  logic              s1_rvalid,
    output logic              s1_rready,
    input  logic [DATA_W-1:0] s1_rdata,
    input  logic [SID_W-1:0]  s1_rid,
    input  logic [1:0]        s1_rresp,
    input  logic              s1_rlast,

    // =====================================================================
    // Slave 2 — Peripheral bridge
    // =====================================================================
    output logic              s2_awvalid,
    input  logic              s2_awready,
    output logic [ADDR_W-1:0] s2_awaddr,
    output logic [SID_W-1:0]  s2_awid,
    output logic [7:0]        s2_awlen,
    output logic [2:0]        s2_awsize,
    output logic [1:0]        s2_awburst,
    output logic              s2_wvalid,
    input  logic              s2_wready,
    output logic [DATA_W-1:0] s2_wdata,
    output logic [STRB_W-1:0] s2_wstrb,
    output logic              s2_wlast,
    input  logic              s2_bvalid,
    output logic              s2_bready,
    input  logic [SID_W-1:0]  s2_bid,
    input  logic [1:0]        s2_bresp,
    output logic              s2_arvalid,
    input  logic              s2_arready,
    output logic [ADDR_W-1:0] s2_araddr,
    output logic [SID_W-1:0]  s2_arid,
    output logic [7:0]        s2_arlen,
    output logic [2:0]        s2_arsize,
    output logic [1:0]        s2_arburst,
    input  logic              s2_rvalid,
    output logic              s2_rready,
    input  logic [DATA_W-1:0] s2_rdata,
    input  logic [SID_W-1:0]  s2_rid,
    input  logic [1:0]        s2_rresp,
    input  logic              s2_rlast,

    // =====================================================================
    // Slave 3 — DMA registers
    // =====================================================================
    output logic              s3_awvalid,
    input  logic              s3_awready,
    output logic [ADDR_W-1:0] s3_awaddr,
    output logic [SID_W-1:0]  s3_awid,
    output logic [7:0]        s3_awlen,
    output logic [2:0]        s3_awsize,
    output logic [1:0]        s3_awburst,
    output logic              s3_wvalid,
    input  logic              s3_wready,
    output logic [DATA_W-1:0] s3_wdata,
    output logic [STRB_W-1:0] s3_wstrb,
    output logic              s3_wlast,
    input  logic              s3_bvalid,
    output logic              s3_bready,
    input  logic [SID_W-1:0]  s3_bid,
    input  logic [1:0]        s3_bresp,
    output logic              s3_arvalid,
    input  logic              s3_arready,
    output logic [ADDR_W-1:0] s3_araddr,
    output logic [SID_W-1:0]  s3_arid,
    output logic [7:0]        s3_arlen,
    output logic [2:0]        s3_arsize,
    output logic [1:0]        s3_arburst,
    input  logic              s3_rvalid,
    output logic              s3_rready,
    input  logic [DATA_W-1:0] s3_rdata,
    input  logic [SID_W-1:0]  s3_rid,
    input  logic [1:0]        s3_rresp,
    input  logic              s3_rlast,

    // =====================================================================
    // Slave 4 — IOMMU registers
    // =====================================================================
    output logic              s4_awvalid,
    input  logic              s4_awready,
    output logic [ADDR_W-1:0] s4_awaddr,
    output logic [SID_W-1:0]  s4_awid,
    output logic [7:0]        s4_awlen,
    output logic [2:0]        s4_awsize,
    output logic [1:0]        s4_awburst,
    output logic              s4_wvalid,
    input  logic              s4_wready,
    output logic [DATA_W-1:0] s4_wdata,
    output logic [STRB_W-1:0] s4_wstrb,
    output logic              s4_wlast,
    input  logic              s4_bvalid,
    output logic              s4_bready,
    input  logic [SID_W-1:0]  s4_bid,
    input  logic [1:0]        s4_bresp,
    output logic              s4_arvalid,
    input  logic              s4_arready,
    output logic [ADDR_W-1:0] s4_araddr,
    output logic [SID_W-1:0]  s4_arid,
    output logic [7:0]        s4_arlen,
    output logic [2:0]        s4_arsize,
    output logic [1:0]        s4_arburst,
    input  logic              s4_rvalid,
    output logic              s4_rready,
    input  logic [DATA_W-1:0] s4_rdata,
    input  logic [SID_W-1:0]  s4_rid,
    input  logic [1:0]        s4_rresp,
    input  logic              s4_rlast
);

    // Flat packed arrays for axi_xbar_top
    logic [N_MASTERS-1:0]            xm_awvalid;
    logic [N_MASTERS-1:0]            xm_awready;
    logic [N_MASTERS*ADDR_W-1:0]     xm_awaddr;
    logic [N_MASTERS*ID_W-1:0]       xm_awid;
    logic [N_MASTERS*8-1:0]          xm_awlen;
    logic [N_MASTERS*3-1:0]          xm_awsize;
    logic [N_MASTERS*2-1:0]          xm_awburst;
    logic [N_MASTERS-1:0]            xm_wvalid;
    logic [N_MASTERS-1:0]            xm_wready;
    logic [N_MASTERS*DATA_W-1:0]     xm_wdata;
    logic [N_MASTERS*STRB_W-1:0]     xm_wstrb;
    logic [N_MASTERS-1:0]            xm_wlast;
    logic [N_MASTERS-1:0]            xm_bvalid;
    logic [N_MASTERS-1:0]            xm_bready;
    logic [N_MASTERS*ID_W-1:0]       xm_bid;
    logic [N_MASTERS*2-1:0]          xm_bresp;
    logic [N_MASTERS-1:0]            xm_arvalid;
    logic [N_MASTERS-1:0]            xm_arready;
    logic [N_MASTERS*ADDR_W-1:0]     xm_araddr;
    logic [N_MASTERS*ID_W-1:0]       xm_arid;
    logic [N_MASTERS*8-1:0]          xm_arlen;
    logic [N_MASTERS*3-1:0]          xm_arsize;
    logic [N_MASTERS*2-1:0]          xm_arburst;
    logic [N_MASTERS-1:0]            xm_rvalid;
    logic [N_MASTERS-1:0]            xm_rready;
    logic [N_MASTERS*DATA_W-1:0]     xm_rdata;
    logic [N_MASTERS*ID_W-1:0]       xm_rid;
    logic [N_MASTERS*2-1:0]          xm_rresp;
    logic [N_MASTERS-1:0]            xm_rlast;

    logic [N_SLAVES-1:0]             xs_awvalid;
    logic [N_SLAVES-1:0]             xs_awready;
    logic [N_SLAVES*ADDR_W-1:0]      xs_awaddr;
    logic [N_SLAVES*SID_W-1:0]       xs_awid;
    logic [N_SLAVES*8-1:0]           xs_awlen;
    logic [N_SLAVES*3-1:0]           xs_awsize;
    logic [N_SLAVES*2-1:0]           xs_awburst;
    logic [N_SLAVES-1:0]             xs_wvalid;
    logic [N_SLAVES-1:0]             xs_wready;
    logic [N_SLAVES*DATA_W-1:0]      xs_wdata;
    logic [N_SLAVES*STRB_W-1:0]      xs_wstrb;
    logic [N_SLAVES-1:0]             xs_wlast;
    logic [N_SLAVES-1:0]             xs_bvalid;
    logic [N_SLAVES-1:0]             xs_bready;
    logic [N_SLAVES*SID_W-1:0]       xs_bid;
    logic [N_SLAVES*2-1:0]           xs_bresp;
    logic [N_SLAVES-1:0]             xs_arvalid;
    logic [N_SLAVES-1:0]             xs_arready;
    logic [N_SLAVES*ADDR_W-1:0]      xs_araddr;
    logic [N_SLAVES*SID_W-1:0]       xs_arid;
    logic [N_SLAVES*8-1:0]           xs_arlen;
    logic [N_SLAVES*3-1:0]           xs_arsize;
    logic [N_SLAVES*2-1:0]           xs_arburst;
    logic [N_SLAVES-1:0]             xs_rvalid;
    logic [N_SLAVES-1:0]             xs_rready;
    logic [N_SLAVES*DATA_W-1:0]      xs_rdata;
    logic [N_SLAVES*SID_W-1:0]       xs_rid;
    logic [N_SLAVES*2-1:0]           xs_rresp;
    logic [N_SLAVES-1:0]             xs_rlast;

    // =====================================================================
    // Master 0 mapping
    // =====================================================================
    assign xm_awvalid[0]                = m0_awvalid;
    assign m0_awready                   = xm_awready[0];
    assign xm_awaddr[0*ADDR_W +: ADDR_W] = m0_awaddr;
    assign xm_awid[0*ID_W +: ID_W]     = m0_awid;
    assign xm_awlen[0*8 +: 8]          = m0_awlen;
    assign xm_awsize[0*3 +: 3]         = m0_awsize;
    assign xm_awburst[0*2 +: 2]        = m0_awburst;
    assign xm_wvalid[0]                = m0_wvalid;
    assign m0_wready                    = xm_wready[0];
    assign xm_wdata[0*DATA_W +: DATA_W] = m0_wdata;
    assign xm_wstrb[0*STRB_W +: STRB_W] = m0_wstrb;
    assign xm_wlast[0]                 = m0_wlast;
    assign m0_bvalid                    = xm_bvalid[0];
    assign xm_bready[0]                = m0_bready;
    assign m0_bid                       = xm_bid[0*ID_W +: ID_W];
    assign m0_bresp                     = xm_bresp[0*2 +: 2];
    assign xm_arvalid[0]               = m0_arvalid;
    assign m0_arready                   = xm_arready[0];
    assign xm_araddr[0*ADDR_W +: ADDR_W] = m0_araddr;
    assign xm_arid[0*ID_W +: ID_W]     = m0_arid;
    assign xm_arlen[0*8 +: 8]          = m0_arlen;
    assign xm_arsize[0*3 +: 3]         = m0_arsize;
    assign xm_arburst[0*2 +: 2]        = m0_arburst;
    assign m0_rvalid                    = xm_rvalid[0];
    assign xm_rready[0]                = m0_rready;
    assign m0_rdata                     = xm_rdata[0*DATA_W +: DATA_W];
    assign m0_rid                       = xm_rid[0*ID_W +: ID_W];
    assign m0_rresp                     = xm_rresp[0*2 +: 2];
    assign m0_rlast                     = xm_rlast[0];

    // =====================================================================
    // Master 1 mapping
    // =====================================================================
    assign xm_awvalid[1]                = m1_awvalid;
    assign m1_awready                   = xm_awready[1];
    assign xm_awaddr[1*ADDR_W +: ADDR_W] = m1_awaddr;
    assign xm_awid[1*ID_W +: ID_W]     = m1_awid;
    assign xm_awlen[1*8 +: 8]          = m1_awlen;
    assign xm_awsize[1*3 +: 3]         = m1_awsize;
    assign xm_awburst[1*2 +: 2]        = m1_awburst;
    assign xm_wvalid[1]                = m1_wvalid;
    assign m1_wready                    = xm_wready[1];
    assign xm_wdata[1*DATA_W +: DATA_W] = m1_wdata;
    assign xm_wstrb[1*STRB_W +: STRB_W] = m1_wstrb;
    assign xm_wlast[1]                 = m1_wlast;
    assign m1_bvalid                    = xm_bvalid[1];
    assign xm_bready[1]                = m1_bready;
    assign m1_bid                       = xm_bid[1*ID_W +: ID_W];
    assign m1_bresp                     = xm_bresp[1*2 +: 2];
    assign xm_arvalid[1]               = m1_arvalid;
    assign m1_arready                   = xm_arready[1];
    assign xm_araddr[1*ADDR_W +: ADDR_W] = m1_araddr;
    assign xm_arid[1*ID_W +: ID_W]     = m1_arid;
    assign xm_arlen[1*8 +: 8]          = m1_arlen;
    assign xm_arsize[1*3 +: 3]         = m1_arsize;
    assign xm_arburst[1*2 +: 2]        = m1_arburst;
    assign m1_rvalid                    = xm_rvalid[1];
    assign xm_rready[1]                = m1_rready;
    assign m1_rdata                     = xm_rdata[1*DATA_W +: DATA_W];
    assign m1_rid                       = xm_rid[1*ID_W +: ID_W];
    assign m1_rresp                     = xm_rresp[1*2 +: 2];
    assign m1_rlast                     = xm_rlast[1];

    // =====================================================================
    // Master 2 mapping
    // =====================================================================
    assign xm_awvalid[2]                = m2_awvalid;
    assign m2_awready                   = xm_awready[2];
    assign xm_awaddr[2*ADDR_W +: ADDR_W] = m2_awaddr;
    assign xm_awid[2*ID_W +: ID_W]     = m2_awid;
    assign xm_awlen[2*8 +: 8]          = m2_awlen;
    assign xm_awsize[2*3 +: 3]         = m2_awsize;
    assign xm_awburst[2*2 +: 2]        = m2_awburst;
    assign xm_wvalid[2]                = m2_wvalid;
    assign m2_wready                    = xm_wready[2];
    assign xm_wdata[2*DATA_W +: DATA_W] = m2_wdata;
    assign xm_wstrb[2*STRB_W +: STRB_W] = m2_wstrb;
    assign xm_wlast[2]                 = m2_wlast;
    assign m2_bvalid                    = xm_bvalid[2];
    assign xm_bready[2]                = m2_bready;
    assign m2_bid                       = xm_bid[2*ID_W +: ID_W];
    assign m2_bresp                     = xm_bresp[2*2 +: 2];
    assign xm_arvalid[2]               = m2_arvalid;
    assign m2_arready                   = xm_arready[2];
    assign xm_araddr[2*ADDR_W +: ADDR_W] = m2_araddr;
    assign xm_arid[2*ID_W +: ID_W]     = m2_arid;
    assign xm_arlen[2*8 +: 8]          = m2_arlen;
    assign xm_arsize[2*3 +: 3]         = m2_arsize;
    assign xm_arburst[2*2 +: 2]        = m2_arburst;
    assign m2_rvalid                    = xm_rvalid[2];
    assign xm_rready[2]                = m2_rready;
    assign m2_rdata                     = xm_rdata[2*DATA_W +: DATA_W];
    assign m2_rid                       = xm_rid[2*ID_W +: ID_W];
    assign m2_rresp                     = xm_rresp[2*2 +: 2];
    assign m2_rlast                     = xm_rlast[2];

    // =====================================================================
    // Slave 0 mapping
    // =====================================================================
    assign s0_awvalid                    = xs_awvalid[0];
    assign xs_awready[0]                 = s0_awready;
    assign s0_awaddr                     = xs_awaddr[0*ADDR_W +: ADDR_W];
    assign s0_awid                       = xs_awid[0*SID_W +: SID_W];
    assign s0_awlen                      = xs_awlen[0*8 +: 8];
    assign s0_awsize                     = xs_awsize[0*3 +: 3];
    assign s0_awburst                    = xs_awburst[0*2 +: 2];
    assign s0_wvalid                     = xs_wvalid[0];
    assign xs_wready[0]                  = s0_wready;
    assign s0_wdata                      = xs_wdata[0*DATA_W +: DATA_W];
    assign s0_wstrb                      = xs_wstrb[0*STRB_W +: STRB_W];
    assign s0_wlast                      = xs_wlast[0];
    assign xs_bvalid[0]                  = s0_bvalid;
    assign s0_bready                     = xs_bready[0];
    assign xs_bid[0*SID_W +: SID_W]      = s0_bid;
    assign xs_bresp[0*2 +: 2]            = s0_bresp;
    assign s0_arvalid                    = xs_arvalid[0];
    assign xs_arready[0]                 = s0_arready;
    assign s0_araddr                     = xs_araddr[0*ADDR_W +: ADDR_W];
    assign s0_arid                       = xs_arid[0*SID_W +: SID_W];
    assign s0_arlen                      = xs_arlen[0*8 +: 8];
    assign s0_arsize                     = xs_arsize[0*3 +: 3];
    assign s0_arburst                    = xs_arburst[0*2 +: 2];
    assign xs_rvalid[0]                  = s0_rvalid;
    assign s0_rready                     = xs_rready[0];
    assign xs_rdata[0*DATA_W +: DATA_W]  = s0_rdata;
    assign xs_rid[0*SID_W +: SID_W]      = s0_rid;
    assign xs_rresp[0*2 +: 2]            = s0_rresp;
    assign xs_rlast[0]                   = s0_rlast;

    // =====================================================================
    // Slave 1 mapping
    // =====================================================================
    assign s1_awvalid                    = xs_awvalid[1];
    assign xs_awready[1]                 = s1_awready;
    assign s1_awaddr                     = xs_awaddr[1*ADDR_W +: ADDR_W];
    assign s1_awid                       = xs_awid[1*SID_W +: SID_W];
    assign s1_awlen                      = xs_awlen[1*8 +: 8];
    assign s1_awsize                     = xs_awsize[1*3 +: 3];
    assign s1_awburst                    = xs_awburst[1*2 +: 2];
    assign s1_wvalid                     = xs_wvalid[1];
    assign xs_wready[1]                  = s1_wready;
    assign s1_wdata                      = xs_wdata[1*DATA_W +: DATA_W];
    assign s1_wstrb                      = xs_wstrb[1*STRB_W +: STRB_W];
    assign s1_wlast                      = xs_wlast[1];
    assign xs_bvalid[1]                  = s1_bvalid;
    assign s1_bready                     = xs_bready[1];
    assign xs_bid[1*SID_W +: SID_W]      = s1_bid;
    assign xs_bresp[1*2 +: 2]            = s1_bresp;
    assign s1_arvalid                    = xs_arvalid[1];
    assign xs_arready[1]                 = s1_arready;
    assign s1_araddr                     = xs_araddr[1*ADDR_W +: ADDR_W];
    assign s1_arid                       = xs_arid[1*SID_W +: SID_W];
    assign s1_arlen                      = xs_arlen[1*8 +: 8];
    assign s1_arsize                     = xs_arsize[1*3 +: 3];
    assign s1_arburst                    = xs_arburst[1*2 +: 2];
    assign xs_rvalid[1]                  = s1_rvalid;
    assign s1_rready                     = xs_rready[1];
    assign xs_rdata[1*DATA_W +: DATA_W]  = s1_rdata;
    assign xs_rid[1*SID_W +: SID_W]      = s1_rid;
    assign xs_rresp[1*2 +: 2]            = s1_rresp;
    assign xs_rlast[1]                   = s1_rlast;

    // =====================================================================
    // Slave 2 mapping
    // =====================================================================
    assign s2_awvalid                    = xs_awvalid[2];
    assign xs_awready[2]                 = s2_awready;
    assign s2_awaddr                     = xs_awaddr[2*ADDR_W +: ADDR_W];
    assign s2_awid                       = xs_awid[2*SID_W +: SID_W];
    assign s2_awlen                      = xs_awlen[2*8 +: 8];
    assign s2_awsize                     = xs_awsize[2*3 +: 3];
    assign s2_awburst                    = xs_awburst[2*2 +: 2];
    assign s2_wvalid                     = xs_wvalid[2];
    assign xs_wready[2]                  = s2_wready;
    assign s2_wdata                      = xs_wdata[2*DATA_W +: DATA_W];
    assign s2_wstrb                      = xs_wstrb[2*STRB_W +: STRB_W];
    assign s2_wlast                      = xs_wlast[2];
    assign xs_bvalid[2]                  = s2_bvalid;
    assign s2_bready                     = xs_bready[2];
    assign xs_bid[2*SID_W +: SID_W]      = s2_bid;
    assign xs_bresp[2*2 +: 2]            = s2_bresp;
    assign s2_arvalid                    = xs_arvalid[2];
    assign xs_arready[2]                 = s2_arready;
    assign s2_araddr                     = xs_araddr[2*ADDR_W +: ADDR_W];
    assign s2_arid                       = xs_arid[2*SID_W +: SID_W];
    assign s2_arlen                      = xs_arlen[2*8 +: 8];
    assign s2_arsize                     = xs_arsize[2*3 +: 3];
    assign s2_arburst                    = xs_arburst[2*2 +: 2];
    assign xs_rvalid[2]                  = s2_rvalid;
    assign s2_rready                     = xs_rready[2];
    assign xs_rdata[2*DATA_W +: DATA_W]  = s2_rdata;
    assign xs_rid[2*SID_W +: SID_W]      = s2_rid;
    assign xs_rresp[2*2 +: 2]            = s2_rresp;
    assign xs_rlast[2]                   = s2_rlast;

    // =====================================================================
    // Slave 3 mapping
    // =====================================================================
    assign s3_awvalid                    = xs_awvalid[3];
    assign xs_awready[3]                 = s3_awready;
    assign s3_awaddr                     = xs_awaddr[3*ADDR_W +: ADDR_W];
    assign s3_awid                       = xs_awid[3*SID_W +: SID_W];
    assign s3_awlen                      = xs_awlen[3*8 +: 8];
    assign s3_awsize                     = xs_awsize[3*3 +: 3];
    assign s3_awburst                    = xs_awburst[3*2 +: 2];
    assign s3_wvalid                     = xs_wvalid[3];
    assign xs_wready[3]                  = s3_wready;
    assign s3_wdata                      = xs_wdata[3*DATA_W +: DATA_W];
    assign s3_wstrb                      = xs_wstrb[3*STRB_W +: STRB_W];
    assign s3_wlast                      = xs_wlast[3];
    assign xs_bvalid[3]                  = s3_bvalid;
    assign s3_bready                     = xs_bready[3];
    assign xs_bid[3*SID_W +: SID_W]      = s3_bid;
    assign xs_bresp[3*2 +: 2]            = s3_bresp;
    assign s3_arvalid                    = xs_arvalid[3];
    assign xs_arready[3]                 = s3_arready;
    assign s3_araddr                     = xs_araddr[3*ADDR_W +: ADDR_W];
    assign s3_arid                       = xs_arid[3*SID_W +: SID_W];
    assign s3_arlen                      = xs_arlen[3*8 +: 8];
    assign s3_arsize                     = xs_arsize[3*3 +: 3];
    assign s3_arburst                    = xs_arburst[3*2 +: 2];
    assign xs_rvalid[3]                  = s3_rvalid;
    assign s3_rready                     = xs_rready[3];
    assign xs_rdata[3*DATA_W +: DATA_W]  = s3_rdata;
    assign xs_rid[3*SID_W +: SID_W]      = s3_rid;
    assign xs_rresp[3*2 +: 2]            = s3_rresp;
    assign xs_rlast[3]                   = s3_rlast;

    // =====================================================================
    // Slave 4 mapping
    // =====================================================================
    assign s4_awvalid                    = xs_awvalid[4];
    assign xs_awready[4]                 = s4_awready;
    assign s4_awaddr                     = xs_awaddr[4*ADDR_W +: ADDR_W];
    assign s4_awid                       = xs_awid[4*SID_W +: SID_W];
    assign s4_awlen                      = xs_awlen[4*8 +: 8];
    assign s4_awsize                     = xs_awsize[4*3 +: 3];
    assign s4_awburst                    = xs_awburst[4*2 +: 2];
    assign s4_wvalid                     = xs_wvalid[4];
    assign xs_wready[4]                  = s4_wready;
    assign s4_wdata                      = xs_wdata[4*DATA_W +: DATA_W];
    assign s4_wstrb                      = xs_wstrb[4*STRB_W +: STRB_W];
    assign s4_wlast                      = xs_wlast[4];
    assign xs_bvalid[4]                  = s4_bvalid;
    assign s4_bready                     = xs_bready[4];
    assign xs_bid[4*SID_W +: SID_W]      = s4_bid;
    assign xs_bresp[4*2 +: 2]            = s4_bresp;
    assign s4_arvalid                    = xs_arvalid[4];
    assign xs_arready[4]                 = s4_arready;
    assign s4_araddr                     = xs_araddr[4*ADDR_W +: ADDR_W];
    assign s4_arid                       = xs_arid[4*SID_W +: SID_W];
    assign s4_arlen                      = xs_arlen[4*8 +: 8];
    assign s4_arsize                     = xs_arsize[4*3 +: 3];
    assign s4_arburst                    = xs_arburst[4*2 +: 2];
    assign xs_rvalid[4]                  = s4_rvalid;
    assign s4_rready                     = xs_rready[4];
    assign xs_rdata[4*DATA_W +: DATA_W]  = s4_rdata;
    assign xs_rid[4*SID_W +: SID_W]      = s4_rid;
    assign xs_rresp[4*2 +: 2]            = s4_rresp;
    assign xs_rlast[4]                   = s4_rlast;

    // =====================================================================
    // Crossbar instantiation
    // =====================================================================
    axi_xbar_top u_xbar (
        .clk            (clk),
        .srst           (srst),
        // Master side
        .m_awvalid      (xm_awvalid),
        .m_awready      (xm_awready),
        .m_awid_flat    (xm_awid),
        .m_awaddr_flat  (xm_awaddr),
        .m_awlen_flat   (xm_awlen),
        .m_awsize_flat  (xm_awsize),
        .m_awburst_flat (xm_awburst),
        .m_wvalid       (xm_wvalid),
        .m_wready       (xm_wready),
        .m_wdata_flat   (xm_wdata),
        .m_wstrb_flat   (xm_wstrb),
        .m_wlast        (xm_wlast),
        .m_bvalid       (xm_bvalid),
        .m_bready       (xm_bready),
        .m_bid_flat     (xm_bid),
        .m_bresp_flat   (xm_bresp),
        .m_arvalid      (xm_arvalid),
        .m_arready      (xm_arready),
        .m_arid_flat    (xm_arid),
        .m_araddr_flat  (xm_araddr),
        .m_arlen_flat   (xm_arlen),
        .m_arsize_flat  (xm_arsize),
        .m_arburst_flat (xm_arburst),
        .m_rvalid       (xm_rvalid),
        .m_rready       (xm_rready),
        .m_rid_flat     (xm_rid),
        .m_rdata_flat   (xm_rdata),
        .m_rresp_flat   (xm_rresp),
        .m_rlast        (xm_rlast),
        // Slave side
        .s_awvalid      (xs_awvalid),
        .s_awready      (xs_awready),
        .s_awid_flat    (xs_awid),
        .s_awaddr_flat  (xs_awaddr),
        .s_awlen_flat   (xs_awlen),
        .s_awsize_flat  (xs_awsize),
        .s_awburst_flat (xs_awburst),
        .s_wvalid       (xs_wvalid),
        .s_wready       (xs_wready),
        .s_wdata_flat   (xs_wdata),
        .s_wstrb_flat   (xs_wstrb),
        .s_wlast        (xs_wlast),
        .s_bvalid       (xs_bvalid),
        .s_bready       (xs_bready),
        .s_bid_flat     (xs_bid),
        .s_bresp_flat   (xs_bresp),
        .s_arvalid      (xs_arvalid),
        .s_arready      (xs_arready),
        .s_arid_flat    (xs_arid),
        .s_araddr_flat  (xs_araddr),
        .s_arlen_flat   (xs_arlen),
        .s_arsize_flat  (xs_arsize),
        .s_arburst_flat (xs_arburst),
        .s_rvalid       (xs_rvalid),
        .s_rready       (xs_rready),
        .s_rid_flat     (xs_rid),
        .s_rdata_flat   (xs_rdata),
        .s_rresp_flat   (xs_rresp),
        .s_rlast        (xs_rlast)
    );

endmodule
