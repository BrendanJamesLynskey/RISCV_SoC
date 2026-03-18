// Brendan Lynskey 2025
// Simple PLIC — Platform-Level Interrupt Controller
// MIT License
//
// A simplified PLIC for the SoC. Accepts N external interrupt sources,
// provides priority-based arbitration, and presents a single external
// interrupt to the CPU core (meip). Memory-mapped registers allow
// software to set priorities, enable/disable sources, and claim/complete.

module plic #(
    parameter N_SOURCES = 8,
    parameter ADDR_W    = 32,
    parameter DATA_W    = 32
)(
    input  logic                clk,
    input  logic                srst,

    // Interrupt sources (active-high, level-triggered)
    input  logic [N_SOURCES-1:0] irq_sources,

    // CPU interrupt output
    output logic                meip,       // machine external interrupt pending

    // Register interface (from peripheral bridge)
    input  logic                reg_wr_en,
    input  logic                reg_rd_en,
    input  logic [ADDR_W-1:0]   reg_addr,
    input  logic [DATA_W-1:0]   reg_wdata,
    output logic [DATA_W-1:0]   reg_rdata
);

    // -------------------------------------------------------------------------
    // Registers
    // -------------------------------------------------------------------------
    // 0x00: IRQ pending   (RO)
    // 0x04: IRQ enable    (RW)
    // 0x08: Priority threshold (RW)
    // 0x0C: Claim/complete (R=claim, W=complete)
    // 0x10+: Per-source priority (RW), one word each

    logic [N_SOURCES-1:0] irq_enable;
    logic [2:0]           threshold;
    logic [2:0]           priorities [0:N_SOURCES-1];
    logic [N_SOURCES-1:0] irq_pending;
    logic [$clog2(N_SOURCES)-1:0] claimed_id;
    logic                 claim_valid;

    // Pending = source asserted AND enabled
    assign irq_pending = irq_sources & irq_enable;

    // -------------------------------------------------------------------------
    // Priority arbitration — find highest-priority pending interrupt
    // -------------------------------------------------------------------------
    logic [$clog2(N_SOURCES)-1:0] best_id;
    logic [2:0]                    best_pri;
    logic                          any_pending;

    always @(*) begin
        best_id    = '0;
        best_pri   = '0;
        any_pending = 1'b0;
        for (int i = 0; i < N_SOURCES; i++) begin
            if (irq_pending[i] && (priorities[i] > best_pri)) begin
                best_id    = i[$clog2(N_SOURCES)-1:0];
                best_pri   = priorities[i];
                any_pending = 1'b1;
            end
        end
    end

    // meip asserted if best priority exceeds threshold
    assign meip = any_pending && (best_pri > threshold);

    // -------------------------------------------------------------------------
    // Register read/write
    // -------------------------------------------------------------------------
    logic [11:0] reg_offset;
    assign reg_offset = reg_addr[11:0];

    always_ff @(posedge clk) begin
        if (srst) begin
            irq_enable  <= '0;
            threshold   <= '0;
            claim_valid <= 1'b0;
            claimed_id  <= '0;
            for (int i = 0; i < N_SOURCES; i++)
                priorities[i] <= 3'd1;  // default priority 1
        end else begin
            if (reg_wr_en) begin
                case (reg_offset)
                    12'h004: irq_enable <= reg_wdata[N_SOURCES-1:0];
                    12'h008: threshold  <= reg_wdata[2:0];
                    12'h00C: begin
                        // Complete: no action needed in this simple design
                        claim_valid <= 1'b0;
                    end
                    default: begin
                        // Per-source priority: offset 0x10 + i*4
                        if (reg_offset >= 12'h010 &&
                            reg_offset < (12'h010 + N_SOURCES * 4)) begin
                            automatic int idx;
                            idx = (reg_offset - 12'h010) >> 2;
                            priorities[idx] <= reg_wdata[2:0];
                        end
                    end
                endcase
            end

            // Claim on read of 0x0C
            if (reg_rd_en && reg_offset == 12'h00C) begin
                claimed_id  <= best_id;
                claim_valid <= any_pending;
            end
        end
    end

    always @(*) begin
        reg_rdata = '0;
        case (reg_offset)
            12'h000: reg_rdata = {{(DATA_W-N_SOURCES){1'b0}}, irq_pending};
            12'h004: reg_rdata = {{(DATA_W-N_SOURCES){1'b0}}, irq_enable};
            12'h008: reg_rdata = {29'b0, threshold};
            12'h00C: reg_rdata = {{(DATA_W-$clog2(N_SOURCES)){1'b0}}, best_id};
            default: begin
                if (reg_offset >= 12'h010 &&
                    reg_offset < (12'h010 + N_SOURCES * 4)) begin
                    automatic int idx;
                    idx = (reg_offset - 12'h010) >> 2;
                    reg_rdata = {29'b0, priorities[idx]};
                end
            end
        endcase
    end

endmodule
