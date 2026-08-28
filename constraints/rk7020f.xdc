## ============================================================
## ------------------------------------------------------------
## Physical constraints -- Tx_D[5:0]
## ------------------------------------------------------------
set_property -dict {PACKAGE_PIN N17 IOSTANDARD LVDS_25} [get_ports {o_tx_d_p[0]}]   ; ## LA11_P
set_property -dict {PACKAGE_PIN N18 IOSTANDARD LVDS_25} [get_ports {o_tx_d_n[0]}]   ; ## LA11_N
set_property -dict {PACKAGE_PIN P20 IOSTANDARD LVDS_25} [get_ports {o_tx_d_p[1]}]   ; ## LA12_P
set_property -dict {PACKAGE_PIN P21 IOSTANDARD LVDS_25} [get_ports {o_tx_d_n[1]}]   ; ## LA12_N
set_property -dict {PACKAGE_PIN L17 IOSTANDARD LVDS_25} [get_ports {o_tx_d_p[2]}]   ; ## LA13_P
set_property -dict {PACKAGE_PIN M17 IOSTANDARD LVDS_25} [get_ports {o_tx_d_n[2]}]   ; ## LA13_N
set_property -dict {PACKAGE_PIN R19 IOSTANDARD LVDS_25} [get_ports {o_tx_d_p[3]}]   ; ## LA10_P
set_property -dict {PACKAGE_PIN T19 IOSTANDARD LVDS_25} [get_ports {o_tx_d_n[3]}]   ; ## LA10_N
set_property -dict {PACKAGE_PIN K19 IOSTANDARD LVDS_25} [get_ports {o_tx_d_p[4]}]   ; ## LA14_P
set_property -dict {PACKAGE_PIN K20 IOSTANDARD LVDS_25} [get_ports {o_tx_d_n[4]}]   ; ## LA14_N
set_property -dict {PACKAGE_PIN J16 IOSTANDARD LVDS_25} [get_ports {o_tx_d_p[5]}]   ; ## LA15_P
set_property -dict {PACKAGE_PIN J17 IOSTANDARD LVDS_25} [get_ports {o_tx_d_n[5]}]   ; ## LA15_N

## ------------------------------------------------------------
## Physical constraints -- Tx_FRAME
## ------------------------------------------------------------
set_property -dict {PACKAGE_PIN R20 IOSTANDARD LVDS_25} [get_ports o_tx_frame_p]    ; ## LA09_P
set_property -dict {PACKAGE_PIN R21 IOSTANDARD LVDS_25} [get_ports o_tx_frame_n]    ; ## LA09_N

## ------------------------------------------------------------
## Physical constraints -- FB_CLK (forwarded clock, генерируется FPGA)
## ------------------------------------------------------------
set_property -dict {PACKAGE_PIN J21 IOSTANDARD LVDS_25} [get_ports o_fb_clk_p]      ; ## LA08_P
set_property -dict {PACKAGE_PIN J22 IOSTANDARD LVDS_25} [get_ports o_fb_clk_n]      ; ## LA08_N


## RESETB
set_property -dict {PACKAGE_PIN A16 IOSTANDARD LVCMOS25} [get_ports ad9361_resetb]  ; ## LA28_P

## SPI0
set_property -dict {PACKAGE_PIN E18 IOSTANDARD LVCMOS25}                 [get_ports SPI0_SCLK_O_0]  ; ## LA26_N
set_property -dict {PACKAGE_PIN F18 IOSTANDARD LVCMOS25 PULLTYPE PULLUP} [get_ports SPI0_SS_O_0]    ; ## LA26_P
set_property -dict {PACKAGE_PIN E21 IOSTANDARD LVCMOS25}                 [get_ports SPI0_MOSI_O_0]  ; ## LA27_P
set_property -dict {PACKAGE_PIN D21 IOSTANDARD LVCMOS25}                 [get_ports SPI0_MISO_I_0]  ; ## LA27_N

## ============================================================
## TIMING CONSTRAINTS
## ============================================================

## ------------------------------------------------------------
## Системный клок i_clk.
create_clock -name i_clk -period 25.000 [get_ports i_clk]
# set_property -dict {PACKAGE_PIN <TODO> IOSTANDARD <TODO>} [get_ports i_clk]

## ------------------------------------------------------------
## FB_CLK -- generated clock, порождённый ODDR внутри fb_clk_gen.
## ------------------------------------------------------------
create_generated_clock -name fb_clk \
    -source [get_ports i_clk] \
    -divide_by 1 \
    -invert \
    [get_ports o_fb_clk_p]

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

set_false_path -hold -from [get_clocks i_clk] -to [get_clocks fb_clk]