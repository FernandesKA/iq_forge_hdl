`timescale 1ns/1ns

module ad9361_rx_lvds (
    input logic i_clk_p,
    input logic i_clk_n,
    input logic i_rst_n,
    input logic i_rx_frame_p,
    input logic i_rx_frame_n,
    input logic [5:0] i_rx_d_p,
    input logic [5:0] i_rx_d_n,
    output logic o_clk,
    output logic [11:0] o_data_i,
    output logic [11:0] o_data_q
); 



endmodule