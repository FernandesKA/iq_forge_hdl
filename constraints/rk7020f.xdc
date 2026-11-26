## ============================================================
## ------------------------------------------------------------
## Physical constraints -- Tx_D[5:0]
## ------------------------------------------------------------
set_property -dict {PACKAGE_PIN N17 IOSTANDARD LVDS_25} [get_ports {o_tx_d_p[0]}]
set_property -dict {PACKAGE_PIN N18 IOSTANDARD LVDS_25} [get_ports {o_tx_d_n[0]}]
set_property -dict {PACKAGE_PIN P20 IOSTANDARD LVDS_25} [get_ports {o_tx_d_p[1]}]
set_property -dict {PACKAGE_PIN P21 IOSTANDARD LVDS_25} [get_ports {o_tx_d_n[1]}]
set_property -dict {PACKAGE_PIN L17 IOSTANDARD LVDS_25} [get_ports {o_tx_d_p[2]}]
set_property -dict {PACKAGE_PIN M17 IOSTANDARD LVDS_25} [get_ports {o_tx_d_n[2]}]
set_property -dict {PACKAGE_PIN R19 IOSTANDARD LVDS_25} [get_ports {o_tx_d_p[3]}]
set_property -dict {PACKAGE_PIN T19 IOSTANDARD LVDS_25} [get_ports {o_tx_d_n[3]}]
set_property -dict {PACKAGE_PIN K19 IOSTANDARD LVDS_25} [get_ports {o_tx_d_p[4]}]
set_property -dict {PACKAGE_PIN K20 IOSTANDARD LVDS_25} [get_ports {o_tx_d_n[4]}]
set_property -dict {PACKAGE_PIN J16 IOSTANDARD LVDS_25} [get_ports {o_tx_d_p[5]}]
set_property -dict {PACKAGE_PIN J17 IOSTANDARD LVDS_25} [get_ports {o_tx_d_n[5]}]

## ------------------------------------------------------------
## Physical constraints -- Tx_FRAME
## ------------------------------------------------------------
set_property -dict {PACKAGE_PIN R20 IOSTANDARD LVDS_25} [get_ports o_tx_frame_p]
set_property -dict {PACKAGE_PIN R21 IOSTANDARD LVDS_25} [get_ports o_tx_frame_n]

## ------------------------------------------------------------
## Physical constraints -- FB_CLK (forwarded clock, генерируется FPGA)
## ------------------------------------------------------------
set_property -dict {PACKAGE_PIN J21 IOSTANDARD LVDS_25} [get_ports o_fb_clk_p]
set_property -dict {PACKAGE_PIN J22 IOSTANDARD LVDS_25} [get_ports o_fb_clk_n]

## ------------------------------------------------------------
set_property -dict {PACKAGE_PIN M19 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports i_rx_clk_p]
set_property -dict {PACKAGE_PIN M20 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports i_rx_clk_n]
set_property -dict {PACKAGE_PIN N19 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports i_rx_frame_p]
set_property -dict {PACKAGE_PIN N20 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports i_rx_frame_n]
set_property -dict {PACKAGE_PIN P17 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports {i_rx_d_p[0]}]
set_property -dict {PACKAGE_PIN P18 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports {i_rx_d_n[0]}]
set_property -dict {PACKAGE_PIN N22 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports {i_rx_d_p[1]}]
set_property -dict {PACKAGE_PIN P22 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports {i_rx_d_n[1]}]
set_property -dict {PACKAGE_PIN M21 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports {i_rx_d_p[2]}]
set_property -dict {PACKAGE_PIN M22 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports {i_rx_d_n[2]}]
set_property -dict {PACKAGE_PIN J18 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports {i_rx_d_p[3]}]
set_property -dict {PACKAGE_PIN K18 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports {i_rx_d_n[3]}]
set_property -dict {PACKAGE_PIN L21 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports {i_rx_d_p[4]}]
set_property -dict {PACKAGE_PIN L22 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports {i_rx_d_n[4]}]
set_property -dict {PACKAGE_PIN T16 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports {i_rx_d_p[5]}]
set_property -dict {PACKAGE_PIN T17 IOSTANDARD LVDS_25 DIFF_TERM 1} [get_ports {i_rx_d_n[5]}]


## RESETB
set_property -dict {PACKAGE_PIN A16 IOSTANDARD LVCMOS25} [get_ports ad9361_resetb]

## SPI0
set_property -dict {PACKAGE_PIN E18 IOSTANDARD LVCMOS25} [get_ports SPI0_SCLK_O_0]
## AD9361 ENABLE (FMC LA16_P) and TXNRX (FMC LA16_N) - chip enable must be high,
## otherwise the transceiver sits in shutdown and never answers on SPI (see the
## vendor reference fmc_ad9361_7020.xdc: enable=J20, txnrx=K21).
set_property -dict {PACKAGE_PIN J20 IOSTANDARD LVCMOS25} [get_ports ad9361_enable]
set_property -dict {PACKAGE_PIN K21 IOSTANDARD LVCMOS25} [get_ports ad9361_txnrx]
set_property PACKAGE_PIN F18 [get_ports SPI0_SS_O_0]
set_property IOSTANDARD LVCMOS25 [get_ports SPI0_SS_O_0]
set_property PULLTYPE PULLUP [get_ports SPI0_SS_O_0]
set_property -dict {PACKAGE_PIN E21 IOSTANDARD LVCMOS25} [get_ports SPI0_MOSI_O_0]
set_property -dict {PACKAGE_PIN D21 IOSTANDARD LVCMOS25} [get_ports SPI0_MISO_I_0]

## ============================================================
## TIMING CONSTRAINTS
## ============================================================

create_generated_clock -name fb_clk -source [get_pins -hierarchical -filter {NAME =~ "*ad9361_tx/ODDR_fb_clk_inst/C"}] -divide_by 1 -invert [get_ports o_fb_clk_p]

## ------------------------------------------------------------
## Tx_D[5:0] / Tx_FRAME -- output delay относительно FB_CLK.
## ------------------------------------------------------------
set_output_delay -clock fb_clk -max 1.000 [get_ports {{o_tx_d_p[*]} {o_tx_d_n[*]} o_tx_frame_p o_tx_frame_n}]
set_output_delay -clock fb_clk -min 0.000 [get_ports {{o_tx_d_p[*]} {o_tx_d_n[*]} o_tx_frame_p o_tx_frame_n}]

set_output_delay -clock fb_clk -clock_fall -max -add_delay 1.000 [get_ports {{o_tx_d_p[*]} {o_tx_d_n[*]} o_tx_frame_p o_tx_frame_n}]
set_output_delay -clock fb_clk -clock_fall -min -add_delay 0.000 [get_ports {{o_tx_d_p[*]} {o_tx_d_n[*]} o_tx_frame_p o_tx_frame_n}]

set_false_path -hold -from [get_clocks clk_fpga_0] -to [get_clocks fb_clk]

## ------------------------------------------------------------
## RX interface -- RX_CLK is generated by the AD9361 (LVDS DDR,
## 250 MHz => 500 Mbps per lane). Same value as the vendor
## reference fmc_ad9361_7020.xdc: create_clock rx_clk -period 4.
## Without this clock the IDDR inputs are left unconstrained.
## ------------------------------------------------------------
create_clock -name rx_clk -period 4 [get_ports i_rx_clk_p]

## ------------------------------------------------------------
## Rx_D[5:0] / Rx_FRAME -- input delay относительно RX_CLK.
##
## Источник чисел: UG-570 Table 51, "Data Path Timing Constraint
## Values -- LVDS Mode":
##   tDDRx = 0.25 ns (min) .. 1.25 ns (max) -- задержка Rx_D[5:0]
##           от DATA_CLK (RX_CLK) AD9361
##   tDDDV = 0.25 ns (min) .. 1.25 ns (max) -- задержка Rx_FRAME
##           от того же клока
##
## Интерфейс DDR: данные меняются на обоих фронтах RX_CLK, поэтому
## кроме rising-edge наборов нужны копии с -clock_fall -add_delay.
## ------------------------------------------------------------
set_input_delay -clock rx_clk -max 1.250 [get_ports {{i_rx_d_p[*]} {i_rx_d_n[*]} i_rx_frame_p i_rx_frame_n}]
set_input_delay -clock rx_clk -min 0.250 [get_ports {{i_rx_d_p[*]} {i_rx_d_n[*]} i_rx_frame_p i_rx_frame_n}]

set_input_delay -clock rx_clk -clock_fall -max 1.250 -add_delay [get_ports {{i_rx_d_p[*]} {i_rx_d_n[*]} i_rx_frame_p i_rx_frame_n}]
set_input_delay -clock rx_clk -clock_fall -min 0.250 -add_delay [get_ports {{i_rx_d_p[*]} {i_rx_d_n[*]} i_rx_frame_p i_rx_frame_n}]
