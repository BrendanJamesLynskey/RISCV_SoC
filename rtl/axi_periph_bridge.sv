// Brendan Lynskey 2025
// AXI4 Peripheral Bridge — decodes AXI transactions to simple reg interface
// MIT License
//
// Bridges AXI4 slave port to a simple valid/ready register interface
// for GPIO, UART, and Timer peripherals. Single-beat only (no bursts).

module axi_periph_bridge #(
    parameter ADDR_W = 32,
    parameter DATA_W = 32,
    parameter ID_W   = 5
)(
    input  logic                clk,
    input  logic                srst,

    // AXI4 Slave interface (from crossbar)
    input  logic                awvalid,
    output logic                awready,
    input  logic [ADDR_W-1:0]   awaddr,
    input  logic [ID_W-1:0]     awid,
    input  logic [7:0]          awlen,
    input  logic [2:0]          awsize,
    input  logic [1:0]          awburst,

    input  logic                wvalid,
    output logic                wready,
    input  logic [DATA_W-1:0]   wdata,
    input  logic [DATA_W/8-1:0] wstrb,
    input  logic                wlast,

    output logic                bvalid,
    input  logic                bready,
    output logic [ID_W-1:0]     bid,
    output logic [1:0]          bresp,

    input  logic                arvalid,
    output logic                arready,
    input  logic [ADDR_W-1:0]   araddr,
    input  logic [ID_W-1:0]     arid,
    input  logic [7:0]          arlen,
    input  logic [2:0]          arsize,
    input  logic [1:0]          arburst,

    output logic                rvalid,
    input  logic                rready,
    output logic [DATA_W-1:0]   rdata,
    output logic [ID_W-1:0]     rid,
    output logic [1:0]          rresp,
    output logic                rlast,

    // Simple register interface to peripherals
    output logic                periph_wr_en,
    output logic                periph_rd_en,
    output logic [ADDR_W-1:0]   periph_addr,
    output logic [DATA_W-1:0]   periph_wdata,
    output logic [DATA_W/8-1:0] periph_wstrb,
    input  logic [DATA_W-1:0]   periph_rdata
);

    // -------------------------------------------------------------------------
    // Write path
    // -------------------------------------------------------------------------
    typedef enum logic [1:0] {
        WR_IDLE,
        WR_DATA,
        WR_RESP
    } wr_state_t;

    wr_state_t       wr_state;
    logic [ID_W-1:0] wr_id;
    logic [ADDR_W-1:0] wr_addr;

    always_ff @(posedge clk) begin
        if (srst) begin
            wr_state <= WR_IDLE;
            wr_id    <= '0;
            wr_addr  <= '0;
        end else begin
            case (wr_state)
                WR_IDLE: begin
                    if (awvalid && awready) begin
                        wr_id    <= awid;
                        wr_addr  <= awaddr;
                        wr_state <= WR_DATA;
                    end
                end
                WR_DATA: begin
                    if (wvalid && wready) begin
                        wr_state <= WR_RESP;
                    end
                end
                WR_RESP: begin
                    if (bvalid && bready) begin
                        wr_state <= WR_IDLE;
                    end
                end
            endcase
        end
    end

    assign awready     = (wr_state == WR_IDLE);
    assign wready      = (wr_state == WR_DATA);
    assign bvalid      = (wr_state == WR_RESP);
    assign bid         = wr_id;
    assign bresp       = 2'b00;
    assign periph_wr_en = (wr_state == WR_DATA) && wvalid;
    assign periph_wdata = wdata;
    assign periph_wstrb = wstrb;

    // -------------------------------------------------------------------------
    // Read path
    // -------------------------------------------------------------------------
    typedef enum logic [1:0] {
        RD_IDLE,
        RD_DATA
    } rd_state_t;

    rd_state_t       rd_state;
    logic [ID_W-1:0] rd_id;
    logic [ADDR_W-1:0] rd_addr;
    logic [DATA_W-1:0] rd_data_r;

    always_ff @(posedge clk) begin
        if (srst) begin
            rd_state  <= RD_IDLE;
            rd_id     <= '0;
            rd_addr   <= '0;
            rd_data_r <= '0;
        end else begin
            case (rd_state)
                RD_IDLE: begin
                    if (arvalid && arready) begin
                        rd_id     <= arid;
                        rd_addr   <= araddr;
                        rd_data_r <= periph_rdata;
                        rd_state  <= RD_DATA;
                    end
                end
                RD_DATA: begin
                    if (rvalid && rready) begin
                        rd_state <= RD_IDLE;
                    end
                end
            endcase
        end
    end

    assign arready     = (rd_state == RD_IDLE);
    assign rvalid      = (rd_state == RD_DATA);
    assign rdata       = rd_data_r;
    assign rid         = rd_id;
    assign rresp       = 2'b00;
    assign rlast       = rvalid;
    assign periph_rd_en = arvalid && arready;

    // Address mux — write address during write, read address during read
    assign periph_addr = (wr_state == WR_DATA) ? wr_addr :
                         (arvalid && arready)  ? araddr  : rd_addr;

endmodule
