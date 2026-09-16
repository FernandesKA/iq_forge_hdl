`timescale 1ns/1ns

module dds_tx_chain #(
    parameter ACC_WIDTH = 24,
    parameter LUT_ADDR_WIDTH = 10
) (
    input i_clk,
    input i_rst_n,
    input i_en,
    input [ACC_WIDTH - 1 : 0] i_ftw,
    output logic [5:0] o_tx_d_p,
    output logic [5:0] o_tx_d_n,
    output logic o_tx_frame_p,
    output logic o_tx_frame_n,
    output logic o_fb_clk_p,
    output logic o_fb_clk_n
);

    logic [ACC_WIDTH - 1 : 0] phase;
    logic lvds_phase_sel;

    phase_acc #(.ACC_WIDTH(ACC_WIDTH)) ph_acc(
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_ce(i_en & lvds_phase_sel),
        .i_ftw(i_ftw),
        .o_phase(phase)
    );

    localparam DATA_WIDTH = 12;
    logic signed [DATA_WIDTH - 1 : 0] sine_i, sine_q;

    sine_lut #(.ACC_WIDTH(ACC_WIDTH), .LUT_ADDR_WIDTH(LUT_ADDR_WIDTH)) sine (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_phase(phase),
        .o_i(sine_i),
        .o_q(sine_q)
    );

    logic signed [DATA_WIDTH - 1 : 0] tx_i_comb, tx_q_comb;

    always_comb begin : out_muxer
        if (i_en) begin
            tx_i_comb = sine_i;
            tx_q_comb = sine_q;
        end else begin
            tx_i_comb = 0;
            tx_q_comb = 0;
        end
    end

    // One extra pipeline stage before ad9361_tx_lvds: at higher i_clk
    // rates, the combinational chain from sine_lut's BRAM-registered
    // output through the sign-invert and out_muxer straight into
    // ad9361_tx_lvds's live-i_tx_q path (see the comment there) is too
    // slow to settle in time for the ODDR (confirmed as a real setup
    // violation at 125 MHz, 22 failing paths, WNS -2.042ns). This adds
    // a uniform 1-cycle delay to tx_i/tx_q, which is safe precisely
    // because it's uniform: ad9361_tx_lvds's hold-vs-live split only
    // depends on tx_i/tx_q changing at a consistent phase_sel-relative
    // boundary, not on the absolute latency getting there, and
    // phase_sel itself isn't touched, so that relationship is
    // preserved. (Registering the sign-invert result inside sine_lut
    // was considered too - functionally equivalent, placed here
    // instead since dds_tx_chain owns the DDR-side interface timing
    // budget, not sine_lut.)
    logic signed [DATA_WIDTH - 1 : 0] tx_i, tx_q;

    always_ff @(posedge i_clk, negedge i_rst_n) begin
        if (~i_rst_n) begin
            tx_i <= '0;
            tx_q <= '0;
        end else begin
            tx_i <= tx_i_comb;
            tx_q <= tx_q_comb;
        end
    end

    ad9361_tx_lvds ad9361_tx (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_tx_i(tx_i),
        .i_tx_q(tx_q),
        .o_tx_d_p(o_tx_d_p),
        .o_tx_d_n(o_tx_d_n),
        .o_tx_frame_p(o_tx_frame_p),
        .o_tx_frame_n(o_tx_frame_n),
        .o_fb_clk_p(o_fb_clk_p),
        .o_fb_clk_n(o_fb_clk_n),
        .o_phase_sel(lvds_phase_sel)
    );

endmodule