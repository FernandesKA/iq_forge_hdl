`timescale 1ns/1ns

module ad9361_rx_lvds_wrapper (
    input  wire       i_clk_p,
    input  wire       i_clk_n,
    input  wire       i_rst_n,
    input  wire       i_rx_frame_p,
    input  wire       i_rx_frame_n,
    input  wire [5:0] i_rx_d_p,
    input  wire [5:0] i_rx_d_n,
    output wire        o_clk,
    output wire [11:0] o_data_i,
    output wire [11:0] o_data_q,
    output wire         o_valid
);

    ad9361_rx_lvds ad9361_rx_lvds_inst (
        .i_clk_p(i_clk_p),
        .i_clk_n(i_clk_n),
        .i_rst_n(i_rst_n),
        .i_rx_frame_p(i_rx_frame_p),
        .i_rx_frame_n(i_rx_frame_n),
        .i_rx_d_p(i_rx_d_p),
        .i_rx_d_n(i_rx_d_n),
        .o_clk(o_clk),
        .o_data_i(o_data_i),
        .o_data_q(o_data_q),
        .o_valid(o_valid)
    );

endmodule
