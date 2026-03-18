// Brendan Lynskey 2025
// Testbench — DMA + IOMMU Integration (IOMMU bypass mode)
// MIT License

`timescale 1ns / 1ps

module tb_dma_iommu_integration;

    import soc_pkg::*;

    // ---- Clock and reset ----
    logic clk = 0;
    always #5 clk = ~clk;

    logic ext_rst_n;
    logic [31:0] gpio_in;
    logic [31:0] gpio_out, gpio_oe;
    logic uart_rx, uart_tx;
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
        .cpu_d_rlast   (cd_rlast)
    );

    // ---- Shared state ----
    integer pass_count = 0;
    integer fail_count = 0;
    logic   tests_done = 0;

    // ---- AXI4 single-beat write via D-port ----
    task automatic axi_write_d(
        input  [31:0] addr,
        input  [31:0] wdata,
        output [1:0]  resp
    );
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
        cd_wvalid <= 1'b1;
        cd_wdata  <= wdata;
        cd_wstrb  <= 4'hF;
        cd_wlast  <= 1'b1;
        @(posedge clk);
        while (!cd_wready) @(posedge clk);
        cd_wvalid <= 1'b0;
        cd_wlast  <= 1'b0;
        cd_bready <= 1'b1;
        @(posedge clk);
        while (!cd_bvalid) @(posedge clk);
        resp = cd_bresp;
        cd_bready <= 1'b0;
        @(posedge clk);
    endtask

    // ---- AXI4 single-beat read via D-port ----
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

    // ---- DMA register addresses (at SoC base 0x3000_0000) ----
    localparam DMA_BASE     = 32'h3000_0000;
    localparam DMA_CH0_CTRL = DMA_BASE + 12'h000;
    localparam DMA_CH0_SRC  = DMA_BASE + 12'h008;
    localparam DMA_CH0_DST  = DMA_BASE + 12'h00C;
    localparam DMA_CH0_LEN  = DMA_BASE + 12'h010;
    localparam DMA_IRQ_STAT = DMA_BASE + 12'h100;
    localparam DMA_IRQ_EN   = DMA_BASE + 12'h104;
    localparam DMA_VERSION  = DMA_BASE + 12'h10C;

    // ---- IOMMU register addresses (at SoC base 0x3000_1000) ----
    localparam IOMMU_BASE    = 32'h3000_1000;
    localparam IOMMU_CAP     = IOMMU_BASE + 8'h00;
    localparam IOMMU_CTRL    = IOMMU_BASE + 8'h04;

    // ---- Main test sequence ----
    logic [31:0] rdata;
    logic [1:0]  rresp;

    initial begin
        $display("=== DMA + IOMMU Integration Testbench (bypass mode) ===");

        // Reset
        ext_rst_n = 0;
        repeat (10) @(posedge clk);
        ext_rst_n = 1;
        repeat (5) @(posedge clk);

        // ==================================================================
        // Test 1: DMA register write/read via S3
        // ==================================================================
        $display("Test 1: DMA register write/read via S3");
        axi_write_d(DMA_CH0_SRC, 32'hCAFE_0001, rresp);
        if (rresp != 2'b00) begin
            $display("  [FAIL] DMA reg write failed, resp=%b", rresp);
            fail_count = fail_count + 1;
        end else begin
            axi_read_d(DMA_CH0_SRC, rdata, rresp);
            if (rresp == 2'b00 && rdata == 32'hCAFE_0001) begin
                $display("  [PASS] DMA ch0 src_addr = 0x%08h (wrote 0xCAFE0001)", rdata);
                pass_count = pass_count + 1;
            end else begin
                $display("  [FAIL] DMA ch0 src_addr = 0x%08h (exp 0xCAFE0001), resp=%b", rdata, rresp);
                fail_count = fail_count + 1;
            end
        end

        // ==================================================================
        // Test 2: IOMMU register write/read via S4
        // ==================================================================
        $display("Test 2: IOMMU register read/write via S4");
        // Read capability register (read-only, should return 0x0000_0081)
        axi_read_d(IOMMU_CAP, rdata, rresp);
        if (rresp == 2'b00 && rdata == 32'h0000_0081) begin
            $display("  [PASS] IOMMU capability = 0x%08h (matches CAP_VALUE)", rdata);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] IOMMU capability = 0x%08h (exp 0x00000081), resp=%b", rdata, rresp);
            fail_count = fail_count + 1;
        end

        // ==================================================================
        // Test 3: DMA single-word transfer (IOMMU bypass)
        // ==================================================================
        $display("Test 3: DMA single-word transfer through IOMMU (bypass)");
        begin
            logic [1:0] wresp;
            logic [31:0] src_data;
            integer wait_cycles;
            src_data = 32'hA5A5_1234;

            // Write test data to SRAM1 at offset 0x0000 (byte addr 0x1000_0000)
            axi_write_d(32'h1000_0000, src_data, wresp);

            // Clear previous DMA config — write 0 to ch0 ctrl
            axi_write_d(DMA_CH0_CTRL, 32'h0, wresp);

            // Program DMA channel 0
            axi_write_d(DMA_CH0_SRC, 32'h1000_0000, wresp);   // source
            axi_write_d(DMA_CH0_DST, 32'h1000_0100, wresp);   // destination
            axi_write_d(DMA_CH0_LEN, 32'd4, wresp);           // 4 bytes = 1 word
            axi_write_d(DMA_IRQ_EN,  32'h0001, wresp);        // TC enable ch0

            // Start: enable + start (ctrl[0]=enable, ctrl[1]=start, MEM2MEM=00)
            axi_write_d(DMA_CH0_CTRL, 32'h0000_0003, wresp);

            // Wait for DMA completion — poll IRQ status
            wait_cycles = 0;
            rdata = 0;
            while (rdata[0] == 1'b0 && wait_cycles < 500) begin
                repeat (5) @(posedge clk);
                axi_read_d(DMA_IRQ_STAT, rdata, rresp);
                wait_cycles = wait_cycles + 1;
            end

            if (rdata[0] == 1'b1) begin
                // Read destination word
                axi_read_d(32'h1000_0100, rdata, rresp);
                if (rresp == 2'b00 && rdata == src_data) begin
                    $display("  [PASS] DMA transfer OK: dst=0x%08h matches src=0x%08h", rdata, src_data);
                    pass_count = pass_count + 1;
                end else begin
                    $display("  [FAIL] DMA dst=0x%08h (exp 0x%08h), resp=%b", rdata, src_data, rresp);
                    fail_count = fail_count + 1;
                end
            end else begin
                $display("  [FAIL] DMA transfer timeout (IRQ status=0x%08h after %0d polls)", rdata, wait_cycles);
                fail_count = fail_count + 1;
            end
        end

        // ==================================================================
        // Test 4: DMA interrupt assertion
        // ==================================================================
        $display("Test 4: DMA interrupt");
        // IRQ status was read in test 3; check that the DMA irq line fired
        axi_read_d(DMA_IRQ_STAT, rdata, rresp);
        if (rdata[0] == 1'b1) begin
            $display("  [PASS] DMA IRQ status bit 0 (TC ch0) is set");
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] DMA IRQ status = 0x%08h (expected bit 0 set)", rdata);
            fail_count = fail_count + 1;
        end

        // ==================================================================
        // Test 5: Address passthrough (IOMMU bypass verified by transfer)
        // ==================================================================
        $display("Test 5: IOMMU address passthrough");
        // The successful DMA transfer in test 3 proves that addresses
        // passed through the IOMMU untranslated. Double-check by reading
        // the destination via the CPU path (M1) and verifying data integrity.
        axi_read_d(32'h1000_0100, rdata, rresp);
        if (rresp == 2'b00 && rdata == 32'hA5A5_1234) begin
            $display("  [PASS] Passthrough verified: CPU reads DMA-written data = 0x%08h", rdata);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] Passthrough check: data=0x%08h (exp 0xA5A51234), resp=%b", rdata, rresp);
            fail_count = fail_count + 1;
        end

        // ==================================================================
        // Summary
        // ==================================================================
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
        #200000;
        if (!tests_done) begin
            $display("[FAIL] Simulation timeout");
            $stop;
        end
    end

endmodule
