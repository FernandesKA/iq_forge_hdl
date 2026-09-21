`timescale  1ns/1ns

module dds_tx_chain_wrapper #(
    parameter ACC_WIDTH      = 24,
    parameter LUT_ADDR_WIDTH = 10
) (
    input  wire                        i_clk,
    input  wire                        i_rst_n,
    input  wire                        i_en,
    input  wire                        i_mode,
    input  wire [ACC_WIDTH - 1 : 0]    i_ftw,
    input  wire                        i_lfm_continious,
    input  wire                        i_lfm_load,
    input  wire [ACC_WIDTH - 1 : 0]    i_lfm_ftw_start,
    input  wire [ACC_WIDTH - 1 : 0]    i_lfm_ftw_stop,
    input  wire [ACC_WIDTH - 1 : 0]    i_lfm_ftw_incr,
    output wire [5:0]                  o_tx_d_p,
    output wire [5:0]                  o_tx_d_n,
    output wire                        o_tx_frame_p,
    output wire                        o_tx_frame_n,
    output wire                        o_fb_clk_p,
    output wire                        o_fb_clk_n
);

    dds_tx_chain #(
        .ACC_WIDTH(ACC_WIDTH),
        .LUT_ADDR_WIDTH(LUT_ADDR_WIDTH)
    ) dds_tx_chain_inst (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_en(i_en),
        .i_mode(i_mode),
        .i_ftw(i_ftw),
        .i_lfm_continious(i_lfm_continious),
        .i_lfm_load(i_lfm_load),
        .i_lfm_ftw_start(i_lfm_ftw_start),
        .i_lfm_ftw_stop(i_lfm_ftw_stop),
        .i_lfm_ftw_incr(i_lfm_ftw_incr),
        .o_tx_d_p(o_tx_d_p),
        .o_tx_d_n(o_tx_d_n),
        .o_tx_frame_p(o_tx_frame_p),
        .o_tx_frame_n(o_tx_frame_n),
        .o_fb_clk_p(o_fb_clk_p),
        .o_fb_clk_n(o_fb_clk_n)
    );

endmodule