// Brendan Lynskey 2025
// Testbench — Peripheral Integration (GPIO, UART, Timer, PLIC)
// MIT License

`timescale 1ns / 1ps

module tb_periph_integration;

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
        .cpu_d_rlast   (cd_rlast),
        .cpu_enable    (1'b0)
    );

    // ---- Shared state ----
    integer pass_count = 0;
    integer fail_count = 0;

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
        satp       = 32'd0;

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

    // ---- Peripheral addresses ----
    // GPIO registers (base 0x2000_0000): data=0x00, input=0x04, dir=0x08, irq_en=0x0C, irq_stat=0x10
    localparam GPIO_DATA    = 32'h2000_0000;
    localparam GPIO_INPUT   = 32'h2000_0004;
    localparam GPIO_DIR     = 32'h2000_0008;
    localparam GPIO_IRQ_EN  = 32'h2000_000C;
    localparam GPIO_IRQ_ST  = 32'h2000_0010;

    // UART registers (base 0x2000_1000): tx_data=0x00, rx_data=0x04, status=0x08, clk_div=0x0C
    localparam UART_TX_DATA = 32'h2000_1000;
    localparam UART_RX_DATA = 32'h2000_1004;
    localparam UART_STATUS  = 32'h2000_1008;
    localparam UART_CLK_DIV = 32'h2000_100C;

    // Timer registers (base 0x2000_2000): ctrl=0x00, prescaler=0x04, compare=0x08, count=0x0C, match=0x10
    localparam TIMER_CTRL    = 32'h2000_2000;
    localparam TIMER_PRESCAL = 32'h2000_2004;
    localparam TIMER_COMPARE = 32'h2000_2008;
    localparam TIMER_COUNT   = 32'h2000_200C;
    localparam TIMER_MATCH   = 32'h2000_2010;

    // PLIC registers (base 0x2000_3000): pending=0x00, enable=0x04, threshold=0x08, claim=0x0C
    localparam PLIC_PENDING  = 32'h2000_3000;
    localparam PLIC_ENABLE   = 32'h2000_3004;
    localparam PLIC_THRESH   = 32'h2000_3008;
    localparam PLIC_CLAIM    = 32'h2000_300C;

    // ---- Main test sequence ----
    logic [31:0] rdata;
    logic [1:0]  rresp;

    initial begin
        $display("=== Peripheral Integration Testbench ===");

        // Reset
        ext_rst_n = 0;
        repeat (10) @(posedge clk);
        ext_rst_n = 1;
        repeat (5) @(posedge clk);

        // ==================================================================
        // Test 1: GPIO write/read — data register
        // ==================================================================
        $display("Test 1: GPIO write/read (data register)");
        axi_write_d(GPIO_DATA, 32'hA5A5_A5A5, rresp);
        if (rresp != 2'b00) begin
            $display("  [FAIL] GPIO data write failed, resp=%b", rresp);
            fail_count = fail_count + 1;
        end else begin
            axi_read_d(GPIO_DATA, rdata, rresp);
            if (rresp == 2'b00 && rdata == 32'hA5A5_A5A5) begin
                $display("  [PASS] GPIO data = 0x%08h", rdata);
                pass_count = pass_count + 1;
            end else begin
                $display("  [FAIL] GPIO data = 0x%08h (exp 0xA5A5A5A5), resp=%b", rdata, rresp);
                fail_count = fail_count + 1;
            end
        end

        // ==================================================================
        // Test 2: GPIO output — set direction, write data, check pin
        // ==================================================================
        $display("Test 2: GPIO output on external pins");
        axi_write_d(GPIO_DIR, 32'hFFFF_FFFF, rresp);  // all outputs
        axi_write_d(GPIO_DATA, 32'hDEAD_BEEF, rresp);
        repeat (3) @(posedge clk);  // let combinational settle
        if (gpio_out == 32'hDEAD_BEEF && gpio_oe == 32'hFFFF_FFFF) begin
            $display("  [PASS] gpio_out=0x%08h gpio_oe=0x%08h", gpio_out, gpio_oe);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] gpio_out=0x%08h (exp 0xDEADBEEF), gpio_oe=0x%08h (exp 0xFFFFFFFF)",
                     gpio_out, gpio_oe);
            fail_count = fail_count + 1;
        end

        // ==================================================================
        // Test 3: Timer write/read — compare register
        // ==================================================================
        $display("Test 3: Timer write/read (compare register)");
        axi_write_d(TIMER_COMPARE, 32'h0000_0064, rresp);
        if (rresp != 2'b00) begin
            $display("  [FAIL] Timer compare write failed, resp=%b", rresp);
            fail_count = fail_count + 1;
        end else begin
            axi_read_d(TIMER_COMPARE, rdata, rresp);
            if (rresp == 2'b00 && rdata == 32'h0000_0064) begin
                $display("  [PASS] Timer compare = 0x%08h", rdata);
                pass_count = pass_count + 1;
            end else begin
                $display("  [FAIL] Timer compare = 0x%08h (exp 0x00000064), resp=%b", rdata, rresp);
                fail_count = fail_count + 1;
            end
        end

        // ==================================================================
        // Test 4: Timer interrupt + PLIC meip
        // ==================================================================
        $display("Test 4: Timer interrupt through PLIC");
        // Configure PLIC: enable timer IRQ (bit 0), threshold=0
        axi_write_d(PLIC_ENABLE, 32'h0000_0001, rresp);  // enable IRQ 0 (timer)
        axi_write_d(PLIC_THRESH, 32'h0000_0000, rresp);   // threshold 0
        // Timer: prescaler=0, compare=2, auto-reload off, enable
        axi_write_d(TIMER_PRESCAL, 32'h0000_0000, rresp);
        axi_write_d(TIMER_COMPARE, 32'h0000_0002, rresp);
        axi_write_d(TIMER_CTRL, 32'h0000_0001, rresp);    // enable, no auto-reload
        // Wait for timer to count to compare value
        repeat (20) @(posedge clk);
        // Check PLIC pending
        axi_read_d(PLIC_PENDING, rdata, rresp);
        if (rdata[0] == 1'b1) begin
            $display("  [PASS] Timer IRQ pending in PLIC (pending=0x%08h)", rdata);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] Timer IRQ not pending (pending=0x%08h)", rdata);
            fail_count = fail_count + 1;
        end
        // Clear timer match flag for subsequent tests
        axi_write_d(TIMER_MATCH, 32'h0000_0001, rresp);
        axi_write_d(TIMER_CTRL, 32'h0000_0000, rresp);  // disable timer

        // ==================================================================
        // Test 5: UART status read
        // ==================================================================
        $display("Test 5: UART status register read");
        axi_read_d(UART_STATUS, rdata, rresp);
        if (rresp == 2'b00) begin
            // tx_busy=bit0 should be 0 (idle), rx_valid=bit1 should be 0
            if (rdata[0] == 1'b0) begin
                $display("  [PASS] UART status = 0x%08h (TX not busy)", rdata);
                pass_count = pass_count + 1;
            end else begin
                $display("  [FAIL] UART status = 0x%08h (TX busy unexpectedly)", rdata);
                fail_count = fail_count + 1;
            end
        end else begin
            $display("  [FAIL] UART status read failed, resp=%b", rresp);
            fail_count = fail_count + 1;
        end

        // ==================================================================
        // Test 6: PLIC register access
        // ==================================================================
        $display("Test 6: PLIC enable register write/read");
        axi_write_d(PLIC_ENABLE, 32'h0000_00FF, rresp);
        if (rresp != 2'b00) begin
            $display("  [FAIL] PLIC enable write failed, resp=%b", rresp);
            fail_count = fail_count + 1;
        end else begin
            axi_read_d(PLIC_ENABLE, rdata, rresp);
            if (rresp == 2'b00 && rdata == 32'h0000_00FF) begin
                $display("  [PASS] PLIC enable = 0x%08h", rdata);
                pass_count = pass_count + 1;
            end else begin
                $display("  [FAIL] PLIC enable = 0x%08h (exp 0x000000FF), resp=%b", rdata, rresp);
                fail_count = fail_count + 1;
            end
        end

        // ==================================================================
        // Test 7: Address decode isolation — GPIO vs UART
        // ==================================================================
        $display("Test 7: Address decode isolation (GPIO vs UART)");
        // Write known value to GPIO data
        axi_write_d(GPIO_DATA, 32'h1234_5678, rresp);
        // Write known value to UART clk_div
        axi_write_d(UART_CLK_DIV, 32'h0000_0042, rresp);
        // Read back GPIO — should be 0x12345678, not contaminated
        axi_read_d(GPIO_DATA, rdata, rresp);
        if (rdata == 32'h1234_5678) begin
            // Read UART clk_div — should be 0x42
            axi_read_d(UART_CLK_DIV, rdata, rresp);
            if (rdata == 32'h0000_0042) begin
                $display("  [PASS] No cross-contamination between GPIO and UART");
                pass_count = pass_count + 1;
            end else begin
                $display("  [FAIL] UART clk_div = 0x%08h (exp 0x00000042)", rdata);
                fail_count = fail_count + 1;
            end
        end else begin
            $display("  [FAIL] GPIO data = 0x%08h (exp 0x12345678)", rdata);
            fail_count = fail_count + 1;
        end

        // ==================================================================
        // Summary
        // ==================================================================
        $display("");
        $display("=== Results: %0d passed, %0d failed ===", pass_count, fail_count);
        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");

        $stop;
    end

    // ---- Timeout watchdog ----
    initial begin
        #200000;
        $display("[TIMEOUT] Simulation exceeded 200us");
        $stop;
    end

endmodule
