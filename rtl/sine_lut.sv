module sine_lut  #(
    parameter int ACC_WIDTH = 24,
    parameter int LUT_ADDR_WIDTH = 10,
    parameter int DATA_WIDTH = 12
) (
    input logic i_clk,
    input logic i_rst_n,
    input logic [ACC_WIDTH - 1 : 0] i_phase,
    output logic signed  [DATA_WIDTH - 1 : 0] o_amplitude
);

    logic [LUT_ADDR_WIDTH - 1 : 0] bram_addr;
    assign bram_addr = i_phase[ACC_WIDTH - 1 -: LUT_ADDR_WIDTH];



endmodule