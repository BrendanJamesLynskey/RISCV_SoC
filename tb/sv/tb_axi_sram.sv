// Brendan Lynskey 2025
// tb_axi_sram — AXI SRAM slave unit testbench
// MIT License

`timescale 1ns / 1ps

module tb_axi_sram;

    parameter ADDR_W = 32;
    parameter DATA_W = 32;
    parameter ID_W   = 4;
    parameter DEPTH  = 256;

    logic clk, srst;
    initial clk = 0;
    always #5 clk = ~clk;

    // AXI signals
    logic                awvalid, awready;
    logic [ADDR_W-1:0]   awaddr;
    logic [ID_W-1:0]     awid;
    logic [7:0]          awlen;
    logic [2:0]          awsize;
    logic [1:0]          awburst;
    logic                wvalid, wready;
    logic [DATA_W-1:0]   wdata;
    logic [DATA_W/8-1:0] wstrb;
    logic                wlast;
    logic                bvalid, bready;
    logic [ID_W-1:0]     bid;
    logic [1:0]          bresp;
    logic                arvalid, arready;
    logic [ADDR_W-1:0]   araddr;
    logic [ID_W-1:0]     arid;
    logic [7:0]          arlen;
    logic [2:0]          arsize;
    logic [1:0]          arburst;
    logic                rvalid, rready;
    logic [DATA_W-1:0]   rdata;
    logic [ID_W-1:0]     rid;
    logic [1:0]          rresp;
    logic                rlast;

    axi_sram #(
        .ADDR_W(ADDR_W), .DATA_W(DATA_W), .ID_W(ID_W), .DEPTH(DEPTH)
    ) dut (.*);

    integer pass_count = 0;
    integer fail_count = 0;

    task check(input string name, input logic [31:0] got, input logic [31:0] exp);
        if (got === exp) begin
            $display("[PASS] %s: 0x%08h", name, got);
            pass_count++;
        end else begin
            $display("[FAIL] %s: got 0x%08h exp 0x%08h", name, got, exp);
            fail_count++;
        end
    endtask

    task axi_write(input logic [31:0] addr, input logic [31:0] data, input logic [3:0] strb_val);
        @(posedge clk);
        awvalid = 1; awaddr = addr; awid = 0; awlen = 0; awsize = 2; awburst = 1;
        @(posedge clk);
        while (!awready) @(posedge clk);
        awvalid = 0;
        wvalid = 1; wdata = data; wstrb = strb_val; wlast = 1;
        @(posedge clk);
        while (!wready) @(posedge clk);
        wvalid = 0; wlast = 0;
        bready = 1;
        @(posedge clk);
        while (!bvalid) @(posedge clk);
        bready = 0;
    endtask

    task axi_read(input logic [31:0] addr, output logic [31:0] data);
        @(posedge clk);
        arvalid = 1; araddr = addr; arid = 0; arlen = 0; arsize = 2; arburst = 1;
        @(posedge clk);
        while (!arready) @(posedge clk);
        arvalid = 0;
        rready = 1;
        @(posedge clk);
        while (!rvalid) @(posedge clk);
        data = rdata;
        rready = 0;
    endtask

    logic [31:0] rd;

    initial begin
        $display("=== tb_axi_sram ===");
        awvalid=0; wvalid=0; bready=0; arvalid=0; rready=0;
        srst = 1; repeat(5) @(posedge clk); srst = 0;
        repeat(2) @(posedge clk);

        // Test 1: Write and read back
        axi_write(32'h0000_0000, 32'hDEAD_BEEF, 4'hF);
        axi_read(32'h0000_0000, rd);
        check("Write/Read word", rd, 32'hDEAD_BEEF);

        // Test 2: Byte-lane write
        axi_write(32'h0000_0004, 32'hFFFF_FFFF, 4'hF);
        axi_write(32'h0000_0004, 32'h0000_00AA, 4'h1); // write byte 0 only
        axi_read(32'h0000_0004, rd);
        check("Byte-lane write", rd, 32'hFFFF_FFAA);

        // Test 3: Different addresses
        axi_write(32'h0000_0008, 32'h1111_1111, 4'hF);
        axi_write(32'h0000_000C, 32'h2222_2222, 4'hF);
        axi_read(32'h0000_0008, rd);
        check("Addr 0x08", rd, 32'h1111_1111);
        axi_read(32'h0000_000C, rd);
        check("Addr 0x0C", rd, 32'h2222_2222);

        // Test 4: Read returns OKAY resp
        check("Read resp OKAY", {30'b0, rresp}, 32'd0);

        // Test 5: Initial memory is zero
        axi_read(32'h0000_0100, rd);
        check("Uninit mem zero", rd, 32'h0000_0000);

        $display("");
        $display("Results: %0d passed, %0d failed", pass_count, fail_count);
        $stop;
    end

    initial begin #50_000; $display("[TIMEOUT]"); $stop; end

endmodule
