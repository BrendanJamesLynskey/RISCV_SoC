// Brendan Lynskey 2025
// SoC-specific override of axi_xbar_pkg
// MIT License
//
// Redefines axi_xbar_pkg with N_MASTERS=3, N_SLAVES=5 and the SoC address
// map.  Compile this INSTEAD of AXI4_Crossbar/rtl/axi_xbar_pkg.sv so that
// every crossbar module picks up the correct configuration.

package axi_xbar_pkg;

    parameter int N_MASTERS     = 3;
    parameter int N_SLAVES      = 5;
    parameter int ADDR_W        = 32;
    parameter int DATA_W        = 32;
    parameter int STRB_W        = DATA_W / 8;
    parameter int ID_W          = 4;
    parameter int SID_W         = ID_W + $clog2(N_MASTERS);
    parameter int MSTR_IDX_W    = $clog2(N_MASTERS);

    // Arbiter mode
    typedef enum logic {
        ARB_ROUND_ROBIN = 1'b0,
        ARB_FIXED_PRIO  = 1'b1
    } arb_mode_t;

    // Burst type encoding
    localparam logic [1:0] BURST_FIXED = 2'b00;
    localparam logic [1:0] BURST_INCR  = 2'b01;

    // Response encoding
    localparam logic [1:0] RESP_OKAY   = 2'b00;
    localparam logic [1:0] RESP_EXOKAY = 2'b01;
    localparam logic [1:0] RESP_SLVERR = 2'b10;
    localparam logic [1:0] RESP_DECERR = 2'b11;

    // Address map — matches soc_pkg (5 slaves)
    localparam logic [N_SLAVES*ADDR_W-1:0] SLAVE_BASE_FLAT = {
        32'h3000_1000,   // Slave 4: IOMMU registers
        32'h3000_0000,   // Slave 3: DMA registers
        32'h2000_0000,   // Slave 2: Peripheral bridge
        32'h1000_0000,   // Slave 1: Data SRAM
        32'h0000_0000    // Slave 0: Instruction SRAM
    };

    localparam logic [N_SLAVES*ADDR_W-1:0] SLAVE_MASK_FLAT = {
        32'h0000_0FFF,   // Slave 4: 4 KB
        32'h0000_0FFF,   // Slave 3: 4 KB
        32'h0000_FFFF,   // Slave 2: 64 KB
        32'h0001_FFFF,   // Slave 1: 128 KB
        32'h0000_FFFF    // Slave 0: 64 KB
    };

endpackage
