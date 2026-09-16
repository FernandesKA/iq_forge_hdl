`timescale  1ns/1ns

module seq_core #(
    parameter BRAM_WIDTH = 64,
    parameter CMD_WIDTH = 8,
    parameter ARG_WIDTH = 32,
    parameter DATA_WIDTH = 12
) (
    input logic i_clk,
    input logic i_rst_n,
    output logic [DATA_WIDTH - 1 : 0] out_i,
    output logic [DATA_WIDTH - 1 : 0] out_q
);




endmodule
