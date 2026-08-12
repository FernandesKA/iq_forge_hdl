`timescale 1ps/1ps

module ad9361_tx_lvds (
    input logic i_clk,
    input logic i_rst_n,
    input logic [11:0] i_tx_i,
    input logic [11:0] i_tx_q,
    output logic [5:0] o_tx_d_p,
    output logic [5:0] o_tx_d_n,
    output logic o_tx_frame_p,
    output logic o_tx_frame_n,
    output logic o_fb_clk_p,
    output logic o_fb_clk_n
);

logic phase_sel;

always_ff @(posedge i_clk, negedge i_rst_n) begin
    if (~i_rst_n) begin
        phase_sel <= 1'b0;
    end else begin
        phase_sel <= ~phase_sel;
    end
end

fb_clk_gen fb_clk_gen_inst(
    .i_clk(i_clk),
    .o_fb_clk_n(o_fb_clk_n),
    .o_fb_clk_p(o_fb_clk_p)
);

logic tx_frame_q;

ODDR #(
   .DDR_CLK_EDGE("OPPOSITE_EDGE"), // "OPPOSITE_EDGE" or "SAME_EDGE"
   .INIT(1'b0),    // Initial value of Q: 1'b0 or 1'b1
   .SRTYPE("SYNC") // Set/Reset type: "SYNC" or "ASYNC"
) ODDR_inst (
   .Q(tx_frame_q),   // 1-bit DDR output
   .C(i_clk),   // 1-bit clock input
   .CE(1'b1), // 1-bit clock enable input
   .D1(phase_sel), // 1-bit data input (positive edge)
   .D2(phase_sel), // 1-bit data input (negative edge)
   .R(~i_rst_n),   // 1-bit reset
   .S(0)    // 1-bit set
);

OBUFDS #(
   .IOSTANDARD("DEFAULT"), // Specify the output I/O standard
   .SLEW("SLOW")           // Specify the output slew rate
) OBUFDS_inst (
   .O(o_tx_frame_p),     // Diff_p output (connect directly to top-level port)
   .OB(o_tx_frame_n),   // Diff_n output (connect directly to top-level port)
   .I(tx_frame_q)      // Buffer input
);

logic [5:0] frame_data_q;

logic [5:0] tx_i_slice;
logic [5:0] tx_q_slice;

always_comb begin
    if (phase_sel) begin
        tx_i_slice = i_tx_i[11:6];
        tx_q_slice = i_tx_q[11:6];
    end else begin
        tx_i_slice = i_tx_i[5:0];
        tx_q_slice = i_tx_q[5:0];
    end
end

genvar i;
generate
    for (i = 0; i < 6; i++) begin : gen_bit
        ODDR #(
        .DDR_CLK_EDGE("OPPOSITE_EDGE"), // "OPPOSITE_EDGE" or "SAME_EDGE"
        .INIT(1'b0),    // Initial value of Q: 1'b0 or 1'b1
        .SRTYPE("SYNC") // Set/Reset type: "SYNC" or "ASYNC"
        ) ODDR_inst (
        .Q(frame_data_q[i]),   // 1-bit DDR output
        .C(i_clk),   // 1-bit clock input
        .CE(1'b1), // 1-bit clock enable input
        .D1(tx_i_slice[i]), // 1-bit data input (positive edge)
        .D2(tx_q_slice[i]), // 1-bit data input (negative edge)
        .R(~i_rst_n),   // 1-bit reset
        .S(0)    // 1-bit set
        );

        OBUFDS #(
        .IOSTANDARD("DEFAULT"), // Specify the output I/O standard
        .SLEW("SLOW")           // Specify the output slew rate
        ) OBUFDS_inst (
        .O(o_tx_d_p[i]),     // Diff_p output (connect directly to top-level port)
        .OB(o_tx_d_n[i]),   // Diff_n output (connect directly to top-level port)
        .I(frame_data_q[i])      // Buffer input
        );
    end
endgenerate



endmodule