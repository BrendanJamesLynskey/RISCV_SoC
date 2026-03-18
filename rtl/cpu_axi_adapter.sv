// Brendan Lynskey 2025
// CPU AXI Adapter — translates virtual addresses via MMU bridge, muxes with PTW
// MIT License
//
// Accepts AXI4 from the CPU (or testbench), extracts the address, sends it
// through the MMU bridge for translation, then re-issues the transaction
// with the physical address to the crossbar.  Also muxes PTW AXI reads
// onto the crossbar port during address translation.

module cpu_axi_adapter
    import soc_pkg::*;
    import mmu_pkg::*;
#(
    parameter logic IS_IPORT = 1'b0   // 1: I-port (ACCESS_EXECUTE), 0: D-port (ACCESS_LOAD/STORE)
)(
    input  logic        clk,
    input  logic        srst,

    // ---- CPU-side AXI4 (from testbench or CPU cache miss port) ----
    input  logic              cpu_awvalid,
    output logic              cpu_awready,
    input  logic [ADDR_W-1:0] cpu_awaddr,
    input  logic [ID_W-1:0]   cpu_awid,
    input  logic [7:0]        cpu_awlen,
    input  logic [2:0]        cpu_awsize,
    input  logic [1:0]        cpu_awburst,

    input  logic              cpu_wvalid,
    output logic              cpu_wready,
    input  logic [DATA_W-1:0] cpu_wdata,
    input  logic [STRB_W-1:0] cpu_wstrb,
    input  logic              cpu_wlast,

    output logic              cpu_bvalid,
    input  logic              cpu_bready,
    output logic [ID_W-1:0]   cpu_bid,
    output logic [1:0]        cpu_bresp,

    input  logic              cpu_arvalid,
    output logic              cpu_arready,
    input  logic [ADDR_W-1:0] cpu_araddr,
    input  logic [ID_W-1:0]   cpu_arid,
    input  logic [7:0]        cpu_arlen,
    input  logic [2:0]        cpu_arsize,
    input  logic [1:0]        cpu_arburst,

    output logic              cpu_rvalid,
    input  logic              cpu_rready,
    output logic [DATA_W-1:0] cpu_rdata,
    output logic [ID_W-1:0]   cpu_rid,
    output logic [1:0]        cpu_rresp,
    output logic              cpu_rlast,

    // ---- MMU translation interface (to/from mmu_axi_bridge) ----
    output logic        trans_req_valid,
    input  logic        trans_req_ready,
    output logic [31:0] trans_vaddr,
    output logic [1:0]  trans_access_type,
    output logic        trans_priv_mode,

    input  logic        trans_resp_valid,
    input  logic [31:0] trans_paddr,
    input  logic        trans_fault,
    input  logic [1:0]  trans_fault_type,

    // ---- PTW AXI4 read port (from mmu_axi_bridge, muxed to crossbar) ----
    input  logic              ptw_arvalid,
    output logic              ptw_arready,
    input  logic [ADDR_W-1:0] ptw_araddr,
    input  logic [ID_W-1:0]   ptw_arid,
    input  logic [7:0]        ptw_arlen,
    input  logic [2:0]        ptw_arsize,
    input  logic [1:0]        ptw_arburst,

    output logic              ptw_rvalid,
    input  logic              ptw_rready,
    output logic [DATA_W-1:0] ptw_rdata,
    output logic [ID_W-1:0]   ptw_rid,
    output logic [1:0]        ptw_rresp,
    output logic              ptw_rlast,

    // ---- Crossbar-side AXI4 master (output to crossbar) ----
    output logic              xbar_awvalid,
    input  logic              xbar_awready,
    output logic [ADDR_W-1:0] xbar_awaddr,
    output logic [ID_W-1:0]   xbar_awid,
    output logic [7:0]        xbar_awlen,
    output logic [2:0]        xbar_awsize,
    output logic [1:0]        xbar_awburst,

    output logic              xbar_wvalid,
    input  logic              xbar_wready,
    output logic [DATA_W-1:0] xbar_wdata,
    output logic [STRB_W-1:0] xbar_wstrb,
    output logic              xbar_wlast,

    input  logic              xbar_bvalid,
    output logic              xbar_bready,
    input  logic [ID_W-1:0]   xbar_bid,
    input  logic [1:0]        xbar_bresp,

    output logic              xbar_arvalid,
    input  logic              xbar_arready,
    output logic [ADDR_W-1:0] xbar_araddr,
    output logic [ID_W-1:0]   xbar_arid,
    output logic [7:0]        xbar_arlen,
    output logic [2:0]        xbar_arsize,
    output logic [1:0]        xbar_arburst,

    input  logic              xbar_rvalid,
    output logic              xbar_rready,
    input  logic [DATA_W-1:0] xbar_rdata,
    input  logic [ID_W-1:0]   xbar_rid,
    input  logic [1:0]        xbar_rresp,
    input  logic              xbar_rlast
);

    // ---- Main FSM ----
    typedef enum logic [2:0] {
        ST_IDLE,
        ST_XLATE_RD,
        ST_XLATE_WR,
        ST_ISSUE_AR,
        ST_PASS_RDATA,
        ST_ISSUE_AW,
        ST_PASS_WDATA,
        ST_PASS_BRESP
    } state_t;

    state_t state;

    // Registered request fields
    logic [ADDR_W-1:0] vaddr_r;
    logic [ADDR_W-1:0] paddr_r;
    logic [ID_W-1:0]   id_r;
    logic [7:0]        len_r;
    logic [2:0]        size_r;
    logic [1:0]        burst_r;

    // ---- Sequential logic ----
    always_ff @(posedge clk) begin
        if (srst) begin
            state   <= ST_IDLE;
            vaddr_r <= '0;
            paddr_r <= '0;
            id_r    <= '0;
            len_r   <= '0;
            size_r  <= '0;
            burst_r <= '0;
        end else begin
            case (state)
                ST_IDLE: begin
                    // Prioritise reads over writes
                    if (cpu_arvalid) begin
                        vaddr_r <= cpu_araddr;
                        id_r    <= cpu_arid;
                        len_r   <= cpu_arlen;
                        size_r  <= cpu_arsize;
                        burst_r <= cpu_arburst;
                        state   <= ST_XLATE_RD;
                    end else if (cpu_awvalid) begin
                        vaddr_r <= cpu_awaddr;
                        id_r    <= cpu_awid;
                        len_r   <= cpu_awlen;
                        size_r  <= cpu_awsize;
                        burst_r <= cpu_awburst;
                        state   <= ST_XLATE_WR;
                    end
                end

                ST_XLATE_RD: begin
                    if (trans_resp_valid) begin
                        if (trans_fault) begin
                            // Fault — return error response, skip transaction
                            state <= ST_IDLE;
                        end else begin
                            paddr_r <= trans_paddr;
                            state   <= ST_ISSUE_AR;
                        end
                    end
                end

                ST_XLATE_WR: begin
                    if (trans_resp_valid) begin
                        if (trans_fault) begin
                            state <= ST_IDLE;
                        end else begin
                            paddr_r <= trans_paddr;
                            state   <= ST_ISSUE_AW;
                        end
                    end
                end

                ST_ISSUE_AR: begin
                    if (xbar_arready)
                        state <= ST_PASS_RDATA;
                end

                ST_PASS_RDATA: begin
                    if (xbar_rvalid && cpu_rready && xbar_rlast)
                        state <= ST_IDLE;
                end

                ST_ISSUE_AW: begin
                    if (xbar_awready)
                        state <= ST_PASS_WDATA;
                end

                ST_PASS_WDATA: begin
                    if (xbar_wready && cpu_wvalid && cpu_wlast)
                        state <= ST_PASS_BRESP;
                end

                ST_PASS_BRESP: begin
                    if (xbar_bvalid && cpu_bready)
                        state <= ST_IDLE;
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

    // ---- CPU-side handshake ----
    assign cpu_arready = (state == ST_IDLE);
    assign cpu_awready = (state == ST_IDLE) && !cpu_arvalid;  // reads have priority

    // ---- MMU translation request ----
    logic xlating;
    assign xlating = (state == ST_XLATE_RD) || (state == ST_XLATE_WR);

    assign trans_req_valid   = xlating;
    assign trans_vaddr       = vaddr_r;
    assign trans_access_type = (state == ST_XLATE_WR) ? ACCESS_STORE :
                               IS_IPORT              ? ACCESS_EXECUTE :
                                                       ACCESS_LOAD;
    assign trans_priv_mode   = 1'b1;  // supervisor mode default

    // ---- Crossbar AR channel mux (PTW during xlate, CPU otherwise) ----
    always @(*) begin
        if (xlating) begin
            // During translation, PTW may need crossbar AR/R
            xbar_arvalid = ptw_arvalid;
            xbar_araddr  = ptw_araddr;
            xbar_arid    = ptw_arid;
            xbar_arlen   = ptw_arlen;
            xbar_arsize  = ptw_arsize;
            xbar_arburst = ptw_arburst;
        end else if (state == ST_ISSUE_AR) begin
            // CPU read — issue with translated physical address
            xbar_arvalid = 1'b1;
            xbar_araddr  = paddr_r;
            xbar_arid    = id_r;
            xbar_arlen   = len_r;
            xbar_arsize  = size_r;
            xbar_arburst = burst_r;
        end else begin
            xbar_arvalid = 1'b0;
            xbar_araddr  = '0;
            xbar_arid    = '0;
            xbar_arlen   = '0;
            xbar_arsize  = '0;
            xbar_arburst = '0;
        end
    end

    // PTW arready feedback
    assign ptw_arready = xlating ? xbar_arready : 1'b0;

    // ---- Crossbar R channel mux ----
    always @(*) begin
        if (xlating) begin
            // PTW gets read data during translation
            ptw_rvalid = xbar_rvalid;
            ptw_rdata  = xbar_rdata;
            ptw_rid    = xbar_rid;
            ptw_rresp  = xbar_rresp;
            ptw_rlast  = xbar_rlast;
            xbar_rready = ptw_rready;
            // CPU side inactive
            cpu_rvalid = 1'b0;
            cpu_rdata  = '0;
            cpu_rid    = '0;
            cpu_rresp  = '0;
            cpu_rlast  = 1'b0;
        end else if (state == ST_PASS_RDATA) begin
            // CPU gets read data
            cpu_rvalid  = xbar_rvalid;
            cpu_rdata   = xbar_rdata;
            cpu_rid     = id_r;
            cpu_rresp   = xbar_rresp;
            cpu_rlast   = xbar_rlast;
            xbar_rready = cpu_rready;
            // PTW inactive
            ptw_rvalid = 1'b0;
            ptw_rdata  = '0;
            ptw_rid    = '0;
            ptw_rresp  = '0;
            ptw_rlast  = 1'b0;
        end else begin
            cpu_rvalid  = 1'b0;
            cpu_rdata   = '0;
            cpu_rid     = '0;
            cpu_rresp   = '0;
            cpu_rlast   = 1'b0;
            ptw_rvalid  = 1'b0;
            ptw_rdata   = '0;
            ptw_rid     = '0;
            ptw_rresp   = '0;
            ptw_rlast   = 1'b0;
            xbar_rready = 1'b0;
        end
    end

    // ---- Crossbar AW channel (CPU write path only) ----
    assign xbar_awvalid = (state == ST_ISSUE_AW);
    assign xbar_awaddr  = paddr_r;
    assign xbar_awid    = id_r;
    assign xbar_awlen   = len_r;
    assign xbar_awsize  = size_r;
    assign xbar_awburst = burst_r;

    // ---- Crossbar W channel (passthrough from CPU) ----
    assign xbar_wvalid = (state == ST_PASS_WDATA) && cpu_wvalid;
    assign xbar_wdata  = cpu_wdata;
    assign xbar_wstrb  = cpu_wstrb;
    assign xbar_wlast  = cpu_wlast;
    assign cpu_wready  = (state == ST_PASS_WDATA) && xbar_wready;

    // ---- Crossbar B channel (passthrough to CPU) ----
    assign cpu_bvalid  = (state == ST_PASS_BRESP) && xbar_bvalid;
    assign cpu_bid     = id_r;
    assign cpu_bresp   = xbar_bresp;
    assign xbar_bready = (state == ST_PASS_BRESP) && cpu_bready;

endmodule
