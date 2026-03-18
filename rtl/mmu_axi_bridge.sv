// Brendan Lynskey 2025
// MMU AXI Bridge — wraps mmu_top with translation interface + AXI4 PTW master
// MIT License
//
// CPU-facing side: valid/ready address translation interface
// Bus-facing side: AXI4 master for page table walk memory reads
// Bypass mode: when satp[31]=0, addresses pass through untranslated

module mmu_axi_bridge
    import soc_pkg::*;
    import mmu_pkg::*;
#(
    parameter int AXI_ID_W = ID_W
)(
    input  logic        clk,
    input  logic        srst,

    // CPU-facing translation interface
    input  logic        trans_req_valid,
    output logic        trans_req_ready,
    input  logic [31:0] trans_vaddr,
    input  logic [1:0]  trans_access_type,
    input  logic        trans_priv_mode,

    output logic        trans_resp_valid,
    output logic [31:0] trans_paddr,
    output logic        trans_fault,
    output logic [1:0]  trans_fault_type,

    // AXI4 master port — PTW memory reads only
    output logic                 ptw_arvalid,
    input  logic                 ptw_arready,
    output logic [31:0]          ptw_araddr,
    output logic [AXI_ID_W-1:0] ptw_arid,
    output logic [7:0]           ptw_arlen,
    output logic [2:0]           ptw_arsize,
    output logic [1:0]           ptw_arburst,

    input  logic                 ptw_rvalid,
    output logic                 ptw_rready,
    input  logic [31:0]          ptw_rdata,
    input  logic [AXI_ID_W-1:0] ptw_rid,
    input  logic [1:0]           ptw_rresp,
    input  logic                 ptw_rlast,

    // AW/W/B channels — tied inactive (PTW is read-only)
    output logic                 ptw_awvalid,
    input  logic                 ptw_awready,
    output logic [31:0]          ptw_awaddr,
    output logic [AXI_ID_W-1:0] ptw_awid,
    output logic [7:0]           ptw_awlen,
    output logic [2:0]           ptw_awsize,
    output logic [1:0]           ptw_awburst,

    output logic                 ptw_wvalid,
    input  logic                 ptw_wready,
    output logic [31:0]          ptw_wdata,
    output logic [3:0]           ptw_wstrb,
    output logic                 ptw_wlast,

    input  logic                 ptw_bvalid,
    output logic                 ptw_bready,
    input  logic [AXI_ID_W-1:0] ptw_bid,
    input  logic [1:0]           ptw_bresp,

    // Control / CSR interface
    input  logic [31:0] satp,
    input  logic        sfence_valid,
    input  logic [31:0] sfence_vaddr,
    input  logic [8:0]  sfence_asid,
    input  logic        mxr,
    input  logic        sum
);

    // ---- Tie off write channels (PTW is read-only) ----
    assign ptw_awvalid = 1'b0;
    assign ptw_awaddr  = '0;
    assign ptw_awid    = '0;
    assign ptw_awlen   = '0;
    assign ptw_awsize  = '0;
    assign ptw_awburst = '0;
    assign ptw_wvalid  = 1'b0;
    assign ptw_wdata   = '0;
    assign ptw_wstrb   = '0;
    assign ptw_wlast   = 1'b0;
    assign ptw_bready  = 1'b1;

    // ---- MMU ↔ PTW memory interface ----
    logic        mem_req_valid;
    logic        mem_req_ready;
    logic [31:0] mem_req_addr;
    logic        mem_resp_valid;
    logic [31:0] mem_resp_data;

    // ---- MMU core instance ----
    mmu_top u_mmu (
        .clk           (clk),
        .srst          (srst),
        .req_valid     (trans_req_valid),
        .req_ready     (trans_req_ready),
        .vaddr         (trans_vaddr),
        .access_type   (trans_access_type),
        .priv_mode     (trans_priv_mode),
        .resp_valid    (trans_resp_valid),
        .paddr         (trans_paddr),
        .page_fault    (trans_fault),
        .fault_type    (trans_fault_type),
        .mem_req_valid (mem_req_valid),
        .mem_req_ready (mem_req_ready),
        .mem_req_addr  (mem_req_addr),
        .mem_resp_valid(mem_resp_valid),
        .mem_resp_data (mem_resp_data),
        .satp          (satp),
        .sfence_valid  (sfence_valid),
        .sfence_vaddr  (sfence_vaddr),
        .sfence_asid   (sfence_asid),
        .mxr           (mxr),
        .sum           (sum)
    );

    // ---- PTW ↔ AXI4 AR/R bridge ----
    // Converts simple mem_req/mem_resp to AXI4 single-beat reads
    typedef enum logic [1:0] {
        PTW_IDLE,
        PTW_AR,
        PTW_R
    } ptw_state_t;

    ptw_state_t ptw_state;
    logic [31:0] ptw_addr_r;

    always_ff @(posedge clk) begin
        if (srst) begin
            ptw_state  <= PTW_IDLE;
            ptw_addr_r <= '0;
        end else begin
            case (ptw_state)
                PTW_IDLE: begin
                    if (mem_req_valid) begin
                        ptw_addr_r <= mem_req_addr;
                        ptw_state  <= PTW_AR;
                    end
                end
                PTW_AR: begin
                    if (ptw_arready)
                        ptw_state <= PTW_R;
                end
                PTW_R: begin
                    if (ptw_rvalid)
                        ptw_state <= PTW_IDLE;
                end
                default: ptw_state <= PTW_IDLE;
            endcase
        end
    end

    // AXI AR channel
    assign ptw_arvalid = (ptw_state == PTW_AR);
    assign ptw_araddr  = ptw_addr_r;
    assign ptw_arid    = '0;
    assign ptw_arlen   = 8'd0;     // single beat
    assign ptw_arsize  = 3'b010;   // 4 bytes
    assign ptw_arburst = 2'b01;    // INCR

    // AXI R channel
    assign ptw_rready = (ptw_state == PTW_R);

    // Back to MMU
    assign mem_req_ready  = (ptw_state == PTW_IDLE);
    assign mem_resp_valid = (ptw_state == PTW_R) && ptw_rvalid;
    assign mem_resp_data  = ptw_rdata;

endmodule
