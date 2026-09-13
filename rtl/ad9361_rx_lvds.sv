`timescale 1ns/1ns

module ad9361_rx_lvds (
    input  logic       i_clk_p,
    input  logic       i_clk_n,
    input  logic       i_rst_n,
    input  logic       i_rx_frame_p,
    input  logic       i_rx_frame_n,
    input  logic [5:0] i_rx_d_p,
    input  logic [5:0] i_rx_d_n,
    output logic       o_clk,
    output logic [11:0] o_data_i,
    output logic [11:0] o_data_q,
    output logic        o_valid
);

    logic rx_clk_ibuf;
    IBUFDS IBUFDS_clk_inst (
        .O(rx_clk_ibuf),
        .I(i_clk_p),
        .IB(i_clk_n)
    );

    BUFG BUFG_rx_clk_inst (
        .O(o_clk),
        .I(rx_clk_ibuf)
    );

    logic rx_frame_se;
    IBUFDS IBUFDS_frame_inst (
        .O(rx_frame_se),
        .I(i_rx_frame_p),
        .IB(i_rx_frame_n)
    );

    logic frame_q1, frame_q2;
    IDDR #(
        .DDR_CLK_EDGE("SAME_EDGE_PIPELINED"),
        .INIT_Q1(1'b0),
        .INIT_Q2(1'b0),
        .SRTYPE("SYNC")
    ) IDDR_frame_inst (
        .Q1(frame_q1),
        .Q2(frame_q2),
        .C(o_clk),
        .CE(1'b1),
        .D(rx_frame_se),
        .R(~i_rst_n),
        .S(1'b0)
    );

    logic [5:0] rx_d_se;
    logic [5:0] d_q1, d_q2;

    genvar i;
    generate
        for (i = 0; i < 6; i++) begin : gen_bit
            IBUFDS IBUFDS_d_inst (
                .O(rx_d_se[i]),
                .I(i_rx_d_p[i]),
                .IB(i_rx_d_n[i])
            );

            IDDR #(
                .DDR_CLK_EDGE("SAME_EDGE_PIPELINED"),
                .INIT_Q1(1'b0),
                .INIT_Q2(1'b0),
                .SRTYPE("SYNC")
            ) IDDR_d_inst (
                .Q1(d_q1[i]),
                .Q2(d_q2[i]),
                .C(o_clk),
                .CE(1'b1),
                .D(rx_d_se[i]),
                .R(~i_rst_n),
                .S(1'b0)
            );
        end
    endgenerate

    logic [11:0] i_hold, q_hold;

    always_ff @(posedge o_clk, negedge i_rst_n) begin
        if (~i_rst_n) begin
            i_hold <= '0;
            q_hold <= '0;
        end else if (frame_q1) begin
            i_hold[11:6] <= d_q2;
            q_hold[11:6] <= d_q1;
        end else begin
            i_hold[5:0] <= d_q2;
            q_hold[5:0] <= d_q1;
        end
    end

    always_ff @(posedge o_clk, negedge i_rst_n) begin
        if (~i_rst_n) begin
            o_data_i <= '0;
            o_data_q <= '0;
            o_valid  <= 1'b0;
        end else if (~frame_q1) begin
            // LSB half just landed - the full 12-bit sample is complete.
            o_data_i <= {i_hold[11:6], d_q2};
            o_data_q <= {q_hold[11:6], d_q1};
            o_valid  <= 1'b1;
        end else begin
            o_valid <= 1'b0;
        end
    end

endmodule
