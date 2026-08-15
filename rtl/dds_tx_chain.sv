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

    logic signed [DATA_WIDTH - 1 : 0] tx_i, tx_q;

    always_comb begin : out_muxer
        if (i_en) begin
            tx_i = sine_i;
            tx_q = sine_q;
        end else begin
            tx_i = 0;
            tx_q = 0;
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