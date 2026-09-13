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
