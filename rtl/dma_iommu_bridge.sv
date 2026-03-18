// Brendan Lynskey 2025
// DMA-IOMMU Bridge — wires DMA master through IOMMU to crossbar M2
// MIT License
//
// Data path:  DMA AXI master → IOMMU AXI slave → (translate) → IOMMU AXI master → Crossbar M2
// Reg access: Crossbar S3 → AXI slave bridge → DMA register file
//             Crossbar S4 → AXI slave bridge → IOMMU register file

module dma_iommu_bridge
    import soc_pkg::*;
(
    input  logic        clk,
    input  logic        srst,

    // ---- AXI4 Master (IOMMU output → crossbar M2) ----
    output logic              m2_awvalid,
    input  logic              m2_awready,
    output logic [ADDR_W-1:0] m2_awaddr,
    output logic [ID_W-1:0]   m2_awid,
    output logic [7:0]        m2_awlen,
    output logic [2:0]        m2_awsize,
    output logic [1:0]        m2_awburst,

    output logic              m2_wvalid,
    input  logic              m2_wready,
    output logic [DATA_W-1:0] m2_wdata,
    output logic [STRB_W-1:0] m2_wstrb,
    output logic              m2_wlast,

    input  logic              m2_bvalid,
    output logic              m2_bready,
    input  logic [ID_W-1:0]   m2_bid,
    input  logic [1:0]        m2_bresp,

    output logic              m2_arvalid,
    input  logic              m2_arready,
    output logic [ADDR_W-1:0] m2_araddr,
    output logic [ID_W-1:0]   m2_arid,
    output logic [7:0]        m2_arlen,
    output logic [2:0]        m2_arsize,
    output logic [1:0]        m2_arburst,

    input  logic              m2_rvalid,
    output logic              m2_rready,
    input  logic [DATA_W-1:0] m2_rdata,
    input  logic [ID_W-1:0]   m2_rid,
    input  logic [1:0]        m2_rresp,
    input  logic              m2_rlast,

    // ---- AXI4 Slave (crossbar S3 → DMA regs) ----
    input  logic              s3_awvalid,
    output logic              s3_awready,
    input  logic [ADDR_W-1:0] s3_awaddr,
    input  logic [SID_W-1:0]  s3_awid,
    input  logic [7:0]        s3_awlen,
    input  logic [2:0]        s3_awsize,
    input  logic [1:0]        s3_awburst,

    input  logic              s3_wvalid,
    output logic              s3_wready,
    input  logic [DATA_W-1:0] s3_wdata,
    input  logic [STRB_W-1:0] s3_wstrb,
    input  logic              s3_wlast,

    output logic              s3_bvalid,
    input  logic              s3_bready,
    output logic [SID_W-1:0]  s3_bid,
    output logic [1:0]        s3_bresp,

    input  logic              s3_arvalid,
    output logic              s3_arready,
    input  logic [ADDR_W-1:0] s3_araddr,
    input  logic [SID_W-1:0]  s3_arid,
    input  logic [7:0]        s3_arlen,
    input  logic [2:0]        s3_arsize,
    input  logic [1:0]        s3_arburst,

    output logic              s3_rvalid,
    input  logic              s3_rready,
    output logic [DATA_W-1:0] s3_rdata,
    output logic [SID_W-1:0]  s3_rid,
    output logic [1:0]        s3_rresp,
    output logic              s3_rlast,

    // ---- AXI4 Slave (crossbar S4 → IOMMU regs) ----
    input  logic              s4_awvalid,
    output logic              s4_awready,
    input  logic [ADDR_W-1:0] s4_awaddr,
    input  logic [SID_W-1:0]  s4_awid,
    input  logic [7:0]        s4_awlen,
    input  logic [2:0]        s4_awsize,
    input  logic [1:0]        s4_awburst,

    input  logic              s4_wvalid,
    output logic              s4_wready,
    input  logic [DATA_W-1:0] s4_wdata,
    input  logic [STRB_W-1:0] s4_wstrb,
    input  logic              s4_wlast,

    output logic              s4_bvalid,
    input  logic              s4_bready,
    output logic [SID_W-1:0]  s4_bid,
    output logic [1:0]        s4_bresp,

    input  logic              s4_arvalid,
    output logic              s4_arready,
    input  logic [ADDR_W-1:0] s4_araddr,
    input  logic [SID_W-1:0]  s4_arid,
    input  logic [7:0]        s4_arlen,
    input  logic [2:0]        s4_arsize,
    input  logic [1:0]        s4_arburst,

    output logic              s4_rvalid,
    input  logic              s4_rready,
    output logic [DATA_W-1:0] s4_rdata,
    output logic [SID_W-1:0]  s4_rid,
    output logic [1:0]        s4_rresp,
    output logic              s4_rlast,

    // ---- DMA peripheral handshake ----
    input  logic [3:0]        dreq,
    output logic [3:0]        dack,

    // ---- Interrupts ----
    output logic              dma_irq,
    output logic              iommu_fault_irq
);

    // =====================================================================
    // IOMMU AXI address width (34 bits from iommu_pkg::PADDR_W)
    // =====================================================================
    localparam IOMMU_ADDR_W = 34;
    localparam IOMMU_ID_W   = 4;   // iommu_pkg::AXI_ID_W

    // =====================================================================
    // DMA ↔ IOMMU intermediate AXI wires
    // =====================================================================
    // DMA AXI master → IOMMU AXI slave (device side)
    logic                      dma_m_awvalid, dma_m_awready;
    logic [ADDR_W-1:0]         dma_m_awaddr;
    logic [7:0]                dma_m_awlen;
    logic [2:0]                dma_m_awsize;
    logic [1:0]                dma_m_awburst;
    logic                      dma_m_wvalid, dma_m_wready;
    logic [DATA_W-1:0]         dma_m_wdata;
    logic [STRB_W-1:0]         dma_m_wstrb;
    logic                      dma_m_wlast;
    logic                      dma_m_bvalid;
    logic                      dma_m_bready;
    logic [1:0]                dma_m_bresp;
    logic                      dma_m_arvalid, dma_m_arready;
    logic [ADDR_W-1:0]         dma_m_araddr;
    logic [7:0]                dma_m_arlen;
    logic [2:0]                dma_m_arsize;
    logic [1:0]                dma_m_arburst;
    logic                      dma_m_rvalid;
    logic                      dma_m_rready;
    logic [DATA_W-1:0]         dma_m_rdata;
    logic [1:0]                dma_m_rresp;
    logic                      dma_m_rlast;

    // IOMMU AXI master (memory side) — 34-bit addresses
    logic                      iommu_m_awvalid, iommu_m_awready;
    logic [IOMMU_ADDR_W-1:0]   iommu_m_awaddr;
    logic [IOMMU_ID_W-1:0]     iommu_m_awid;
    logic [7:0]                iommu_m_awlen;
    logic [2:0]                iommu_m_awsize;
    logic [1:0]                iommu_m_awburst;
    logic                      iommu_m_wvalid, iommu_m_wready;
    logic [DATA_W-1:0]         iommu_m_wdata;
    logic [STRB_W-1:0]         iommu_m_wstrb;
    logic                      iommu_m_wlast;
    logic                      iommu_m_bvalid;
    logic                      iommu_m_bready;
    logic [IOMMU_ID_W-1:0]     iommu_m_bid;
    logic [1:0]                iommu_m_bresp;
    logic                      iommu_m_arvalid, iommu_m_arready;
    logic [IOMMU_ADDR_W-1:0]   iommu_m_araddr;
    logic [IOMMU_ID_W-1:0]     iommu_m_arid;
    logic [7:0]                iommu_m_arlen;
    logic [2:0]                iommu_m_arsize;
    logic [1:0]                iommu_m_arburst;
    logic                      iommu_m_rvalid;
    logic                      iommu_m_rready;
    logic [DATA_W-1:0]         iommu_m_rdata;
    logic [IOMMU_ID_W-1:0]     iommu_m_rid;
    logic [1:0]                iommu_m_rresp;
    logic                      iommu_m_rlast;

    // =====================================================================
    // DMA register interface wires
    // =====================================================================
    logic                dma_reg_wr_en;
    logic                dma_reg_rd_en;
    logic [11:0]         dma_reg_addr;
    logic [DATA_W-1:0]   dma_reg_wr_data;
    logic [DATA_W-1:0]   dma_reg_rd_data;
    logic                dma_reg_rd_valid;

    // =====================================================================
    // IOMMU register interface wires
    // =====================================================================
    logic                iommu_reg_wr_valid;
    logic                iommu_reg_wr_ready;
    logic [7:0]          iommu_reg_wr_addr;
    logic [31:0]         iommu_reg_wr_data;
    logic                iommu_reg_rd_valid;
    logic                iommu_reg_rd_ready;
    logic [7:0]          iommu_reg_rd_addr;
    logic [31:0]         iommu_reg_rd_data;

    // =====================================================================
    // DMA Controller
    // =====================================================================
    dma_top #(
        .NUM_CH        (4),
        .DATA_W        (DATA_W),
        .ADDR_W        (ADDR_W),
        .MAX_BURST_LEN (16),
        .ARB_MODE      ("ROUND_ROBIN")
    ) u_dma (
        .clk            (clk),
        .srst           (srst),
        // Register interface
        .reg_wr_en      (dma_reg_wr_en),
        .reg_rd_en      (dma_reg_rd_en),
        .reg_addr       (dma_reg_addr),
        .reg_wr_data    (dma_reg_wr_data),
        .reg_rd_data    (dma_reg_rd_data),
        .reg_rd_valid   (dma_reg_rd_valid),
        // AXI master (no ID signals)
        .m_axi_awvalid  (dma_m_awvalid),
        .m_axi_awready  (dma_m_awready),
        .m_axi_awaddr   (dma_m_awaddr),
        .m_axi_awlen    (dma_m_awlen),
        .m_axi_awsize   (dma_m_awsize),
        .m_axi_awburst  (dma_m_awburst),
        .m_axi_wvalid   (dma_m_wvalid),
        .m_axi_wready   (dma_m_wready),
        .m_axi_wdata    (dma_m_wdata),
        .m_axi_wstrb    (dma_m_wstrb),
        .m_axi_wlast    (dma_m_wlast),
        .m_axi_bvalid   (dma_m_bvalid),
        .m_axi_bready   (dma_m_bready),
        .m_axi_bresp    (dma_m_bresp),
        .m_axi_arvalid  (dma_m_arvalid),
        .m_axi_arready  (dma_m_arready),
        .m_axi_araddr   (dma_m_araddr),
        .m_axi_arlen    (dma_m_arlen),
        .m_axi_arsize   (dma_m_arsize),
        .m_axi_arburst  (dma_m_arburst),
        .m_axi_rvalid   (dma_m_rvalid),
        .m_axi_rready   (dma_m_rready),
        .m_axi_rdata    (dma_m_rdata),
        .m_axi_rresp    (dma_m_rresp),
        .m_axi_rlast    (dma_m_rlast),
        // Peripheral handshake
        .dreq           (dreq),
        .dack           (dack),
        // Interrupt
        .irq            (dma_irq)
    );

    // =====================================================================
    // IOMMU — AXI wrapper
    // =====================================================================
    // DMA AXI master → IOMMU AXI slave: zero-extend addr 32→34, tie ID=0
    iommu_axi_wrapper u_iommu (
        .clk            (clk),
        .srst           (srst),
        // Slave (device side) — from DMA
        .s_axi_awid     ({IOMMU_ID_W{1'b0}}),
        .s_axi_awaddr   ({{(IOMMU_ADDR_W-ADDR_W){1'b0}}, dma_m_awaddr}),
        .s_axi_awlen    (dma_m_awlen),
        .s_axi_awsize   (dma_m_awsize),
        .s_axi_awburst  (dma_m_awburst),
        .s_axi_awvalid  (dma_m_awvalid),
        .s_axi_awready  (dma_m_awready),
        .s_axi_wdata    (dma_m_wdata),
        .s_axi_wstrb    (dma_m_wstrb),
        .s_axi_wlast    (dma_m_wlast),
        .s_axi_wvalid   (dma_m_wvalid),
        .s_axi_wready   (dma_m_wready),
        .s_axi_bid      (),
        .s_axi_bresp    (dma_m_bresp),
        .s_axi_bvalid   (dma_m_bvalid),
        .s_axi_bready   (dma_m_bready),
        .s_axi_arid     ({IOMMU_ID_W{1'b0}}),
        .s_axi_araddr   ({{(IOMMU_ADDR_W-ADDR_W){1'b0}}, dma_m_araddr}),
        .s_axi_arlen    (dma_m_arlen),
        .s_axi_arsize   (dma_m_arsize),
        .s_axi_arburst  (dma_m_arburst),
        .s_axi_arvalid  (dma_m_arvalid),
        .s_axi_arready  (dma_m_arready),
        .s_axi_rid      (),
        .s_axi_rdata    (dma_m_rdata),
        .s_axi_rresp    (dma_m_rresp),
        .s_axi_rlast    (dma_m_rlast),
        .s_axi_rvalid   (dma_m_rvalid),
        .s_axi_rready   (dma_m_rready),
        // Master (memory side) — to crossbar M2 (34-bit internal)
        .m_axi_awid     (iommu_m_awid),
        .m_axi_awaddr   (iommu_m_awaddr),
        .m_axi_awlen    (iommu_m_awlen),
        .m_axi_awsize   (iommu_m_awsize),
        .m_axi_awburst  (iommu_m_awburst),
        .m_axi_awvalid  (iommu_m_awvalid),
        .m_axi_awready  (iommu_m_awready),
        .m_axi_wdata    (iommu_m_wdata),
        .m_axi_wstrb    (iommu_m_wstrb),
        .m_axi_wlast    (iommu_m_wlast),
        .m_axi_wvalid   (iommu_m_wvalid),
        .m_axi_wready   (iommu_m_wready),
        .m_axi_bid      (iommu_m_bid),
        .m_axi_bresp    (iommu_m_bresp),
        .m_axi_bvalid   (iommu_m_bvalid),
        .m_axi_bready   (iommu_m_bready),
        .m_axi_arid     (iommu_m_arid),
        .m_axi_araddr   (iommu_m_araddr),
        .m_axi_arlen    (iommu_m_arlen),
        .m_axi_arsize   (iommu_m_arsize),
        .m_axi_arburst  (iommu_m_arburst),
        .m_axi_arvalid  (iommu_m_arvalid),
        .m_axi_arready  (iommu_m_arready),
        .m_axi_rid      (iommu_m_rid),
        .m_axi_rdata    (iommu_m_rdata),
        .m_axi_rresp    (iommu_m_rresp),
        .m_axi_rlast    (iommu_m_rlast),
        .m_axi_rvalid   (iommu_m_rvalid),
        .m_axi_rready   (iommu_m_rready),
        // Register interface
        .reg_wr_valid   (iommu_reg_wr_valid),
        .reg_wr_ready   (iommu_reg_wr_ready),
        .reg_wr_addr    (iommu_reg_wr_addr),
        .reg_wr_data    (iommu_reg_wr_data),
        .reg_rd_valid   (iommu_reg_rd_valid),
        .reg_rd_ready   (iommu_reg_rd_ready),
        .reg_rd_addr    (iommu_reg_rd_addr),
        .reg_rd_data    (iommu_reg_rd_data),
        // Interrupt
        .irq_fault      (iommu_fault_irq)
    );

    // =====================================================================
    // IOMMU AXI master → crossbar M2 (truncate 34→32 bit addresses)
    // =====================================================================
    assign m2_awvalid = iommu_m_awvalid;
    assign iommu_m_awready = m2_awready;
    assign m2_awaddr  = iommu_m_awaddr[ADDR_W-1:0];
    assign m2_awid    = iommu_m_awid;
    assign m2_awlen   = iommu_m_awlen;
    assign m2_awsize  = iommu_m_awsize;
    assign m2_awburst = iommu_m_awburst;

    assign m2_wvalid  = iommu_m_wvalid;
    assign iommu_m_wready = m2_wready;
    assign m2_wdata   = iommu_m_wdata;
    assign m2_wstrb   = iommu_m_wstrb;
    assign m2_wlast   = iommu_m_wlast;

    assign iommu_m_bvalid = m2_bvalid;
    assign m2_bready  = iommu_m_bready;
    assign iommu_m_bid    = m2_bid;
    assign iommu_m_bresp  = m2_bresp;

    assign m2_arvalid = iommu_m_arvalid;
    assign iommu_m_arready = m2_arready;
    assign m2_araddr  = iommu_m_araddr[ADDR_W-1:0];
    assign m2_arid    = iommu_m_arid;
    assign m2_arlen   = iommu_m_arlen;
    assign m2_arsize  = iommu_m_arsize;
    assign m2_arburst = iommu_m_arburst;

    assign iommu_m_rvalid = m2_rvalid;
    assign m2_rready  = iommu_m_rready;
    assign iommu_m_rdata  = m2_rdata;
    assign iommu_m_rid    = m2_rid;
    assign iommu_m_rresp  = m2_rresp;
    assign iommu_m_rlast  = m2_rlast;

    // =====================================================================
    // S3: AXI slave bridge for DMA registers (registered reads)
    // =====================================================================
    // DMA reg_rd_data is registered (1-cycle latency after rd_en), so we
    // cannot use axi_periph_bridge directly. Custom FSM with wait state.

    typedef enum logic [1:0] { S3_WR_IDLE, S3_WR_DATA, S3_WR_RESP } s3_wr_state_t;
    typedef enum logic [1:0] { S3_RD_IDLE, S3_RD_WAIT, S3_RD_RESP } s3_rd_state_t;

    s3_wr_state_t s3_wr_state;
    s3_rd_state_t s3_rd_state;
    logic [SID_W-1:0]  s3_wr_id_r, s3_rd_id_r;
    logic [ADDR_W-1:0] s3_wr_addr_r, s3_rd_addr_r;
    logic [DATA_W-1:0] s3_rd_data_r;

    // Write FSM
    always_ff @(posedge clk) begin
        if (srst) begin
            s3_wr_state  <= S3_WR_IDLE;
            s3_wr_id_r   <= '0;
            s3_wr_addr_r <= '0;
        end else begin
            case (s3_wr_state)
                S3_WR_IDLE: begin
                    if (s3_awvalid && s3_awready) begin
                        s3_wr_id_r   <= s3_awid;
                        s3_wr_addr_r <= s3_awaddr;
                        s3_wr_state  <= S3_WR_DATA;
                    end
                end
                S3_WR_DATA: begin
                    if (s3_wvalid && s3_wready) begin
                        s3_wr_state <= S3_WR_RESP;
                    end
                end
                S3_WR_RESP: begin
                    if (s3_bvalid && s3_bready) begin
                        s3_wr_state <= S3_WR_IDLE;
                    end
                end
                default: s3_wr_state <= S3_WR_IDLE;
            endcase
        end
    end

    assign s3_awready = (s3_wr_state == S3_WR_IDLE);
    assign s3_wready  = (s3_wr_state == S3_WR_DATA);
    assign s3_bvalid  = (s3_wr_state == S3_WR_RESP);
    assign s3_bid     = s3_wr_id_r;
    assign s3_bresp   = 2'b00;

    // Read FSM (with wait state for registered DMA read data)
    always_ff @(posedge clk) begin
        if (srst) begin
            s3_rd_state  <= S3_RD_IDLE;
            s3_rd_id_r   <= '0;
            s3_rd_addr_r <= '0;
            s3_rd_data_r <= '0;
        end else begin
            case (s3_rd_state)
                S3_RD_IDLE: begin
                    if (s3_arvalid && s3_arready) begin
                        s3_rd_id_r   <= s3_arid;
                        s3_rd_addr_r <= s3_araddr;
                        s3_rd_state  <= S3_RD_WAIT;
                    end
                end
                S3_RD_WAIT: begin
                    if (dma_reg_rd_valid) begin
                        s3_rd_data_r <= dma_reg_rd_data;
                        s3_rd_state  <= S3_RD_RESP;
                    end
                end
                S3_RD_RESP: begin
                    if (s3_rvalid && s3_rready) begin
                        s3_rd_state <= S3_RD_IDLE;
                    end
                end
                default: s3_rd_state <= S3_RD_IDLE;
            endcase
        end
    end

    // Block reads during write data phase to avoid reg_addr mux conflict
    assign s3_arready = (s3_rd_state == S3_RD_IDLE) && (s3_wr_state != S3_WR_DATA);
    assign s3_rvalid  = (s3_rd_state == S3_RD_RESP);
    assign s3_rdata   = s3_rd_data_r;
    assign s3_rid     = s3_rd_id_r;
    assign s3_rresp   = 2'b00;
    assign s3_rlast   = s3_rvalid;

    // DMA register interface drives
    assign dma_reg_wr_en   = (s3_wr_state == S3_WR_DATA) && s3_wvalid;
    assign dma_reg_rd_en   = s3_arvalid && s3_arready;
    assign dma_reg_addr    = dma_reg_wr_en ? s3_wr_addr_r[11:0] : s3_araddr[11:0];
    assign dma_reg_wr_data = s3_wdata;

    // =====================================================================
    // S4: AXI slave bridge for IOMMU registers (combinational reads)
    // =====================================================================
    // IOMMU reg reads are combinational, so axi_periph_bridge works directly.

    logic                s4_periph_wr_en;
    logic                s4_periph_rd_en;
    logic [ADDR_W-1:0]   s4_periph_addr;
    logic [DATA_W-1:0]   s4_periph_wdata;
    logic [STRB_W-1:0]   s4_periph_wstrb;
    logic [DATA_W-1:0]   s4_periph_rdata;

    axi_periph_bridge #(
        .ADDR_W (ADDR_W),
        .DATA_W (DATA_W),
        .ID_W   (SID_W)
    ) u_s4_bridge (
        .clk         (clk),
        .srst        (srst),
        .awvalid     (s4_awvalid),
        .awready     (s4_awready),
        .awaddr      (s4_awaddr),
        .awid        (s4_awid),
        .awlen       (s4_awlen),
        .awsize      (s4_awsize),
        .awburst     (s4_awburst),
        .wvalid      (s4_wvalid),
        .wready      (s4_wready),
        .wdata       (s4_wdata),
        .wstrb       (s4_wstrb),
        .wlast       (s4_wlast),
        .bvalid      (s4_bvalid),
        .bready      (s4_bready),
        .bid         (s4_bid),
        .bresp       (s4_bresp),
        .arvalid     (s4_arvalid),
        .arready     (s4_arready),
        .araddr      (s4_araddr),
        .arid        (s4_arid),
        .arlen       (s4_arlen),
        .arsize      (s4_arsize),
        .arburst     (s4_arburst),
        .rvalid      (s4_rvalid),
        .rready      (s4_rready),
        .rdata       (s4_rdata),
        .rid         (s4_rid),
        .rresp       (s4_rresp),
        .rlast       (s4_rlast),
        .periph_wr_en(s4_periph_wr_en),
        .periph_rd_en(s4_periph_rd_en),
        .periph_addr (s4_periph_addr),
        .periph_wdata(s4_periph_wdata),
        .periph_wstrb(s4_periph_wstrb),
        .periph_rdata(s4_periph_rdata)
    );

    // IOMMU register interface wiring
    assign iommu_reg_wr_valid = s4_periph_wr_en;
    assign iommu_reg_rd_valid = s4_periph_rd_en;
    assign iommu_reg_wr_addr  = s4_periph_addr[7:0];
    assign iommu_reg_rd_addr  = s4_periph_addr[7:0];
    assign iommu_reg_wr_data  = s4_periph_wdata;
    assign s4_periph_rdata    = iommu_reg_rd_data;

endmodule
