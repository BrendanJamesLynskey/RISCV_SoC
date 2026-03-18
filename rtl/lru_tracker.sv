// Brendan Lynskey 2025
// Unified LRU Tracker — resolves naming conflict between MMU and IOMMU repos
// MIT License
//
// Both MMU (NUM_ENTRIES param) and IOMMU (DEPTH param) instantiate a module
// called lru_tracker with different parameter names and different algorithms.
// This unified version accepts both parameter conventions.
// Tree-based pseudo-LRU implementation (fewer resources than matrix-based).

module lru_tracker #(
    parameter int NUM_ENTRIES = 16,
    parameter int DEPTH       = NUM_ENTRIES
)(
    input  logic                      clk,
    input  logic                      srst,
    input  logic                      access_valid,
    input  logic [$clog2(DEPTH)-1:0]  access_idx,
    output logic [$clog2(DEPTH)-1:0]  lru_idx
);

    localparam int IDX_W = $clog2(DEPTH);

    // Tree-based pseudo-LRU using DEPTH-1 bits
    logic [DEPTH-2:0] tree;

    // On access: walk leaf-to-root, set each node to point AWAY from accessed entry
    integer node_wr, bit_sel;
    always_ff @(posedge clk) begin
        if (srst) begin
            tree <= '0;
        end else if (access_valid) begin
            for (int level = 0; level < IDX_W; level++) begin
                node_wr = (1 << (IDX_W - 1 - level)) - 1 + (access_idx >> (level + 1));
                bit_sel = (access_idx >> level) & 1;
                tree[node_wr] <= ~bit_sel[0];
            end
        end
    end

    // Walk the tree top-down to find LRU entry
    integer node_rd;
    always @(*) begin
        lru_idx = '0;
        node_rd = 0;
        for (int level = 0; level < IDX_W; level++) begin
            if (tree[node_rd] == 1'b0) begin
                lru_idx[IDX_W - 1 - level] = 1'b0;
                node_rd = 2 * node_rd + 1;
            end else begin
                lru_idx[IDX_W - 1 - level] = 1'b1;
                node_rd = 2 * node_rd + 2;
            end
        end
    end

endmodule
