// Brendan Lynskey 2025
// Testbench for soc_xbar_wrapper
// MIT License

`timescale 1ns/1ps

module tb_soc_xbar_wrapper;

    import soc_pkg::*;

    logic clk, srst;

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    // =====================================================================
    // Master port signals
    // =====================================================================
    // Master 0
    logic              m0_awvalid, m0_awready;
    logic [ADDR_W-1:0] m0_awaddr;
    logic [ID_W-1:0]   m0_awid;
    logic [7:0]        m0_awlen;
    logic [2:0]        m0_awsize;
    logic [1:0]        m0_awburst;
    logic              m0_wvalid, m0_wready;
    logic [DATA_W-1:0] m0_wdata;
    logic [STRB_W-1:0] m0_wstrb;
    logic              m0_wlast;
    logic              m0_bvalid, m0_bready;
    logic [ID_W-1:0]   m0_bid;
    logic [1:0]        m0_bresp;
    logic              m0_arvalid, m0_arready;
    logic [ADDR_W-1:0] m0_araddr;
    logic [ID_W-1:0]   m0_arid;
    logic [7:0]        m0_arlen;
    logic [2:0]        m0_arsize;
    logic [1:0]        m0_arburst;
    logic              m0_rvalid, m0_rready;
    logic [DATA_W-1:0] m0_rdata;
    logic [ID_W-1:0]   m0_rid;
    logic [1:0]        m0_rresp;
    logic              m0_rlast;

    // Master 1
    logic              m1_awvalid, m1_awready;
    logic [ADDR_W-1:0] m1_awaddr;
    logic [ID_W-1:0]   m1_awid;
    logic [7:0]        m1_awlen;
    logic [2:0]        m1_awsize;
    logic [1:0]        m1_awburst;
    logic              m1_wvalid, m1_wready;
    logic [DATA_W-1:0] m1_wdata;
    logic [STRB_W-1:0] m1_wstrb;
    logic              m1_wlast;
    logic              m1_bvalid, m1_bready;
    logic [ID_W-1:0]   m1_bid;
    logic [1:0]        m1_bresp;
    logic              m1_arvalid, m1_arready;
    logic [ADDR_W-1:0] m1_araddr;
    logic [ID_W-1:0]   m1_arid;
    logic [7:0]        m1_arlen;
    logic [2:0]        m1_arsize;
    logic [1:0]        m1_arburst;
    logic              m1_rvalid, m1_rready;
    logic [DATA_W-1:0] m1_rdata;
    logic [ID_W-1:0]   m1_rid;
    logic [1:0]        m1_rresp;
    logic              m1_rlast;

    // Master 2
    logic              m2_awvalid, m2_awready;
    logic [ADDR_W-1:0] m2_awaddr;
    logic [ID_W-1:0]   m2_awid;
    logic [7:0]        m2_awlen;
    logic [2:0]        m2_awsize;
    logic [1:0]        m2_awburst;
    logic              m2_wvalid, m2_wready;
    logic [DATA_W-1:0] m2_wdata;
    logic [STRB_W-1:0] m2_wstrb;
    logic              m2_wlast;
    logic              m2_bvalid, m2_bready;
    logic [ID_W-1:0]   m2_bid;
    logic [1:0]        m2_bresp;
    logic              m2_arvalid, m2_arready;
    logic [ADDR_W-1:0] m2_araddr;
    logic [ID_W-1:0]   m2_arid;
    logic [7:0]        m2_arlen;
    logic [2:0]        m2_arsize;
    logic [1:0]        m2_arburst;
    logic              m2_rvalid, m2_rready;
    logic [DATA_W-1:0] m2_rdata;
    logic [ID_W-1:0]   m2_rid;
    logic [1:0]        m2_rresp;
    logic              m2_rlast;

    // =====================================================================
    // Slave port signals
    // =====================================================================
    logic              s_awvalid [0:4];
    logic              s_awready [0:4];
    logic [ADDR_W-1:0] s_awaddr  [0:4];
    logic [SID_W-1:0]  s_awid    [0:4];
    logic [7:0]        s_awlen   [0:4];
    logic [2:0]        s_awsize  [0:4];
    logic [1:0]        s_awburst [0:4];
    logic              s_wvalid  [0:4];
    logic              s_wready  [0:4];
    logic [DATA_W-1:0] s_wdata   [0:4];
    logic [STRB_W-1:0] s_wstrb   [0:4];
    logic              s_wlast   [0:4];
    logic              s_bvalid  [0:4];
    logic              s_bready  [0:4];
    logic [SID_W-1:0]  s_bid     [0:4];
    logic [1:0]        s_bresp   [0:4];
    logic              s_arvalid [0:4];
    logic              s_arready [0:4];
    logic [ADDR_W-1:0] s_araddr  [0:4];
    logic [SID_W-1:0]  s_arid    [0:4];
    logic [7:0]        s_arlen   [0:4];
    logic [2:0]        s_arsize  [0:4];
    logic [1:0]        s_arburst [0:4];
    logic              s_rvalid  [0:4];
    logic              s_rready  [0:4];
    logic [DATA_W-1:0] s_rdata   [0:4];
    logic [SID_W-1:0]  s_rid     [0:4];
    logic [1:0]        s_rresp   [0:4];
    logic              s_rlast   [0:4];

    // Reset flag clear — pulse srst briefly to clear bfm_aw_flag
    task automatic clear_aw_flags;
        srst = 1;
        @(posedge clk);
        srst = 0;
        @(posedge clk);
    endtask

    // =====================================================================
    // DUT
    // =====================================================================
    soc_xbar_wrapper u_dut (
        .clk  (clk),
        .srst (srst),
        // Master 0
        .m0_awvalid (m0_awvalid), .m0_awready (m0_awready),
        .m0_awaddr  (m0_awaddr),  .m0_awid    (m0_awid),
        .m0_awlen   (m0_awlen),   .m0_awsize  (m0_awsize),
        .m0_awburst (m0_awburst),
        .m0_wvalid  (m0_wvalid),  .m0_wready  (m0_wready),
        .m0_wdata   (m0_wdata),   .m0_wstrb   (m0_wstrb),
        .m0_wlast   (m0_wlast),
        .m0_bvalid  (m0_bvalid),  .m0_bready  (m0_bready),
        .m0_bid     (m0_bid),     .m0_bresp   (m0_bresp),
        .m0_arvalid (m0_arvalid), .m0_arready (m0_arready),
        .m0_araddr  (m0_araddr),  .m0_arid    (m0_arid),
        .m0_arlen   (m0_arlen),   .m0_arsize  (m0_arsize),
        .m0_arburst (m0_arburst),
        .m0_rvalid  (m0_rvalid),  .m0_rready  (m0_rready),
        .m0_rdata   (m0_rdata),   .m0_rid     (m0_rid),
        .m0_rresp   (m0_rresp),   .m0_rlast   (m0_rlast),
        // Master 1
        .m1_awvalid (m1_awvalid), .m1_awready (m1_awready),
        .m1_awaddr  (m1_awaddr),  .m1_awid    (m1_awid),
        .m1_awlen   (m1_awlen),   .m1_awsize  (m1_awsize),
        .m1_awburst (m1_awburst),
        .m1_wvalid  (m1_wvalid),  .m1_wready  (m1_wready),
        .m1_wdata   (m1_wdata),   .m1_wstrb   (m1_wstrb),
        .m1_wlast   (m1_wlast),
        .m1_bvalid  (m1_bvalid),  .m1_bready  (m1_bready),
        .m1_bid     (m1_bid),     .m1_bresp   (m1_bresp),
        .m1_arvalid (m1_arvalid), .m1_arready (m1_arready),
        .m1_araddr  (m1_araddr),  .m1_arid    (m1_arid),
        .m1_arlen   (m1_arlen),   .m1_arsize  (m1_arsize),
        .m1_arburst (m1_arburst),
        .m1_rvalid  (m1_rvalid),  .m1_rready  (m1_rready),
        .m1_rdata   (m1_rdata),   .m1_rid     (m1_rid),
        .m1_rresp   (m1_rresp),   .m1_rlast   (m1_rlast),
        // Master 2
        .m2_awvalid (m2_awvalid), .m2_awready (m2_awready),
        .m2_awaddr  (m2_awaddr),  .m2_awid    (m2_awid),
        .m2_awlen   (m2_awlen),   .m2_awsize  (m2_awsize),
        .m2_awburst (m2_awburst),
        .m2_wvalid  (m2_wvalid),  .m2_wready  (m2_wready),
        .m2_wdata   (m2_wdata),   .m2_wstrb   (m2_wstrb),
        .m2_wlast   (m2_wlast),
        .m2_bvalid  (m2_bvalid),  .m2_bready  (m2_bready),
        .m2_bid     (m2_bid),     .m2_bresp   (m2_bresp),
        .m2_arvalid (m2_arvalid), .m2_arready (m2_arready),
        .m2_araddr  (m2_araddr),  .m2_arid    (m2_arid),
        .m2_arlen   (m2_arlen),   .m2_arsize  (m2_arsize),
        .m2_arburst (m2_arburst),
        .m2_rvalid  (m2_rvalid),  .m2_rready  (m2_rready),
        .m2_rdata   (m2_rdata),   .m2_rid     (m2_rid),
        .m2_rresp   (m2_rresp),   .m2_rlast   (m2_rlast),
        // Slave 0
        .s0_awvalid (s_awvalid[0]), .s0_awready (s_awready[0]),
        .s0_awaddr  (s_awaddr[0]),  .s0_awid    (s_awid[0]),
        .s0_awlen   (s_awlen[0]),   .s0_awsize  (s_awsize[0]),
        .s0_awburst (s_awburst[0]),
        .s0_wvalid  (s_wvalid[0]),  .s0_wready  (s_wready[0]),
        .s0_wdata   (s_wdata[0]),   .s0_wstrb   (s_wstrb[0]),
        .s0_wlast   (s_wlast[0]),
        .s0_bvalid  (s_bvalid[0]),  .s0_bready  (s_bready[0]),
        .s0_bid     (s_bid[0]),     .s0_bresp   (s_bresp[0]),
        .s0_arvalid (s_arvalid[0]), .s0_arready (s_arready[0]),
        .s0_araddr  (s_araddr[0]),  .s0_arid    (s_arid[0]),
        .s0_arlen   (s_arlen[0]),   .s0_arsize  (s_arsize[0]),
        .s0_arburst (s_arburst[0]),
        .s0_rvalid  (s_rvalid[0]),  .s0_rready  (s_rready[0]),
        .s0_rdata   (s_rdata[0]),   .s0_rid     (s_rid[0]),
        .s0_rresp   (s_rresp[0]),   .s0_rlast   (s_rlast[0]),
        // Slave 1
        .s1_awvalid (s_awvalid[1]), .s1_awready (s_awready[1]),
        .s1_awaddr  (s_awaddr[1]),  .s1_awid    (s_awid[1]),
        .s1_awlen   (s_awlen[1]),   .s1_awsize  (s_awsize[1]),
        .s1_awburst (s_awburst[1]),
        .s1_wvalid  (s_wvalid[1]),  .s1_wready  (s_wready[1]),
        .s1_wdata   (s_wdata[1]),   .s1_wstrb   (s_wstrb[1]),
        .s1_wlast   (s_wlast[1]),
        .s1_bvalid  (s_bvalid[1]),  .s1_bready  (s_bready[1]),
        .s1_bid     (s_bid[1]),     .s1_bresp   (s_bresp[1]),
        .s1_arvalid (s_arvalid[1]), .s1_arready (s_arready[1]),
        .s1_araddr  (s_araddr[1]),  .s1_arid    (s_arid[1]),
        .s1_arlen   (s_arlen[1]),   .s1_arsize  (s_arsize[1]),
        .s1_arburst (s_arburst[1]),
        .s1_rvalid  (s_rvalid[1]),  .s1_rready  (s_rready[1]),
        .s1_rdata   (s_rdata[1]),   .s1_rid     (s_rid[1]),
        .s1_rresp   (s_rresp[1]),   .s1_rlast   (s_rlast[1]),
        // Slave 2
        .s2_awvalid (s_awvalid[2]), .s2_awready (s_awready[2]),
        .s2_awaddr  (s_awaddr[2]),  .s2_awid    (s_awid[2]),
        .s2_awlen   (s_awlen[2]),   .s2_awsize  (s_awsize[2]),
        .s2_awburst (s_awburst[2]),
        .s2_wvalid  (s_wvalid[2]),  .s2_wready  (s_wready[2]),
        .s2_wdata   (s_wdata[2]),   .s2_wstrb   (s_wstrb[2]),
        .s2_wlast   (s_wlast[2]),
        .s2_bvalid  (s_bvalid[2]),  .s2_bready  (s_bready[2]),
        .s2_bid     (s_bid[2]),     .s2_bresp   (s_bresp[2]),
        .s2_arvalid (s_arvalid[2]), .s2_arready (s_arready[2]),
        .s2_araddr  (s_araddr[2]),  .s2_arid    (s_arid[2]),
        .s2_arlen   (s_arlen[2]),   .s2_arsize  (s_arsize[2]),
        .s2_arburst (s_arburst[2]),
        .s2_rvalid  (s_rvalid[2]),  .s2_rready  (s_rready[2]),
        .s2_rdata   (s_rdata[2]),   .s2_rid     (s_rid[2]),
        .s2_rresp   (s_rresp[2]),   .s2_rlast   (s_rlast[2]),
        // Slave 3
        .s3_awvalid (s_awvalid[3]), .s3_awready (s_awready[3]),
        .s3_awaddr  (s_awaddr[3]),  .s3_awid    (s_awid[3]),
        .s3_awlen   (s_awlen[3]),   .s3_awsize  (s_awsize[3]),
        .s3_awburst (s_awburst[3]),
        .s3_wvalid  (s_wvalid[3]),  .s3_wready  (s_wready[3]),
        .s3_wdata   (s_wdata[3]),   .s3_wstrb   (s_wstrb[3]),
        .s3_wlast   (s_wlast[3]),
        .s3_bvalid  (s_bvalid[3]),  .s3_bready  (s_bready[3]),
        .s3_bid     (s_bid[3]),     .s3_bresp   (s_bresp[3]),
        .s3_arvalid (s_arvalid[3]), .s3_arready (s_arready[3]),
        .s3_araddr  (s_araddr[3]),  .s3_arid    (s_arid[3]),
        .s3_arlen   (s_arlen[3]),   .s3_arsize  (s_arsize[3]),
        .s3_arburst (s_arburst[3]),
        .s3_rvalid  (s_rvalid[3]),  .s3_rready  (s_rready[3]),
        .s3_rdata   (s_rdata[3]),   .s3_rid     (s_rid[3]),
        .s3_rresp   (s_rresp[3]),   .s3_rlast   (s_rlast[3]),
        // Slave 4
        .s4_awvalid (s_awvalid[4]), .s4_awready (s_awready[4]),
        .s4_awaddr  (s_awaddr[4]),  .s4_awid    (s_awid[4]),
        .s4_awlen   (s_awlen[4]),   .s4_awsize  (s_awsize[4]),
        .s4_awburst (s_awburst[4]),
        .s4_wvalid  (s_wvalid[4]),  .s4_wready  (s_wready[4]),
        .s4_wdata   (s_wdata[4]),   .s4_wstrb   (s_wstrb[4]),
        .s4_wlast   (s_wlast[4]),
        .s4_bvalid  (s_bvalid[4]),  .s4_bready  (s_bready[4]),
        .s4_bid     (s_bid[4]),     .s4_bresp   (s_bresp[4]),
        .s4_arvalid (s_arvalid[4]), .s4_arready (s_arready[4]),
        .s4_araddr  (s_araddr[4]),  .s4_arid    (s_arid[4]),
        .s4_arlen   (s_arlen[4]),   .s4_arsize  (s_arsize[4]),
        .s4_arburst (s_arburst[4]),
        .s4_rvalid  (s_rvalid[4]),  .s4_rready  (s_rready[4]),
        .s4_rdata   (s_rdata[4]),   .s4_rid     (s_rid[4]),
        .s4_rresp   (s_rresp[4]),   .s4_rlast   (s_rlast[4])
    );

    // =====================================================================
    // Simple AXI slave BFMs — accept writes, return OKAY
    // =====================================================================
    logic [4:0] bfm_aw_flag;

    genvar gi;
    generate
        for (gi = 0; gi < 5; gi = gi + 1) begin : gen_slave_bfm
            // Write response — latch ID on AW handshake, respond after W
            logic [SID_W-1:0] bfm_wid;
            logic             bfm_b_pending;

            always_ff @(posedge clk)
                if (srst) begin
                    bfm_wid      <= '0;
                    bfm_b_pending <= 1'b0;
                end else if (bfm_b_pending && s_bready[gi]) begin
                    bfm_b_pending <= 1'b0;
                end else if (s_wvalid[gi] && s_wready[gi] && s_wlast[gi]) begin
                    bfm_b_pending <= 1'b1;
                end

            always_ff @(posedge clk)
                if (srst)
                    bfm_wid <= '0;
                else if (s_awvalid[gi] && s_awready[gi])
                    bfm_wid <= s_awid[gi];

            // Track AW handshakes for test checking
            always_ff @(posedge clk)
                if (srst)
                    bfm_aw_flag[gi] <= 1'b0;
                else if (s_awvalid[gi] && s_awready[gi])
                    bfm_aw_flag[gi] <= 1'b1;

            // Read — accept AR, return one beat of data
            logic [SID_W-1:0] bfm_rid;
            logic             bfm_r_pending;

            always_ff @(posedge clk)
                if (srst) begin
                    bfm_rid       <= '0;
                    bfm_r_pending <= 1'b0;
                end else if (bfm_r_pending && s_rready[gi]) begin
                    bfm_r_pending <= 1'b0;
                end else if (s_arvalid[gi] && s_arready[gi]) begin
                    bfm_r_pending <= 1'b1;
                    bfm_rid       <= s_arid[gi];
                end

            // All combinational slave outputs in one block
            always @(*) begin
                s_awready[gi] = 1'b1;
                s_wready[gi]  = 1'b1;
                s_bvalid[gi]  = bfm_b_pending;
                s_bid[gi]     = bfm_wid;
                s_bresp[gi]   = 2'b00;
                s_arready[gi] = !bfm_r_pending;
                s_rvalid[gi]  = bfm_r_pending;
                s_rid[gi]     = bfm_rid;
                s_rdata[gi]   = 32'hAAAA_0000 | gi[31:0];
                s_rresp[gi]   = 2'b00;
                s_rlast[gi]   = 1'b1;
            end
        end
    endgenerate

    // =====================================================================
    // Master idle task
    // =====================================================================
    task automatic idle_all_masters;
        m0_awvalid <= 0; m0_wvalid <= 0; m0_bready <= 1;
        m0_arvalid <= 0; m0_rready <= 1;
        m0_awaddr  <= '0; m0_awid <= '0; m0_awlen <= '0;
        m0_awsize  <= 3'b010; m0_awburst <= 2'b01;
        m0_wdata   <= '0; m0_wstrb <= '0; m0_wlast <= 0;
        m0_araddr  <= '0; m0_arid <= '0; m0_arlen <= '0;
        m0_arsize  <= 3'b010; m0_arburst <= 2'b01;

        m1_awvalid <= 0; m1_wvalid <= 0; m1_bready <= 1;
        m1_arvalid <= 0; m1_rready <= 1;
        m1_awaddr  <= '0; m1_awid <= '0; m1_awlen <= '0;
        m1_awsize  <= 3'b010; m1_awburst <= 2'b01;
        m1_wdata   <= '0; m1_wstrb <= '0; m1_wlast <= 0;
        m1_araddr  <= '0; m1_arid <= '0; m1_arlen <= '0;
        m1_arsize  <= 3'b010; m1_arburst <= 2'b01;

        m2_awvalid <= 0; m2_wvalid <= 0; m2_bready <= 1;
        m2_arvalid <= 0; m2_rready <= 1;
        m2_awaddr  <= '0; m2_awid <= '0; m2_awlen <= '0;
        m2_awsize  <= 3'b010; m2_awburst <= 2'b01;
        m2_wdata   <= '0; m2_wstrb <= '0; m2_wlast <= 0;
        m2_araddr  <= '0; m2_arid <= '0; m2_arlen <= '0;
        m2_arsize  <= 3'b010; m2_arburst <= 2'b01;
    endtask

    // =====================================================================
    // Test infrastructure
    // =====================================================================
    integer pass_count, fail_count;

    task automatic check(input string name, input logic cond);
        if (cond) begin
            $display("[PASS] %s", name);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] %s", name);
            fail_count = fail_count + 1;
        end
    endtask

    // =====================================================================
    // Write-and-check task: issue a single-beat write from a given master
    // and verify which slave saw the AW handshake.
    // =====================================================================
    task automatic do_write_m0(
        input logic [ADDR_W-1:0] addr,
        input logic [DATA_W-1:0] data
    );
        @(posedge clk);
        m0_awvalid <= 1; m0_awaddr <= addr; m0_awid <= 4'h1;
        m0_awlen   <= 8'd0; m0_awsize <= 3'b010; m0_awburst <= 2'b01;
        m0_wvalid  <= 1; m0_wdata  <= data; m0_wstrb <= 4'hF; m0_wlast <= 1;
        // Wait for AW handshake
        begin : aw0_wait
            integer t;
            for (t = 0; t < 100; t = t + 1) begin
                @(posedge clk);
                if (m0_awready) begin
                    m0_awvalid <= 0;
                    disable aw0_wait;
                end
            end
        end
        // Wait for W handshake
        begin : w0_wait
            integer t;
            for (t = 0; t < 100; t = t + 1) begin
                @(posedge clk);
                if (m0_wready) begin
                    m0_wvalid <= 0; m0_wlast <= 0;
                    disable w0_wait;
                end
            end
        end
        // Wait for B
        begin : b0_wait
            integer t;
            for (t = 0; t < 100; t = t + 1) begin
                @(posedge clk);
                if (m0_bvalid && m0_bready)
                    disable b0_wait;
            end
        end
    endtask

    task automatic do_write_m1(
        input logic [ADDR_W-1:0] addr,
        input logic [DATA_W-1:0] data
    );
        @(posedge clk);
        m1_awvalid <= 1; m1_awaddr <= addr; m1_awid <= 4'h2;
        m1_awlen   <= 8'd0; m1_awsize <= 3'b010; m1_awburst <= 2'b01;
        m1_wvalid  <= 1; m1_wdata  <= data; m1_wstrb <= 4'hF; m1_wlast <= 1;
        begin : aw1_wait
            integer t;
            for (t = 0; t < 100; t = t + 1) begin
                @(posedge clk);
                if (m1_awready) begin
                    m1_awvalid <= 0;
                    disable aw1_wait;
                end
            end
        end
        begin : w1_wait
            integer t;
            for (t = 0; t < 100; t = t + 1) begin
                @(posedge clk);
                if (m1_wready) begin
                    m1_wvalid <= 0; m1_wlast <= 0;
                    disable w1_wait;
                end
            end
        end
        begin : b1_wait
            integer t;
            for (t = 0; t < 100; t = t + 1) begin
                @(posedge clk);
                if (m1_bvalid && m1_bready)
                    disable b1_wait;
            end
        end
    endtask

    task automatic do_write_m2(
        input logic [ADDR_W-1:0] addr,
        input logic [DATA_W-1:0] data
    );
        @(posedge clk);
        m2_awvalid <= 1; m2_awaddr <= addr; m2_awid <= 4'h3;
        m2_awlen   <= 8'd0; m2_awsize <= 3'b010; m2_awburst <= 2'b01;
        m2_wvalid  <= 1; m2_wdata  <= data; m2_wstrb <= 4'hF; m2_wlast <= 1;
        begin : aw2_wait
            integer t;
            for (t = 0; t < 100; t = t + 1) begin
                @(posedge clk);
                if (m2_awready) begin
                    m2_awvalid <= 0;
                    disable aw2_wait;
                end
            end
        end
        begin : w2_wait
            integer t;
            for (t = 0; t < 100; t = t + 1) begin
                @(posedge clk);
                if (m2_wready) begin
                    m2_wvalid <= 0; m2_wlast <= 0;
                    disable w2_wait;
                end
            end
        end
        begin : b2_wait
            integer t;
            for (t = 0; t < 100; t = t + 1) begin
                @(posedge clk);
                if (m2_bvalid && m2_bready)
                    disable b2_wait;
            end
        end
    endtask

    // Write from master 2 to unmapped address — expect DECERR on B channel
    task automatic do_write_m2_decerr(
        input logic [ADDR_W-1:0] addr,
        output logic [1:0]       got_bresp
    );
        @(posedge clk);
        m2_awvalid <= 1; m2_awaddr <= addr; m2_awid <= 4'h5;
        m2_awlen   <= 8'd0; m2_awsize <= 3'b010; m2_awburst <= 2'b01;
        m2_wvalid  <= 1; m2_wdata  <= 32'hDEAD; m2_wstrb <= 4'hF; m2_wlast <= 1;
        begin : aw_de
            integer t;
            for (t = 0; t < 100; t = t + 1) begin
                @(posedge clk);
                if (m2_awready) begin
                    m2_awvalid <= 0;
                    disable aw_de;
                end
            end
        end
        begin : w_de
            integer t;
            for (t = 0; t < 100; t = t + 1) begin
                @(posedge clk);
                if (m2_wready) begin
                    m2_wvalid <= 0; m2_wlast <= 0;
                    disable w_de;
                end
            end
        end
        begin : b_de
            integer t;
            for (t = 0; t < 200; t = t + 1) begin
                @(posedge clk);
                if (m2_bvalid && m2_bready) begin
                    got_bresp = m2_bresp;
                    disable b_de;
                end
            end
        end
    endtask

    // =====================================================================
    // Main test sequence
    // =====================================================================
    initial begin
        pass_count = 0;
        fail_count = 0;

        idle_all_masters();
        srst = 1;
        repeat (4) @(posedge clk);
        srst = 0;
        repeat (2) @(posedge clk);

        // -----------------------------------------------------------------
        // Test 1: Master 0 write to 0x0000_0000 → Slave 0
        // -----------------------------------------------------------------
        clear_aw_flags();
        do_write_m0(32'h0000_0000, 32'hCAFE_0000);
        repeat (2) @(posedge clk);
        check("M0 write 0x0000_0000 reaches S0", bfm_aw_flag[0] === 1'b1);

        // -----------------------------------------------------------------
        // Test 2: Master 1 write to 0x1000_0000 → Slave 1
        // -----------------------------------------------------------------
        clear_aw_flags();
        do_write_m1(32'h1000_0000, 32'hCAFE_0001);
        repeat (2) @(posedge clk);
        check("M1 write 0x1000_0000 reaches S1", bfm_aw_flag[1] === 1'b1);

        // -----------------------------------------------------------------
        // Test 3: Master 1 write to 0x2000_0000 → Slave 2
        // -----------------------------------------------------------------
        clear_aw_flags();
        do_write_m1(32'h2000_0000, 32'hCAFE_0002);
        repeat (2) @(posedge clk);
        check("M1 write 0x2000_0000 reaches S2", bfm_aw_flag[2] === 1'b1);

        // -----------------------------------------------------------------
        // Test 4: Master 2 write to 0x3000_0000 → Slave 3
        // -----------------------------------------------------------------
        clear_aw_flags();
        do_write_m2(32'h3000_0000, 32'hCAFE_0003);
        repeat (2) @(posedge clk);
        check("M2 write 0x3000_0000 reaches S3", bfm_aw_flag[3] === 1'b1);

        // -----------------------------------------------------------------
        // Test 5: Master 2 write to 0x3000_1000 → Slave 4
        // -----------------------------------------------------------------
        clear_aw_flags();
        do_write_m2(32'h3000_1000, 32'hCAFE_0004);
        repeat (2) @(posedge clk);
        check("M2 write 0x3000_1000 reaches S4", bfm_aw_flag[4] === 1'b1);

        // -----------------------------------------------------------------
        // Test 6: Unmapped address → DECERR
        // -----------------------------------------------------------------
        begin
            logic [1:0] bresp_got;
            do_write_m2_decerr(32'hF000_0000, bresp_got);
            check("Unmapped 0xF000_0000 returns DECERR", bresp_got === 2'b11);
        end

        // -----------------------------------------------------------------
        // Summary
        // -----------------------------------------------------------------
        $display("--------------------------------------------------");
        $display("  Results: %0d passed, %0d failed", pass_count, fail_count);
        $display("--------------------------------------------------");
        tests_done = 1;
        $stop;
    end

    // Watchdog
    logic tests_done = 0;
    initial begin
        #50000;
        if (!tests_done) begin
            $display("[FAIL] Watchdog timeout");
            $stop;
        end
    end

endmodule
