// Brendan Lynskey 2025
// Testbench — MMU Integration (bypass mode)
// MIT License

`timescale 1ns / 1ps

module tb_mmu_integration;

    import soc_pkg::*;

    // ---- Clock and reset ----
    logic clk = 0;
    always #5 clk = ~clk;

    logic ext_rst_n;
    logic [31:0] gpio_in;
    logic [31:0] gpio_out, gpio_oe;
    logic uart_rx, uart_tx;

    // SATP — 0 means bypass mode
    logic [31:0] satp;

    // CPU I-port AXI4
    logic              ci_awvalid, ci_awready;
    logic [ADDR_W-1:0] ci_awaddr;
    logic [ID_W-1:0]   ci_awid;
    logic [7:0]        ci_awlen;
    logic [2:0]        ci_awsize;
    logic [1:0]        ci_awburst;
    logic              ci_wvalid, ci_wready;
    logic [DATA_W-1:0] ci_wdata;
    logic [STRB_W-1:0] ci_wstrb;
    logic              ci_wlast;
    logic              ci_bvalid, ci_bready;
    logic [ID_W-1:0]   ci_bid;
    logic [1:0]        ci_bresp;
    logic              ci_arvalid, ci_arready;
    logic [ADDR_W-1:0] ci_araddr;
    logic [ID_W-1:0]   ci_arid;
    logic [7:0]        ci_arlen;
    logic [2:0]        ci_arsize;
    logic [1:0]        ci_arburst;
    logic              ci_rvalid, ci_rready;
    logic [DATA_W-1:0] ci_rdata;
    logic [ID_W-1:0]   ci_rid;
    logic [1:0]        ci_rresp;
    logic              ci_rlast;

    // CPU D-port AXI4
    logic              cd_awvalid, cd_awready;
    logic [ADDR_W-1:0] cd_awaddr;
    logic [ID_W-1:0]   cd_awid;
    logic [7:0]        cd_awlen;
    logic [2:0]        cd_awsize;
    logic [1:0]        cd_awburst;
    logic              cd_wvalid, cd_wready;
    logic [DATA_W-1:0] cd_wdata;
    logic [STRB_W-1:0] cd_wstrb;
    logic              cd_wlast;
    logic              cd_bvalid, cd_bready;
    logic [ID_W-1:0]   cd_bid;
    logic [1:0]        cd_bresp;
    logic              cd_arvalid, cd_arready;
    logic [ADDR_W-1:0] cd_araddr;
    logic [ID_W-1:0]   cd_arid;
    logic [7:0]        cd_arlen;
    logic [2:0]        cd_arsize;
    logic [1:0]        cd_arburst;
    logic              cd_rvalid, cd_rready;
    logic [DATA_W-1:0] cd_rdata;
    logic [ID_W-1:0]   cd_rid;
    logic [1:0]        cd_rresp;
    logic              cd_rlast;

    // ---- DUT ----
    riscv_soc_top #(.INIT_FILE("")) u_dut (
        .clk         (clk),
        .ext_rst_n   (ext_rst_n),
        .gpio_in     (gpio_in),
        .gpio_out    (gpio_out),
        .gpio_oe     (gpio_oe),
        .uart_rx     (uart_rx),
        .uart_tx     (uart_tx),
        .satp        (satp),
        // I-port
        .cpu_i_awvalid (ci_awvalid),
        .cpu_i_awready (ci_awready),
        .cpu_i_awaddr  (ci_awaddr),
        .cpu_i_awid    (ci_awid),
        .cpu_i_awlen   (ci_awlen),
        .cpu_i_awsize  (ci_awsize),
        .cpu_i_awburst (ci_awburst),
        .cpu_i_wvalid  (ci_wvalid),
        .cpu_i_wready  (ci_wready),
        .cpu_i_wdata   (ci_wdata),
        .cpu_i_wstrb   (ci_wstrb),
        .cpu_i_wlast   (ci_wlast),
        .cpu_i_bvalid  (ci_bvalid),
        .cpu_i_bready  (ci_bready),
        .cpu_i_bid     (ci_bid),
        .cpu_i_bresp   (ci_bresp),
        .cpu_i_arvalid (ci_arvalid),
        .cpu_i_arready (ci_arready),
        .cpu_i_araddr  (ci_araddr),
        .cpu_i_arid    (ci_arid),
        .cpu_i_arlen   (ci_arlen),
        .cpu_i_arsize  (ci_arsize),
        .cpu_i_arburst (ci_arburst),
        .cpu_i_rvalid  (ci_rvalid),
        .cpu_i_rready  (ci_rready),
        .cpu_i_rdata   (ci_rdata),
        .cpu_i_rid     (ci_rid),
        .cpu_i_rresp   (ci_rresp),
        .cpu_i_rlast   (ci_rlast),
        // D-port
        .cpu_d_awvalid (cd_awvalid),
        .cpu_d_awready (cd_awready),
        .cpu_d_awaddr  (cd_awaddr),
        .cpu_d_awid    (cd_awid),
        .cpu_d_awlen   (cd_awlen),
        .cpu_d_awsize  (cd_awsize),
        .cpu_d_awburst (cd_awburst),
        .cpu_d_wvalid  (cd_wvalid),
        .cpu_d_wready  (cd_wready),
        .cpu_d_wdata   (cd_wdata),
        .cpu_d_wstrb   (cd_wstrb),
        .cpu_d_wlast   (cd_wlast),
        .cpu_d_bvalid  (cd_bvalid),
        .cpu_d_bready  (cd_bready),
        .cpu_d_bid     (cd_bid),
        .cpu_d_bresp   (cd_bresp),
        .cpu_d_arvalid (cd_arvalid),
        .cpu_d_arready (cd_arready),
        .cpu_d_araddr  (cd_araddr),
        .cpu_d_arid    (cd_arid),
        .cpu_d_arlen   (cd_arlen),
        .cpu_d_arsize  (cd_arsize),
        .cpu_d_arburst (cd_arburst),
        .cpu_d_rvalid  (cd_rvalid),
        .cpu_d_rready  (cd_rready),
        .cpu_d_rdata   (cd_rdata),
        .cpu_d_rid     (cd_rid),
        .cpu_d_rresp   (cd_rresp),
        .cpu_d_rlast   (cd_rlast),
        .cpu_enable    (1'b0)
    );

    // ---- Shared state ----
    integer pass_count = 0;
    integer fail_count = 0;
    logic   tests_done = 0;

    // ---- Helper tasks ----

    // AXI4 single-beat read via I-port
    task automatic axi_read_i(
        input  [31:0] addr,
        output [31:0] data,
        output [1:0]  resp
    );
        // AR phase
        @(posedge clk);
        ci_arvalid <= 1'b1;
        ci_araddr  <= addr;
        ci_arid    <= 4'd0;
        ci_arlen   <= 8'd0;
        ci_arsize  <= 3'b010;
        ci_arburst <= 2'b01;
        @(posedge clk);
        while (!ci_arready) @(posedge clk);
        ci_arvalid <= 1'b0;
        // R phase
        ci_rready <= 1'b1;
        @(posedge clk);
        while (!ci_rvalid) @(posedge clk);
        data = ci_rdata;
        resp = ci_rresp;
        ci_rready <= 1'b0;
        @(posedge clk);
    endtask

    // AXI4 single-beat read via D-port
    task automatic axi_read_d(
        input  [31:0] addr,
        output [31:0] data,
        output [1:0]  resp
    );
        @(posedge clk);
        cd_arvalid <= 1'b1;
        cd_araddr  <= addr;
        cd_arid    <= 4'd1;
        cd_arlen   <= 8'd0;
        cd_arsize  <= 3'b010;
        cd_arburst <= 2'b01;
        @(posedge clk);
        while (!cd_arready) @(posedge clk);
        cd_arvalid <= 1'b0;
        cd_rready <= 1'b1;
        @(posedge clk);
        while (!cd_rvalid) @(posedge clk);
        data = cd_rdata;
        resp = cd_rresp;
        cd_rready <= 1'b0;
        @(posedge clk);
    endtask

    // AXI4 single-beat write via D-port
    task automatic axi_write_d(
        input  [31:0] addr,
        input  [31:0] wdata,
        output [1:0]  resp
    );
        // AW phase
        @(posedge clk);
        cd_awvalid <= 1'b1;
        cd_awaddr  <= addr;
        cd_awid    <= 4'd1;
        cd_awlen   <= 8'd0;
        cd_awsize  <= 3'b010;
        cd_awburst <= 2'b01;
        @(posedge clk);
        while (!cd_awready) @(posedge clk);
        cd_awvalid <= 1'b0;
        // W phase
        cd_wvalid <= 1'b1;
        cd_wdata  <= wdata;
        cd_wstrb  <= 4'hF;
        cd_wlast  <= 1'b1;
        @(posedge clk);
        while (!cd_wready) @(posedge clk);
        cd_wvalid <= 1'b0;
        cd_wlast  <= 1'b0;
        // B phase
        cd_bready <= 1'b1;
        @(posedge clk);
        while (!cd_bvalid) @(posedge clk);
        resp = cd_bresp;
        cd_bready <= 1'b0;
        @(posedge clk);
    endtask

    // ---- Initialise signals ----
    initial begin
        ext_rst_n  = 0;
        gpio_in    = '0;
        uart_rx    = 1'b1;
        satp       = 32'd0;  // bypass mode

        ci_awvalid = 0; ci_awaddr = 0; ci_awid = 0; ci_awlen = 0;
        ci_awsize  = 0; ci_awburst = 0;
        ci_wvalid  = 0; ci_wdata = 0; ci_wstrb = 0; ci_wlast = 0;
        ci_bready  = 0;
        ci_arvalid = 0; ci_araddr = 0; ci_arid = 0; ci_arlen = 0;
        ci_arsize  = 0; ci_arburst = 0;
        ci_rready  = 0;

        cd_awvalid = 0; cd_awaddr = 0; cd_awid = 0; cd_awlen = 0;
        cd_awsize  = 0; cd_awburst = 0;
        cd_wvalid  = 0; cd_wdata = 0; cd_wstrb = 0; cd_wlast = 0;
        cd_bready  = 0;
        cd_arvalid = 0; cd_araddr = 0; cd_arid = 0; cd_arlen = 0;
        cd_arsize  = 0; cd_arburst = 0;
        cd_rready  = 0;
    end

    // ---- Main test sequence ----
    logic [31:0] rdata;
    logic [1:0]  rresp;
    logic [31:0] rdata_i, rdata_d;
    logic [1:0]  rresp_i, rresp_d;

    initial begin
        $display("=== MMU Integration Testbench (bypass mode) ===");

        // Reset
        ext_rst_n = 0;
        repeat (10) @(posedge clk);
        ext_rst_n = 1;
        repeat (5) @(posedge clk);

        // ------------------------------------------------------------------
        // Test 1: Bypass mode read — M0 → SRAM0
        // ------------------------------------------------------------------
        $display("Test 1: Bypass mode read via M0 (SRAM0)");
        axi_read_i(32'h0000_0010, rdata, rresp);
        if (rresp == 2'b00) begin
            $display("  [PASS] Read from SRAM0 @ 0x0000_0010 OK, data=0x%08h, resp=OKAY", rdata);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] Read from SRAM0 @ 0x0000_0010 failed, resp=%b", rresp);
            fail_count = fail_count + 1;
        end

        // ------------------------------------------------------------------
        // Test 2: Bypass mode write + readback — M1 → SRAM1
        // ------------------------------------------------------------------
        $display("Test 2: Bypass mode write via M1 (SRAM1)");
        axi_write_d(32'h1000_0020, 32'hDEAD_BEEF, rresp);
        if (rresp == 2'b00) begin
            $display("  Write 0xDEADBEEF to SRAM1 @ 0x1000_0020 OK");
        end else begin
            $display("  [FAIL] Write to SRAM1 failed, resp=%b", rresp);
            fail_count = fail_count + 1;
        end
        // Read back
        axi_read_d(32'h1000_0020, rdata, rresp);
        if (rresp == 2'b00 && rdata == 32'hDEAD_BEEF) begin
            $display("  [PASS] Readback 0x%08h matches written data", rdata);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] Readback data=0x%08h (exp 0xDEADBEEF), resp=%b", rdata, rresp);
            fail_count = fail_count + 1;
        end

        // ------------------------------------------------------------------
        // Test 3: Bypass mode peripheral read — M1 → Slave 2
        // ------------------------------------------------------------------
        $display("Test 3: Bypass mode peripheral read via M1");
        axi_read_d(32'h2000_0000, rdata, rresp);
        if (rresp == 2'b00) begin
            $display("  [PASS] Read from peripheral @ 0x2000_0000 OK, data=0x%08h, resp=OKAY", rdata);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] Peripheral read failed, resp=%b", rresp);
            fail_count = fail_count + 1;
        end

        // ------------------------------------------------------------------
        // Test 4: Both ports concurrent — M0 read + M1 read
        // ------------------------------------------------------------------
        $display("Test 4: Concurrent reads on M0 and M1");
        fork
            axi_read_i(32'h0000_0000, rdata_i, rresp_i);
            axi_read_d(32'h1000_0020, rdata_d, rresp_d);
        join
        if (rresp_i == 2'b00 && rresp_d == 2'b00 && rdata_d == 32'hDEAD_BEEF) begin
            $display("  [PASS] M0 data=0x%08h resp=OKAY, M1 data=0x%08h resp=OKAY", rdata_i, rdata_d);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] M0 resp=%b data=0x%08h, M1 resp=%b data=0x%08h",
                     rresp_i, rdata_i, rresp_d, rdata_d);
            fail_count = fail_count + 1;
        end

        // ------------------------------------------------------------------
        // Test 5: Address passthrough — verify paddr == vaddr in bypass
        // ------------------------------------------------------------------
        $display("Test 5: Address passthrough (paddr == vaddr in bypass)");
        // Write a marker value to SRAM0 @ word address 0x100 (byte addr 0x400)
        // Use I-port adapter for write (goes through MMU bridge → crossbar M0)
        // Actually, let's use the D-port to write to SRAM0 (SRAM0 starts at 0x0000_0000)
        axi_write_d(32'h0000_0400, 32'hCAFE_BABE, rresp);
        // Read it back via I-port to confirm address passthrough
        axi_read_i(32'h0000_0400, rdata, rresp);
        if (rresp == 2'b00 && rdata == 32'hCAFE_BABE) begin
            $display("  [PASS] paddr passthrough verified: wrote via M1, read via M0 @ 0x0000_0400 = 0x%08h", rdata);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] paddr mismatch: data=0x%08h (exp 0xCAFEBABE), resp=%b", rdata, rresp);
            fail_count = fail_count + 1;
        end

        // ------------------------------------------------------------------
        // Summary
        // ------------------------------------------------------------------
        $display("=== Results: %0d PASSED, %0d FAILED ===", pass_count, fail_count);
        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");
        tests_done = 1;
        $stop;
    end

    // ---- Timeout watchdog ----
    initial begin
        #50000;
        if (!tests_done) begin
            $display("[FAIL] Simulation timeout");
            $stop;
        end
    end

endmodule
