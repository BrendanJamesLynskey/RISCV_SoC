// Brendan Lynskey 2025
// Peripheral Subsystem — sub-decodes peripheral bridge to GPIO, UART, Timer, PLIC
// MIT License
//
// Address bits [13:12] select the peripheral:
//   2'b00 → GPIO   (offset 0x0000)
//   2'b01 → UART   (offset 0x1000)
//   2'b10 → Timer  (offset 0x2000)
//   2'b11 → PLIC   (offset 0x3000)

module periph_subsystem
    import soc_pkg::*;
(
    input  logic                clk,
    input  logic                srst,

    // Peripheral bridge register interface
    input  logic                periph_wr_en,
    input  logic                periph_rd_en,
    input  logic [ADDR_W-1:0]   periph_addr,
    input  logic [DATA_W-1:0]   periph_wdata,
    input  logic [STRB_W-1:0]   periph_wstrb,
    output logic [DATA_W-1:0]   periph_rdata,

    // GPIO external pins
    input  logic [31:0]         gpio_in,
    output logic [31:0]         gpio_out,
    output logic [31:0]         gpio_oe,

    // UART external pins
    input  logic                uart_rx,
    output logic                uart_tx,

    // DMA interrupts (from outside)
    input  logic [3:0]          dma_irq,

    // Interrupt outputs (exposed for visibility)
    output logic                timer_irq,
    output logic                uart_rx_irq,
    output logic                gpio_irq,

    // PLIC output
    output logic                meip
);

    // -------------------------------------------------------------------------
    // Address sub-decode
    // -------------------------------------------------------------------------
    logic [1:0] periph_sel;
    assign periph_sel = periph_addr[13:12];

    logic gpio_wr_en,  gpio_rd_en;
    logic uart_wr_en,  uart_rd_en;
    logic timer_wr_en, timer_rd_en;
    logic plic_wr_en,  plic_rd_en;

    assign gpio_wr_en  = periph_wr_en && (periph_sel == 2'b00);
    assign gpio_rd_en  = periph_rd_en && (periph_sel == 2'b00);
    assign uart_wr_en  = periph_wr_en && (periph_sel == 2'b01);
    assign uart_rd_en  = periph_rd_en && (periph_sel == 2'b01);
    assign timer_wr_en = periph_wr_en && (periph_sel == 2'b10);
    assign timer_rd_en = periph_rd_en && (periph_sel == 2'b10);
    assign plic_wr_en  = periph_wr_en && (periph_sel == 2'b11);
    assign plic_rd_en  = periph_rd_en && (periph_sel == 2'b11);

    // -------------------------------------------------------------------------
    // Peripheral read-data buses
    // -------------------------------------------------------------------------
    logic [31:0] gpio_rdata;
    logic [31:0] uart_rdata;
    logic [31:0] timer_rdata;
    logic [31:0] plic_rdata;

    // Active-low reset for Verilog-2001 peripherals (they use rst_n)
    logic rst_n;
    assign rst_n = ~srst;

    // -------------------------------------------------------------------------
    // GPIO
    // -------------------------------------------------------------------------
    gpio u_gpio (
        .clk      (clk),
        .rst_n    (rst_n),
        .addr     (periph_addr[7:0]),
        .wr_en    (gpio_wr_en),
        .rd_en    (gpio_rd_en),
        .wdata    (periph_wdata),
        .rdata    (gpio_rdata),
        .gpio_in  (gpio_in),
        .gpio_out (gpio_out),
        .irq      (gpio_irq)
    );

    // Shadow the GPIO direction register for gpio_oe output.
    // GPIO module doesn't expose dir as a port, so we capture writes to it.
    // GPIO dir register: addr[4:2] == 3'd2
    always_ff @(posedge clk) begin
        if (srst)
            gpio_oe <= '0;
        else if (gpio_wr_en && periph_addr[4:2] == 3'd2)
            gpio_oe <= periph_wdata;
    end

    // -------------------------------------------------------------------------
    // UART
    // -------------------------------------------------------------------------
    uart u_uart (
        .clk      (clk),
        .rst_n    (rst_n),
        .addr     (periph_addr[7:0]),
        .wr_en    (uart_wr_en),
        .rd_en    (uart_rd_en),
        .wdata    (periph_wdata),
        .rdata    (uart_rdata),
        .uart_tx  (uart_tx),
        .uart_rx  (uart_rx),
        .irq      (uart_rx_irq)
    );

    // -------------------------------------------------------------------------
    // Timer
    // -------------------------------------------------------------------------
    timer u_timer (
        .clk      (clk),
        .rst_n    (rst_n),
        .addr     (periph_addr[7:0]),
        .wr_en    (timer_wr_en),
        .rd_en    (timer_rd_en),
        .wdata    (periph_wdata),
        .rdata    (timer_rdata),
        .irq      (timer_irq)
    );

    // -------------------------------------------------------------------------
    // PLIC — interrupt source assembly
    // -------------------------------------------------------------------------
    logic [N_EXT_IRQ-1:0] irq_sources;
    assign irq_sources[IRQ_TIMER]   = timer_irq;
    assign irq_sources[IRQ_UART_TX] = 1'b0;  // UART module has no TX interrupt
    assign irq_sources[IRQ_UART_RX] = uart_rx_irq;
    assign irq_sources[IRQ_GPIO]    = gpio_irq;
    assign irq_sources[IRQ_DMA_CH0] = dma_irq[0];
    assign irq_sources[IRQ_DMA_CH1] = dma_irq[1];
    assign irq_sources[IRQ_DMA_CH2] = dma_irq[2];
    assign irq_sources[IRQ_DMA_CH3] = dma_irq[3];

    plic #(
        .N_SOURCES (N_EXT_IRQ),
        .ADDR_W    (ADDR_W),
        .DATA_W    (DATA_W)
    ) u_plic (
        .clk         (clk),
        .srst        (srst),
        .irq_sources (irq_sources),
        .meip        (meip),
        .reg_wr_en   (plic_wr_en),
        .reg_rd_en   (plic_rd_en),
        .reg_addr    (periph_addr),
        .reg_wdata   (periph_wdata),
        .reg_rdata   (plic_rdata)
    );

    // -------------------------------------------------------------------------
    // Read-data mux
    // -------------------------------------------------------------------------
    always @(*) begin
        case (periph_sel)
            2'b00:   periph_rdata = gpio_rdata;
            2'b01:   periph_rdata = uart_rdata;
            2'b10:   periph_rdata = timer_rdata;
            2'b11:   periph_rdata = plic_rdata;
            default: periph_rdata = '0;
        endcase
    end

endmodule
