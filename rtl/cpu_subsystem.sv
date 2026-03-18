// Brendan Lynskey 2025
// CPU Subsystem — BRV32P core + L1 caches with AXI4 master interfaces
// MIT License
//
// Instantiates the BRV32P 5-stage pipelined RV32IMC core with its
// instruction and data caches. Bridges the simple cache memory interfaces
// to full AXI4 master ports for connection to the MMU adapters.
//
// I-cache AXI port: read-only (AR/R channels active, AW/W/B tied off)
// D-cache AXI port: read/write (all 5 channels active)

module cpu_subsystem
    import soc_pkg::*;
(
    input  logic        clk,
    input  logic        srst,

    // =========================================================================
    // I-cache AXI4 master (connects to cpu_axi_adapter / I-MMU)
    // =========================================================================
    output logic              ic_awvalid,
    input  logic              ic_awready,
    output logic [ADDR_W-1:0] ic_awaddr,
    output logic [ID_W-1:0]   ic_awid,
    output logic [7:0]        ic_awlen,
    output logic [2:0]        ic_awsize,
    output logic [1:0]        ic_awburst,

    output logic              ic_wvalid,
    input  logic              ic_wready,
    output logic [DATA_W-1:0] ic_wdata,
    output logic [STRB_W-1:0] ic_wstrb,
    output logic              ic_wlast,

    input  logic              ic_bvalid,
    output logic              ic_bready,
    input  logic [ID_W-1:0]   ic_bid,
    input  logic [1:0]        ic_bresp,

    output logic              ic_arvalid,
    input  logic              ic_arready,
    output logic [ADDR_W-1:0] ic_araddr,
    output logic [ID_W-1:0]   ic_arid,
    output logic [7:0]        ic_arlen,
    output logic [2:0]        ic_arsize,
    output logic [1:0]        ic_arburst,

    input  logic              ic_rvalid,
    output logic              ic_rready,
    input  logic [DATA_W-1:0] ic_rdata,
    input  logic [ID_W-1:0]   ic_rid,
    input  logic [1:0]        ic_rresp,
    input  logic              ic_rlast,

    // =========================================================================
    // D-cache AXI4 master (connects to cpu_axi_adapter / D-MMU)
    // =========================================================================
    output logic              dc_awvalid,
    input  logic              dc_awready,
    output logic [ADDR_W-1:0] dc_awaddr,
    output logic [ID_W-1:0]   dc_awid,
    output logic [7:0]        dc_awlen,
    output logic [2:0]        dc_awsize,
    output logic [1:0]        dc_awburst,

    output logic              dc_wvalid,
    input  logic              dc_wready,
    output logic [DATA_W-1:0] dc_wdata,
    output logic [STRB_W-1:0] dc_wstrb,
    output logic              dc_wlast,

    input  logic              dc_bvalid,
    output logic              dc_bready,
    input  logic [ID_W-1:0]   dc_bid,
    input  logic [1:0]        dc_bresp,

    output logic              dc_arvalid,
    input  logic              dc_arready,
    output logic [ADDR_W-1:0] dc_araddr,
    output logic [ID_W-1:0]   dc_arid,
    output logic [7:0]        dc_arlen,
    output logic [2:0]        dc_arsize,
    output logic [1:0]        dc_arburst,

    input  logic              dc_rvalid,
    output logic              dc_rready,
    input  logic [DATA_W-1:0] dc_rdata,
    input  logic [ID_W-1:0]   dc_rid,
    input  logic [1:0]        dc_rresp,
    input  logic              dc_rlast,

    // =========================================================================
    // Interrupts
    // =========================================================================
    input  logic              meip,
    input  logic              timer_irq
);

    // =========================================================================
    // Reset conversion: SoC uses srst (sync active-high), CPU uses rst_n (async active-low)
    // =========================================================================
    wire rst_n;
    assign rst_n = ~srst;

    // =========================================================================
    // Core <-> Cache signals
    // =========================================================================
    wire [31:0] core_imem_addr, core_imem_rdata;
    wire        core_imem_rd, core_imem_ready;

    wire [31:0] core_dmem_addr, core_dmem_wdata, core_dmem_rdata;
    wire        core_dmem_rd, core_dmem_wr, core_dmem_ready;
    wire [1:0]  core_dmem_width;
    wire        core_dmem_sign_ext;

    // =========================================================================
    // Cache <-> AXI bridge signals
    // =========================================================================
    // I-cache memory interface
    wire [31:0] ic_mem_addr;
    wire        ic_mem_rd;
    wire [31:0] ic_mem_rdata;
    wire        ic_mem_valid;

    // D-cache memory interface
    wire [31:0] dc_mem_addr;
    wire        dc_mem_rd;
    wire        dc_mem_wr;
    wire [31:0] dc_mem_wdata;
    wire [3:0]  dc_mem_wstrb;
    wire [31:0] dc_mem_rdata;
    wire        dc_mem_valid;
    wire        dc_mem_wr_done;

    // =========================================================================
    // CPU Core
    // =========================================================================
    brv32p_core u_core (
        .clk           (clk),
        .rst_n         (rst_n),
        .imem_addr     (core_imem_addr),
        .imem_rd       (core_imem_rd),
        .imem_rdata    (core_imem_rdata),
        .imem_ready    (core_imem_ready),
        .dmem_addr     (core_dmem_addr),
        .dmem_rd       (core_dmem_rd),
        .dmem_wr       (core_dmem_wr),
        .dmem_width    (core_dmem_width),
        .dmem_sign_ext (core_dmem_sign_ext),
        .dmem_wdata    (core_dmem_wdata),
        .dmem_rdata    (core_dmem_rdata),
        .dmem_ready    (core_dmem_ready),
        .ext_irq       (meip),
        .timer_irq     (timer_irq)
    );

    // =========================================================================
    // I-Cache
    // =========================================================================
    icache u_icache (
        .clk       (clk),
        .rst_n     (rst_n),
        .addr      (core_imem_addr),
        .rd_en     (core_imem_rd),
        .rdata     (core_imem_rdata),
        .ready     (core_imem_ready),
        .mem_addr  (ic_mem_addr),
        .mem_rd    (ic_mem_rd),
        .mem_rdata (ic_mem_rdata),
        .mem_valid (ic_mem_valid)
    );

    // =========================================================================
    // D-Cache
    // =========================================================================
    dcache u_dcache (
        .clk        (clk),
        .rst_n      (rst_n),
        .addr       (core_dmem_addr),
        .rd_en      (core_dmem_rd),
        .wr_en      (core_dmem_wr),
        .width      (core_dmem_width),
        .sign_ext   (core_dmem_sign_ext),
        .wdata      (core_dmem_wdata),
        .rdata      (core_dmem_rdata),
        .ready      (core_dmem_ready),
        .mem_addr   (dc_mem_addr),
        .mem_rd     (dc_mem_rd),
        .mem_wr     (dc_mem_wr),
        .mem_wdata  (dc_mem_wdata),
        .mem_wstrb  (dc_mem_wstrb),
        .mem_rdata  (dc_mem_rdata),
        .mem_valid  (dc_mem_valid),
        .mem_wr_done(dc_mem_wr_done)
    );

    // =========================================================================
    // I-Cache Memory Interface → AXI4 Bridge (read-only)
    // =========================================================================
    // Converts the icache's simple mem_rd/mem_addr/mem_rdata/mem_valid
    // interface to AXI4 single-beat read transactions.

    typedef enum logic [1:0] {
        IC_IDLE,
        IC_AR,
        IC_R
    } ic_bridge_state_t;

    ic_bridge_state_t ic_bstate;
    logic [31:0] ic_req_addr;

    always_ff @(posedge clk) begin
        if (srst) begin
            ic_bstate  <= IC_IDLE;
            ic_req_addr <= '0;
        end else begin
            case (ic_bstate)
                IC_IDLE: begin
                    if (ic_mem_rd) begin
                        ic_req_addr <= ic_mem_addr;
                        ic_bstate   <= IC_AR;
                    end
                end
                IC_AR: begin
                    if (ic_arready)
                        ic_bstate <= IC_R;
                end
                IC_R: begin
                    if (ic_rvalid)
                        ic_bstate <= IC_IDLE;
                end
                default: ic_bstate <= IC_IDLE;
            endcase
        end
    end

    // AXI4 AR channel
    assign ic_arvalid = (ic_bstate == IC_AR);
    assign ic_araddr  = ic_req_addr;
    assign ic_arid    = '0;
    assign ic_arlen   = 8'd0;      // single beat
    assign ic_arsize  = 3'b010;    // 4 bytes
    assign ic_arburst = 2'b01;     // INCR

    // AXI4 R channel
    assign ic_rready = (ic_bstate == IC_R);

    // Back to icache
    assign ic_mem_rdata = ic_rdata;
    assign ic_mem_valid = (ic_bstate == IC_R) && ic_rvalid;

    // I-cache AXI write channels tied off (read-only)
    assign ic_awvalid = 1'b0;
    assign ic_awaddr  = '0;
    assign ic_awid    = '0;
    assign ic_awlen   = '0;
    assign ic_awsize  = '0;
    assign ic_awburst = '0;
    assign ic_wvalid  = 1'b0;
    assign ic_wdata   = '0;
    assign ic_wstrb   = '0;
    assign ic_wlast   = 1'b0;
    assign ic_bready  = 1'b1;

    // =========================================================================
    // D-Cache Memory Interface → AXI4 Bridge (read + write)
    // =========================================================================
    // Converts the dcache's simple memory interface to AXI4 transactions.
    // Reads: single-beat AR/R
    // Writes: single-beat AW/W/B

    typedef enum logic [2:0] {
        DC_BIDLE,
        DC_BAR,
        DC_BR,
        DC_BAW,
        DC_BW,
        DC_BB
    } dc_bridge_state_t;

    dc_bridge_state_t dc_bstate;
    logic [31:0] dc_req_addr;
    logic [31:0] dc_req_wdata;
    logic [3:0]  dc_req_wstrb;

    always_ff @(posedge clk) begin
        if (srst) begin
            dc_bstate    <= DC_BIDLE;
            dc_req_addr  <= '0;
            dc_req_wdata <= '0;
            dc_req_wstrb <= '0;
        end else begin
            case (dc_bstate)
                DC_BIDLE: begin
                    if (dc_mem_rd) begin
                        dc_req_addr <= dc_mem_addr;
                        dc_bstate   <= DC_BAR;
                    end else if (dc_mem_wr) begin
                        dc_req_addr  <= dc_mem_addr;
                        dc_req_wdata <= dc_mem_wdata;
                        dc_req_wstrb <= dc_mem_wstrb;
                        dc_bstate    <= DC_BAW;
                    end
                end
                DC_BAR: begin
                    if (dc_arready)
                        dc_bstate <= DC_BR;
                end
                DC_BR: begin
                    if (dc_rvalid)
                        dc_bstate <= DC_BIDLE;
                end
                DC_BAW: begin
                    if (dc_awready)
                        dc_bstate <= DC_BW;
                end
                DC_BW: begin
                    if (dc_wready)
                        dc_bstate <= DC_BB;
                end
                DC_BB: begin
                    if (dc_bvalid)
                        dc_bstate <= DC_BIDLE;
                end
                default: dc_bstate <= DC_BIDLE;
            endcase
        end
    end

    // AXI4 AR channel
    assign dc_arvalid = (dc_bstate == DC_BAR);
    assign dc_araddr  = dc_req_addr;
    assign dc_arid    = '0;
    assign dc_arlen   = 8'd0;
    assign dc_arsize  = 3'b010;
    assign dc_arburst = 2'b01;

    // AXI4 R channel
    assign dc_rready = (dc_bstate == DC_BR);

    // Back to dcache (read path)
    assign dc_mem_rdata = dc_rdata;
    assign dc_mem_valid = (dc_bstate == DC_BR) && dc_rvalid;

    // AXI4 AW channel
    assign dc_awvalid = (dc_bstate == DC_BAW);
    assign dc_awaddr  = dc_req_addr;
    assign dc_awid    = '0;
    assign dc_awlen   = 8'd0;
    assign dc_awsize  = 3'b010;
    assign dc_awburst = 2'b01;

    // AXI4 W channel
    assign dc_wvalid = (dc_bstate == DC_BW);
    assign dc_wdata  = dc_req_wdata;
    assign dc_wstrb  = dc_req_wstrb;
    assign dc_wlast  = 1'b1;

    // AXI4 B channel
    assign dc_bready = (dc_bstate == DC_BB);
    assign dc_mem_wr_done = (dc_bstate == DC_BB) && dc_bvalid;

endmodule
