// Brendan Lynskey 2025
// tb_riscv_soc_top — SoC integration testbench
// MIT License
//
// Tests the SoC top-level with cpu_enable=0 (external ports drive M0/M1).
// Verifies:
//   1. Reset synchronisation
//   2. SRAM0 read/write (via direct hierarchical access)
//   3. PLIC, GPIO, UART tie-offs

`timescale 1ns / 1ps

module tb_riscv_soc_top;

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

    assign gpio_in = 32'hDEAD_BEEF;
    assign uart_rx = 1'b1;

    // =========================================================================
    // DUT instantiation
    // =========================================================================
    riscv_soc_top #(
        .INIT_FILE ("")
    ) dut (
        .clk        (clk),
        .ext_rst_n  (ext_rst_n),
        .gpio_in    (gpio_in),
        .gpio_out   (gpio_out),
        .gpio_oe    (gpio_oe),
        .uart_rx    (uart_rx),
        .uart_tx    (uart_tx),
        .cpu_enable (1'b0)
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
    // SRAM direct access tasks (hierarchical reference to SRAM memory array)
    // =========================================================================
    localparam SRAM0_ADDR_LSB = 2; // log2(32/8)

    task sram0_write(input logic [31:0] addr, input logic [31:0] data);
        dut.u_sram0.mem[addr[15:SRAM0_ADDR_LSB]] = data;
    endtask

    task sram0_read(input logic [31:0] addr, output logic [31:0] data);
        data = dut.u_sram0.mem[addr[15:SRAM0_ADDR_LSB]];
    endtask

    // =========================================================================
    // Test sequence
    // =========================================================================
    logic [31:0] rdata;

    initial begin
        $display("=== RISC-V SoC Integration Testbench ===");
        $display("");

        // ---- Reset ----
        ext_rst_n = 1'b0;
        repeat (10) @(posedge clk);

        // Test 1: Reset is asserted
        check("Reset asserted", {31'b0, dut.srst}, 32'h0000_0001);

        ext_rst_n = 1'b1;
        repeat (10) @(posedge clk);

        // Test 2: Reset deasserted
        check("Reset deasserted", {31'b0, dut.srst}, 32'h0000_0000);

        // ---- SRAM0 write/read (direct hierarchical access) ----
        // Test 3: Write to SRAM0 and read back
        sram0_write(32'h0000_0000, 32'hCAFE_BABE);
        sram0_read(32'h0000_0000, rdata);
        check("SRAM0 write/read", rdata, 32'hCAFE_BABE);

        // Test 4: Write to different address
        sram0_write(32'h0000_0004, 32'h1234_5678);
        sram0_read(32'h0000_0004, rdata);
        check("SRAM0 addr 0x04", rdata, 32'h1234_5678);

        // Test 5: Verify first write unchanged
        sram0_read(32'h0000_0000, rdata);
        check("SRAM0 addr 0x00 still valid", rdata, 32'hCAFE_BABE);

        // ---- PLIC ----
        // Test 6: PLIC meip is low (no interrupts enabled)
        check("PLIC meip low", {31'b0, dut.meip}, 32'h0000_0000);

        // ---- GPIO tie-offs ----
        // Test 7: GPIO output is zero (stub)
        check("GPIO out stub", gpio_out, 32'h0000_0000);

        // ---- UART ----
        // Test 8: UART TX idle high
        check("UART TX idle", {31'b0, uart_tx}, 32'h0000_0001);

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
        #100_000;
        $display("[TIMEOUT] Simulation timed out");
        $stop;
    end

endmodule
