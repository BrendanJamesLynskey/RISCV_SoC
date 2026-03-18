// Brendan Lynskey 2025
// tb_plic — PLIC unit testbench
// MIT License

`timescale 1ns / 1ps

module tb_plic;

    parameter N_SOURCES = 8;

    logic clk, srst;
    initial clk = 0;
    always #5 clk = ~clk;

    logic [N_SOURCES-1:0] irq_sources;
    logic                  meip;
    logic                  reg_wr_en, reg_rd_en;
    logic [31:0]           reg_addr, reg_wdata, reg_rdata;

    plic #(.N_SOURCES(N_SOURCES)) dut (
        .clk(clk), .srst(srst),
        .irq_sources(irq_sources), .meip(meip),
        .reg_wr_en(reg_wr_en), .reg_rd_en(reg_rd_en),
        .reg_addr(reg_addr), .reg_wdata(reg_wdata), .reg_rdata(reg_rdata)
    );

    integer pass_count = 0, fail_count = 0;

    task check(input string name, input logic [31:0] got, input logic [31:0] exp);
        if (got === exp) begin
            $display("[PASS] %s: 0x%08h", name, got);
            pass_count++;
        end else begin
            $display("[FAIL] %s: got 0x%08h exp 0x%08h", name, got, exp);
            fail_count++;
        end
    endtask

    task reg_write(input logic [31:0] addr, input logic [31:0] data);
        @(posedge clk);
        reg_wr_en = 1; reg_addr = addr; reg_wdata = data;
        @(posedge clk);
        reg_wr_en = 0;
    endtask

    task reg_read(input logic [31:0] addr, output logic [31:0] data);
        @(posedge clk);
        reg_rd_en = 1; reg_addr = addr;
        @(posedge clk);
        reg_rd_en = 0;
        data = reg_rdata;
    endtask

    logic [31:0] rd;

    initial begin
        $display("=== tb_plic ===");
        irq_sources = 0; reg_wr_en = 0; reg_rd_en = 0; reg_addr = 0; reg_wdata = 0;
        srst = 1; repeat(5) @(posedge clk); srst = 0;
        repeat(2) @(posedge clk);

        // Test 1: No interrupts, meip low
        check("meip init low", {31'b0, meip}, 0);

        // Test 2: Assert source 0, but not enabled — meip stays low
        irq_sources = 8'h01;
        @(posedge clk); @(posedge clk);
        check("src0 not enabled", {31'b0, meip}, 0);

        // Test 3: Enable source 0 — meip goes high
        reg_write(32'h004, 32'h0000_0001); // enable bit 0
        @(posedge clk); @(posedge clk);
        check("src0 enabled meip", {31'b0, meip}, 1);

        // Test 4: Raise threshold above priority — meip drops
        reg_write(32'h008, 32'h0000_0007); // threshold = 7 > default priority 1
        @(posedge clk); @(posedge clk);
        check("threshold blocks", {31'b0, meip}, 0);

        // Test 5: Lower threshold — meip returns
        reg_write(32'h008, 32'h0000_0000);
        @(posedge clk); @(posedge clk);
        check("threshold 0 meip", {31'b0, meip}, 1);

        // Test 6: Read pending register
        reg_addr = 32'h000;
        @(posedge clk);
        check("pending src0", reg_rdata[0], 1);

        // Test 7: Deassert source — meip drops
        irq_sources = 0;
        @(posedge clk); @(posedge clk);
        check("src0 cleared meip", {31'b0, meip}, 0);

        // Test 8: Set priority of source 2 high, assert it
        reg_write(32'h018, 32'h0000_0005); // source 2 priority = 5
        reg_write(32'h004, 32'h0000_0004); // enable source 2
        irq_sources = 8'h04;
        @(posedge clk); @(posedge clk);
        check("src2 high pri meip", {31'b0, meip}, 1);

        irq_sources = 0;
        @(posedge clk);

        $display("");
        $display("Results: %0d passed, %0d failed", pass_count, fail_count);
        $stop;
    end

    initial begin #50_000; $display("[TIMEOUT]"); $stop; end

endmodule
