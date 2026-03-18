// Brendan Lynskey 2025
// AXI4 SRAM Slave — single-port SRAM with AXI4 interface
// MIT License
//
// This module provides a simple SRAM backing store accessible via
// AXI4 read/write channels. Supports single-beat and burst transfers.
// Used as Slave 0 (instruction SRAM) and Slave 1 (data SRAM) in the SoC.

module axi_sram #(
    parameter ADDR_W     = 32,
    parameter DATA_W     = 32,
    parameter ID_W       = 5,
    parameter DEPTH      = 16384,  // number of words
    parameter INIT_FILE  = ""
)(
    input  logic                clk,
    input  logic                srst,

    // AXI4 Write Address channel
    input  logic                awvalid,
    output logic                awready,
    input  logic [ADDR_W-1:0]   awaddr,
    input  logic [ID_W-1:0]     awid,
    input  logic [7:0]          awlen,
    input  logic [2:0]          awsize,
    input  logic [1:0]          awburst,

    // AXI4 Write Data channel
    input  logic                wvalid,
    output logic                wready,
    input  logic [DATA_W-1:0]   wdata,
    input  logic [DATA_W/8-1:0] wstrb,
    input  logic                wlast,

    // AXI4 Write Response channel
    output logic                bvalid,
    input  logic                bready,
    output logic [ID_W-1:0]     bid,
    output logic [1:0]          bresp,

    // AXI4 Read Address channel
    input  logic                arvalid,
    output logic                arready,
    input  logic [ADDR_W-1:0]   araddr,
    input  logic [ID_W-1:0]     arid,
    input  logic [7:0]          arlen,
    input  logic [2:0]          arsize,
    input  logic [1:0]          arburst,

    // AXI4 Read Data channel
    output logic                rvalid,
    input  logic                rready,
    output logic [DATA_W-1:0]   rdata,
    output logic [ID_W-1:0]     rid,
    output logic [1:0]          rresp,
    output logic                rlast
);

    localparam ADDR_LSB = $clog2(DATA_W / 8);
    localparam MEM_AW   = $clog2(DEPTH);

    // -------------------------------------------------------------------------
    // Memory array
    // -------------------------------------------------------------------------
    logic [DATA_W-1:0] mem [0:DEPTH-1];

    initial begin
        integer i;
        for (i = 0; i < DEPTH; i = i + 1) mem[i] = '0;
        if (INIT_FILE != "") $readmemh(INIT_FILE, mem);
    end

    // -------------------------------------------------------------------------
    // Write FSM
    // -------------------------------------------------------------------------
    typedef enum logic [1:0] {
        W_IDLE,
        W_DATA,
        W_RESP
    } w_state_t;

    w_state_t           w_state;
    logic [ID_W-1:0]    w_id;
    logic [ADDR_W-1:0]  w_addr;
    logic [7:0]         w_len;
    logic [7:0]         w_cnt;

    always_ff @(posedge clk) begin
        if (srst) begin
            w_state <= W_IDLE;
            w_id    <= '0;
            w_addr  <= '0;
            w_len   <= '0;
            w_cnt   <= '0;
        end else begin
            case (w_state)
                W_IDLE: begin
                    if (awvalid && awready) begin
                        w_id    <= awid;
                        w_addr  <= awaddr;
                        w_len   <= awlen;
                        w_cnt   <= '0;
                        w_state <= W_DATA;
                    end
                end

                W_DATA: begin
                    if (wvalid && wready) begin
                        // Byte-lane write
                        for (int b = 0; b < DATA_W/8; b++) begin
                            if (wstrb[b])
                                mem[w_addr[ADDR_LSB +: MEM_AW]][b*8 +: 8] <= wdata[b*8 +: 8];
                        end
                        w_addr <= w_addr + (1 << ADDR_LSB);
                        w_cnt  <= w_cnt + 1;
                        if (wlast) begin
                            w_state <= W_RESP;
                        end
                    end
                end

                W_RESP: begin
                    if (bvalid && bready) begin
                        w_state <= W_IDLE;
                    end
                end
            endcase
        end
    end

    assign awready = (w_state == W_IDLE);
    assign wready  = (w_state == W_DATA);
    assign bvalid  = (w_state == W_RESP);
    assign bid     = w_id;
    assign bresp   = 2'b00; // OKAY

    // -------------------------------------------------------------------------
    // Read FSM
    // -------------------------------------------------------------------------
    typedef enum logic [1:0] {
        R_IDLE,
        R_DATA
    } r_state_t;

    r_state_t           r_state;
    logic [ID_W-1:0]    r_id;
    logic [ADDR_W-1:0]  r_addr;
    logic [7:0]         r_len;
    logic [7:0]         r_cnt;

    always_ff @(posedge clk) begin
        if (srst) begin
            r_state <= R_IDLE;
            r_id    <= '0;
            r_addr  <= '0;
            r_len   <= '0;
            r_cnt   <= '0;
        end else begin
            case (r_state)
                R_IDLE: begin
                    if (arvalid && arready) begin
                        r_id    <= arid;
                        r_addr  <= araddr;
                        r_len   <= arlen;
                        r_cnt   <= '0;
                        r_state <= R_DATA;
                    end
                end

                R_DATA: begin
                    if (rvalid && rready) begin
                        r_addr <= r_addr + (1 << ADDR_LSB);
                        r_cnt  <= r_cnt + 1;
                        if (r_cnt == r_len) begin
                            r_state <= R_IDLE;
                        end
                    end
                end
            endcase
        end
    end

    assign arready = (r_state == R_IDLE);
    assign rvalid  = (r_state == R_DATA);
    assign rdata   = mem[r_addr[ADDR_LSB +: MEM_AW]];
    assign rid     = r_id;
    assign rresp   = 2'b00; // OKAY
    assign rlast   = (r_state == R_DATA) && (r_cnt == r_len);

endmodule
