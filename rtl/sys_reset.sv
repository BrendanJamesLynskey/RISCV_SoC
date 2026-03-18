// Brendan Lynskey 2025
// System Reset Controller — async assert, sync deassert
// MIT License

module sys_reset #(
    parameter SYNC_STAGES = 3
)(
    input  logic clk,
    input  logic ext_rst_n,   // active-low external reset (button/pin)
    output logic srst          // synchronous active-high reset
);

    logic [SYNC_STAGES-1:0] rst_pipe;

    always_ff @(posedge clk or negedge ext_rst_n) begin
        if (!ext_rst_n) begin
            rst_pipe <= {SYNC_STAGES{1'b1}};
        end else begin
            rst_pipe <= {rst_pipe[SYNC_STAGES-2:0], 1'b0};
        end
    end

    assign srst = rst_pipe[SYNC_STAGES-1];

endmodule
