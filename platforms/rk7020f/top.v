`timescale 1 ps / 1 ps

  // Expose PS GPIO EMIO as AD9361 enable/txnrx. RESETB is driven by the
  // AXI GPIO reset register so software can perform a real hardware reset.
module top (
  inout [14:0] DDR_addr, inout [2:0] DDR_ba, inout DDR_cas_n,
  inout DDR_ck_n, inout DDR_ck_p, inout DDR_cke, inout DDR_cs_n,
  inout [3:0] DDR_dm, inout [31:0] DDR_dq, inout [3:0] DDR_dqs_n,
  inout [3:0] DDR_dqs_p, inout DDR_odt, inout DDR_ras_n,
  inout DDR_reset_n, inout DDR_we_n, inout FIXED_IO_ddr_vrn,
  inout FIXED_IO_ddr_vrp, inout [53:0] FIXED_IO_mio,
  inout FIXED_IO_ps_clk, inout FIXED_IO_ps_porb, inout FIXED_IO_ps_srstb,
  input SPI0_MISO_I_0, output SPI0_MOSI_O_0, output SPI0_SCLK_O_0,
  output SPI0_SS_O_0, output ad9361_enable, output ad9361_resetb,
  output ad9361_txnrx, input i_rx_clk_n, input i_rx_clk_p,
  input [5:0] i_rx_d_n, input [5:0] i_rx_d_p, input i_rx_frame_n,
  input i_rx_frame_p, output o_fb_clk_n, output o_fb_clk_p,
  output [5:0] o_tx_d_n, output [5:0] o_tx_d_p,
  output o_tx_frame_n, output o_tx_frame_p
);
  wire [63:0] gpio_i, gpio_o, gpio_t;
  assign gpio_i = gpio_o;

  system_wrapper u_system (
    .DDR_addr(DDR_addr), .DDR_ba(DDR_ba), .DDR_cas_n(DDR_cas_n),
    .DDR_ck_n(DDR_ck_n), .DDR_ck_p(DDR_ck_p), .DDR_cke(DDR_cke),
    .DDR_cs_n(DDR_cs_n), .DDR_dm(DDR_dm), .DDR_dq(DDR_dq),
    .DDR_dqs_n(DDR_dqs_n), .DDR_dqs_p(DDR_dqs_p), .DDR_odt(DDR_odt),
    .DDR_ras_n(DDR_ras_n), .DDR_reset_n(DDR_reset_n), .DDR_we_n(DDR_we_n),
    .FIXED_IO_ddr_vrn(FIXED_IO_ddr_vrn), .FIXED_IO_ddr_vrp(FIXED_IO_ddr_vrp),
    .FIXED_IO_mio(FIXED_IO_mio), .FIXED_IO_ps_clk(FIXED_IO_ps_clk),
    .FIXED_IO_ps_porb(FIXED_IO_ps_porb), .FIXED_IO_ps_srstb(FIXED_IO_ps_srstb),
    .SPI0_MISO_I_0(SPI0_MISO_I_0), .SPI0_MOSI_O_0(SPI0_MOSI_O_0),
    .SPI0_SCLK_O_0(SPI0_SCLK_O_0), .SPI0_SS_O_0(SPI0_SS_O_0),
    .ad9361_enable(ad9361_enable), .ad9361_resetb(ad9361_resetb),
    .ad9361_txnrx(ad9361_txnrx), .gpio_i(gpio_i), .gpio_o(gpio_o),
    .gpio_t(gpio_t), .i_rx_clk_n(i_rx_clk_n), .i_rx_clk_p(i_rx_clk_p),
    .i_rx_d_n(i_rx_d_n), .i_rx_d_p(i_rx_d_p), .i_rx_frame_n(i_rx_frame_n),
    .i_rx_frame_p(i_rx_frame_p), .o_fb_clk_n(o_fb_clk_n),
    .o_fb_clk_p(o_fb_clk_p), .o_tx_d_n(o_tx_d_n), .o_tx_d_p(o_tx_d_p),
    .o_tx_frame_n(o_tx_frame_n), .o_tx_frame_p(o_tx_frame_p)
  );
endmodule
