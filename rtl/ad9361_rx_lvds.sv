`timescale 1ns/1ns

// Receives the AD9361 RX LVDS digital interface. Mirror image of
// ad9361_tx_lvds.sv: that module launches, per i_clk period, tx_i_slice
// on the ODDR's D1 (first half of the period) and tx_q_slice on D2
// (second half), with o_tx_frame_p high marking the MSB (upper 6 bits)
// half and low marking the LSB half. IDDR in SAME_EDGE_PIPELINED mode
// naturally re-aligns both edges' captured bits together at one rising
// clock edge - Q1 lands on the same "D1/first-half" timing as the
// transmitter's I-slice, Q2 on the "D2/second-half" timing as the
// Q-slice - so this is a direct structural mirror of the TX side, not a
// re-derivation of the bit convention.
//
// Built to verify, via AD9361's own internal TX->RX digital loopback
// (ad9361_bist_loopback mode=1 / DATA_PORT_LOOP_TEST_ENABLE), that data
// sent out ad9361_tx_lvds actually arrives at the chip correctly -
// there is no FPGA-side BIST/DMA loopback core on this port
// (ad9361_dig_tune/ad9361_hdl_loopback are stubbed), so this is the only
// way to get a bit-level answer instead of an indirect RF-spectrum one.
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

    // frame_q1 high = this period carried the MSB (upper 6 bits) half,
    // matching o_tx_frame_p on the TX side.
    //
    // d_q1/d_q2 -> Q/I (not I/Q): empirically confirmed by
    // ad9361_rx_lvds_tb.sv (back-to-back loopback against
    // ad9361_tx_lvds) - o_clk's rising edge (IDDR's sampling edge) lands
    // on the fb_clk_p rising transition, which is the ad9361_tx_lvds.sv
    // D1->D2 midpoint, so what IDDR presents as "Q1" (last-sampled-value
    // going into this edge) is actually the tx_q_slice/D2 half, and "Q2"
    // (this edge's fresh sample) is the following period's
    // tx_i_slice/D1 half - opposite of the naive first-half/second-half
    // reading.
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
