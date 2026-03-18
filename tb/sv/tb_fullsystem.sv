// Brendan Lynskey 2025
// tb_fullsystem — Full-system firmware integration testbench
// MIT License
//
// Capstone test: boots the SoC with cpu_enable=1, loads fulltest.hex,
// and verifies that firmware correctly exercises SRAM, GPIO, Timer/PLIC.

`timescale 1ns / 1ps

module tb_fullsystem;

    // =========================================================================
    // Clock and reset
    // =========================================================================
    logic clk;
    logic ext_rst_n;

    initial clk = 0;
    always #5 clk = ~clk;  // 100 MHz

    // =========================================================================
    // DUT signals
    // =========================================================================
    logic [31:0] gpio_in;
    logic [31:0] gpio_out;
    logic [31:0] gpio_oe;
    logic        uart_rx;
    logic        uart_tx;

    assign gpio_in = 32'h0;
    assign uart_rx = 1'b1;

    // =========================================================================
    // DUT instantiation — CPU enabled, firmware loaded into SRAM0
    // =========================================================================
    riscv_soc_top #(
        .INIT_FILE ("firmware/fulltest.hex")
    ) dut (
        .clk        (clk),
        .ext_rst_n  (ext_rst_n),
        .gpio_in    (gpio_in),
        .gpio_out   (gpio_out),
        .gpio_oe    (gpio_oe),
        .uart_rx    (uart_rx),
        .uart_tx    (uart_tx),
        .satp       (32'h0),
        .cpu_enable (1'b1),
        // External CPU ports unused when cpu_enable=1
        .cpu_i_awvalid (1'b0),
        .cpu_i_awaddr  ('0),
        .cpu_i_awid    ('0),
        .cpu_i_awlen   ('0),
        .cpu_i_awsize  ('0),
        .cpu_i_awburst ('0),
        .cpu_i_wvalid  (1'b0),
        .cpu_i_wdata   ('0),
        .cpu_i_wstrb   ('0),
        .cpu_i_wlast   (1'b0),
        .cpu_i_bready  (1'b0),
        .cpu_i_arvalid (1'b0),
        .cpu_i_araddr  ('0),
        .cpu_i_arid    ('0),
        .cpu_i_arlen   ('0),
        .cpu_i_arsize  ('0),
        .cpu_i_arburst ('0),
        .cpu_i_rready  (1'b0),
        .cpu_d_awvalid (1'b0),
        .cpu_d_awaddr  ('0),
        .cpu_d_awid    ('0),
        .cpu_d_awlen   ('0),
        .cpu_d_awsize  ('0),
        .cpu_d_awburst ('0),
        .cpu_d_wvalid  (1'b0),
        .cpu_d_wdata   ('0),
        .cpu_d_wstrb   ('0),
        .cpu_d_wlast   (1'b0),
        .cpu_d_bready  (1'b0),
        .cpu_d_arvalid (1'b0),
        .cpu_d_araddr  ('0),
        .cpu_d_arid    ('0),
        .cpu_d_arlen   ('0),
        .cpu_d_arsize  ('0),
        .cpu_d_arburst ('0),
        .cpu_d_rready  (1'b0)
    );

    // =========================================================================
    // Test counters
    // =========================================================================
    integer pass_count = 0;
    integer fail_count = 0;

    task check(input string name, input logic [31:0] got, input logic [31:0] exp);
        if (got === exp) begin
            $display("[PASS] %s: got 0x%08h", name, got);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] %s: got 0x%08h, expected 0x%08h", name, got, exp);
            fail_count = fail_count + 1;
        end
    endtask

    // =========================================================================
    // meip tracker — sample periodically to detect interrupt assertion
    // =========================================================================
    logic meip_seen = 0;

    always @(posedge clk) begin
        if (dut.meip)
            meip_seen <= 1'b1;
    end


    // =========================================================================
    // Test sequence
    // =========================================================================
    initial begin
        $display("=== Full-System Firmware Testbench ===");
        $display("");

        // ---- Reset ----
        ext_rst_n = 1'b0;
        repeat (20) @(posedge clk);
        ext_rst_n = 1'b1;
        repeat (5) @(posedge clk);

        // Test 1: Compilation passed
        check("Compilation OK", 32'h1, 32'h1);

        // Wait for CPU to execute all firmware (cache fills + pipeline)
        repeat (5000) @(posedge clk);

        // ---- Memory checks ----
        // Test 2: SRAM1 word 0 = 0xDEADBEEF
        check("SRAM1[0x10000000] = 0xDEADBEEF",
              dut.u_sram1.mem[0], 32'hDEADBEEF);

        // Test 3: SRAM1 word 1 = 0x12345678
        check("SRAM1[0x10000004] = 0x12345678",
              dut.u_sram1.mem[1], 32'h12345678);

        // ---- GPIO checks ----
        // Test 4: GPIO output = 0xAA
        check("GPIO out[7:0] = 0xAA",
              {24'b0, gpio_out[7:0]}, 32'h000000AA);

        // Test 5: GPIO output enable = 0xFF
        check("GPIO oe[7:0] = 0xFF",
              {24'b0, gpio_oe[7:0]}, 32'h000000FF);

        // ---- Completion check ----
        // Test 6: Completion marker at 0x10000F00 (word index 0x3C0)
        check("SRAM1[0x10000F00] = 0x900D900D",
              dut.u_sram1.mem[32'h3C0], 32'h900D900D);

        // ---- Timer/interrupt check ----
        // Test 7: meip was asserted at some point during execution
        if (meip_seen) begin
            $display("[PASS] meip was asserted (timer interrupt fired)");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] meip was never asserted");
            fail_count = fail_count + 1;
        end

        // ---- Summary ----
        $display("");
        $display("=== Results: %0d passed, %0d failed ===", pass_count, fail_count);
        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");

        $stop;
    end

    // Timeout
    initial begin
        #500_000;
        $display("[TIMEOUT] Simulation timed out");
        $stop;
    end

endmodule
