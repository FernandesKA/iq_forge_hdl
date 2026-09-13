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
## Physical constraints -- AD9361 RX LVDS interface (Rx_CLK/Rx_FRAME/
## Rx_D[5:0]). Only used for the digital TX->RX loopback verification
## path (ad9361_rx_lvds_wrapper) - not real RX signal reception.
## Pins from the vendor's own reference project for this exact board
## (fmc_ad9361_7020.xdc), same source as the TX pins above, which were
## already cross-checked and matched exactly.
## ------------------------------------------------------------
set_property -dict {PACKAGE_PIN M19 IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports i_rx_clk_p]
set_property -dict {PACKAGE_PIN M20 IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports i_rx_clk_n]
set_property -dict {PACKAGE_PIN N19 IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports i_rx_frame_p]
set_property -dict {PACKAGE_PIN N20 IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports i_rx_frame_n]
set_property -dict {PACKAGE_PIN P17 IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports {i_rx_d_p[0]}]
set_property -dict {PACKAGE_PIN P18 IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports {i_rx_d_n[0]}]
set_property -dict {PACKAGE_PIN N22 IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports {i_rx_d_p[1]}]
set_property -dict {PACKAGE_PIN P22 IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports {i_rx_d_n[1]}]
set_property -dict {PACKAGE_PIN M21 IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports {i_rx_d_p[2]}]
set_property -dict {PACKAGE_PIN M22 IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports {i_rx_d_n[2]}]
set_property -dict {PACKAGE_PIN J18 IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports {i_rx_d_p[3]}]
set_property -dict {PACKAGE_PIN K18 IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports {i_rx_d_n[3]}]
set_property -dict {PACKAGE_PIN L21 IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports {i_rx_d_p[4]}]
set_property -dict {PACKAGE_PIN L22 IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports {i_rx_d_n[4]}]
set_property -dict {PACKAGE_PIN T16 IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports {i_rx_d_p[5]}]
set_property -dict {PACKAGE_PIN T17 IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports {i_rx_d_n[5]}]


## RESETB
set_property -dict {PACKAGE_PIN A16 IOSTANDARD LVCMOS25} [get_ports ad9361_resetb]

## SPI0
set_property -dict {PACKAGE_PIN E18 IOSTANDARD LVCMOS25} [get_ports SPI0_SCLK_O_0]
set_property PACKAGE_PIN F18 [get_ports SPI0_SS_O_0]
set_property IOSTANDARD LVCMOS25 [get_ports SPI0_SS_O_0]
set_property PULLTYPE PULLUP [get_ports SPI0_SS_O_0]
set_property -dict {PACKAGE_PIN E21 IOSTANDARD LVCMOS25} [get_ports SPI0_MOSI_O_0]
set_property -dict {PACKAGE_PIN D21 IOSTANDARD LVCMOS25} [get_ports SPI0_MISO_I_0]

## ============================================================
## TIMING CONSTRAINTS
## ============================================================

## ------------------------------------------------------------
## Системный клок i_clk.
##
## i_clk НЕ является top-level портом -- это внутренний net блочного
## дизайна (PS7 FCLKCLK[0], 40 МГц), поэтому [get_ports i_clk] тут
## всегда резолвился в пустое множество: create_clock/create_generated
## _clock/set_output_delay/set_false_path ниже молча не применялись
## (Vivado выдавал CRITICAL WARNING "No valid object(s) found" в
## runme.log, но report_timing_summary всё равно печатал "All user
## specified timing constraints are met" -- constraints просто не
## существовали). Vivado уже сам авто-создаёт клок "clk_fpga_0" на этом
## net из свойств PS7 -- пересоздавать его нельзя (конфликт), поэтому
## ниже используется он напрямую.
# set_property -dict {PACKAGE_PIN <TODO> IOSTANDARD <TODO>} [get_ports i_clk]

## ------------------------------------------------------------
## FB_CLK -- generated clock, порождённый ODDR внутри ad9361_tx_lvds
## (register-matched pipeline, см. комментарий у ODDR_fb_clk_inst).
## Источник -- C-пин именно этого ODDR (а не [get_ports i_clk], которого
## не существует), но клок на этом пине уже есть (clk_fpga_0), поэтому
## generated_clock корректно строится от него.
## ------------------------------------------------------------
create_generated_clock -name fb_clk -source [get_pins -hierarchical -filter {NAME =~ "*ad9361_tx/ODDR_fb_clk_inst/C"}] -divide_by 1 -invert [get_ports o_fb_clk_p]

## ------------------------------------------------------------
## Tx_D[5:0] / Tx_FRAME -- output delay относительно FB_CLK.
##
## Источник чисел: UG-570 Table 51, "Data Path Timing Constraint
## Values -- LVDS Mode":
##   t_STx = 1.00 ns (min) -- setup Tx_D/Tx_FRAME относительно FALLING
##           edge FB_CLK, на входах AD9361
##   t_HTx = 0.00 ns (min) -- hold, там же
##
## Это требования приёмника (AD9361), измеренные relative к его
## собственному FB_CLK falling edge
## ------------------------------------------------------------
set_output_delay -clock fb_clk -max  1.000 [get_ports {o_tx_d_p[*] o_tx_d_n[*] o_tx_frame_p o_tx_frame_n}]
set_output_delay -clock fb_clk -min  0.000 [get_ports {o_tx_d_p[*] o_tx_d_n[*] o_tx_frame_p o_tx_frame_n}]

set_output_delay -clock fb_clk -clock_fall -max  1.000 -add_delay [get_ports {o_tx_d_p[*] o_tx_d_n[*] o_tx_frame_p o_tx_frame_n}]
set_output_delay -clock fb_clk -clock_fall -min  0.000 -add_delay [get_ports {o_tx_d_p[*] o_tx_d_n[*] o_tx_frame_p o_tx_frame_n}]

## (no hold false-path here -- want the real, computed hold margin for
## this interface, not a blanket exception hiding it)

## ------------------------------------------------------------
## Debug core -- captures ad9361_rx_lvds_wrapper_0's reconstructed I/Q,
## clocked by its own recovered RX clock (a separate domain from
## clk_fpga_0). Used to verify data sent out ad9361_tx_lvds actually
## arrives back correctly via AD9361's internal TX->RX digital loopback
## (ad9361_bist_loopback mode=1) - there's no FPGA-side BIST/DMA
## loopback core on this port, so this is the only way to check that
## bit-exactly instead of only indirectly via the RF spectrum.
## ------------------------------------------------------------
create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 4096 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list system_i/ad9361_rx_lvds_wrapper_0/inst/ad9361_rx_lvds_inst/o_clk]]

set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 12 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list \
    {system_i/ad9361_rx_lvds_wrapper_0/inst/ad9361_rx_lvds_inst/o_data_i[0]} \
    {system_i/ad9361_rx_lvds_wrapper_0/inst/ad9361_rx_lvds_inst/o_data_i[1]} \
    {system_i/ad9361_rx_lvds_wrapper_0/inst/ad9361_rx_lvds_inst/o_data_i[2]} \
    {system_i/ad9361_rx_lvds_wrapper_0/inst/ad9361_rx_lvds_inst/o_data_i[3]} \
    {system_i/ad9361_rx_lvds_wrapper_0/inst/ad9361_rx_lvds_inst/o_data_i[4]} \
    {system_i/ad9361_rx_lvds_wrapper_0/inst/ad9361_rx_lvds_inst/o_data_i[5]} \
    {system_i/ad9361_rx_lvds_wrapper_0/inst/ad9361_rx_lvds_inst/o_data_i[6]} \
    {system_i/ad9361_rx_lvds_wrapper_0/inst/ad9361_rx_lvds_inst/o_data_i[7]} \
    {system_i/ad9361_rx_lvds_wrapper_0/inst/ad9361_rx_lvds_inst/o_data_i[8]} \
    {system_i/ad9361_rx_lvds_wrapper_0/inst/ad9361_rx_lvds_inst/o_data_i[9]} \
    {system_i/ad9361_rx_lvds_wrapper_0/inst/ad9361_rx_lvds_inst/o_data_i[10]} \
    {system_i/ad9361_rx_lvds_wrapper_0/inst/ad9361_rx_lvds_inst/o_data_i[11]} \
]]

create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 12 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list \
    {system_i/ad9361_rx_lvds_wrapper_0/inst/ad9361_rx_lvds_inst/o_data_q[0]} \
    {system_i/ad9361_rx_lvds_wrapper_0/inst/ad9361_rx_lvds_inst/o_data_q[1]} \
    {system_i/ad9361_rx_lvds_wrapper_0/inst/ad9361_rx_lvds_inst/o_data_q[2]} \
    {system_i/ad9361_rx_lvds_wrapper_0/inst/ad9361_rx_lvds_inst/o_data_q[3]} \
    {system_i/ad9361_rx_lvds_wrapper_0/inst/ad9361_rx_lvds_inst/o_data_q[4]} \
    {system_i/ad9361_rx_lvds_wrapper_0/inst/ad9361_rx_lvds_inst/o_data_q[5]} \
    {system_i/ad9361_rx_lvds_wrapper_0/inst/ad9361_rx_lvds_inst/o_data_q[6]} \
    {system_i/ad9361_rx_lvds_wrapper_0/inst/ad9361_rx_lvds_inst/o_data_q[7]} \
    {system_i/ad9361_rx_lvds_wrapper_0/inst/ad9361_rx_lvds_inst/o_data_q[8]} \
    {system_i/ad9361_rx_lvds_wrapper_0/inst/ad9361_rx_lvds_inst/o_data_q[9]} \
    {system_i/ad9361_rx_lvds_wrapper_0/inst/ad9361_rx_lvds_inst/o_data_q[10]} \
    {system_i/ad9361_rx_lvds_wrapper_0/inst/ad9361_rx_lvds_inst/o_data_q[11]} \
]]

create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 1 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list system_i/ad9361_rx_lvds_wrapper_0/inst/ad9361_rx_lvds_inst/o_valid]]

set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets u_ila_0_o_clk]
