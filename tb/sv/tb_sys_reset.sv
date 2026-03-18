// Brendan Lynskey 2025
// tb_sys_reset — Reset controller testbench
// MIT License

`timescale 1ns / 1ps

module tb_sys_reset;

    logic clk, ext_rst_n, srst;
    initial clk = 0;
    always #5 clk = ~clk;

    sys_reset dut (.clk(clk), .ext_rst_n(ext_rst_n), .srst(srst));

    integer pass_count = 0, fail_count = 0;

    task check(input string name, input logic got, input logic exp);
        if (got === exp) begin
            $display("[PASS] %s", name);
            pass_count++;
        end else begin
            $display("[FAIL] %s: got %b exp %b", name, got, exp);
            fail_count++;
        end
    endtask

    initial begin
        $display("=== tb_sys_reset ===");

        // Test 1: Assert reset
        ext_rst_n = 0;
        repeat(5) @(posedge clk);
        check("Reset asserted", srst, 1'b1);

        // Test 2: Deassert — srst should stay high for sync stages
        ext_rst_n = 1;
        @(posedge clk);
        check("Still in reset cycle 1", srst, 1'b1);

        // Test 3: After enough cycles, deasserts
        repeat(5) @(posedge clk);
        check("Reset deasserted", srst, 1'b0);

        // Test 4: Re-assert
        ext_rst_n = 0;
        @(posedge clk); @(posedge clk);
        check("Re-assert", srst, 1'b1);

        // Test 5: Release again
        ext_rst_n = 1;
        repeat(5) @(posedge clk);
        check("Re-release", srst, 1'b0);

        $display("");
        $display("Results: %0d passed, %0d failed", pass_count, fail_count);
        $stop;
    end

    initial begin #10_000; $display("[TIMEOUT]"); $stop; end

endmodule
