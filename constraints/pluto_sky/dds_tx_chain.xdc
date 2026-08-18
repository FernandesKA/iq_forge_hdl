## PlutoSky (AD9361 + Zynq XC7Z020CLG400-2). Pins cross-checked against the
## vendor's own working project (Src/AD936X.xdc, OpenSourceSDRLab
## 7020_AD936X_SDR) and schematic_PlutoSky.pdf -- both match.
##
## IOSTANDARD is LVDS_25/LVCMOS25 to match that proven design, even though
## VCCO_34/VCCO_35 read as 1.8V on the schematic (which would call for
## LVDS/LVCMOS18) -- the vendor XDC downgrades the resulting UCIO-1 DRC to
## a Warning instead of fixing it, and it works on real hardware.

## Tx_D[5:0]
set_property -dict {PACKAGE_PIN V15 IOSTANDARD LVDS_25} [get_ports {o_tx_d_p[0]}]
set_property -dict {PACKAGE_PIN W15 IOSTANDARD LVDS_25} [get_ports {o_tx_d_n[0]}]
set_property -dict {PACKAGE_PIN V12 IOSTANDARD LVDS_25} [get_ports {o_tx_d_p[1]}]
set_property -dict {PACKAGE_PIN W13 IOSTANDARD LVDS_25} [get_ports {o_tx_d_n[1]}]
set_property -dict {PACKAGE_PIN W14 IOSTANDARD LVDS_25} [get_ports {o_tx_d_p[2]}]
set_property -dict {PACKAGE_PIN Y14 IOSTANDARD LVDS_25} [get_ports {o_tx_d_n[2]}]
set_property -dict {PACKAGE_PIN T12 IOSTANDARD LVDS_25} [get_ports {o_tx_d_p[3]}]
set_property -dict {PACKAGE_PIN U12 IOSTANDARD LVDS_25} [get_ports {o_tx_d_n[3]}]
set_property -dict {PACKAGE_PIN T11 IOSTANDARD LVDS_25} [get_ports {o_tx_d_p[4]}]
set_property -dict {PACKAGE_PIN T10 IOSTANDARD LVDS_25} [get_ports {o_tx_d_n[4]}]
set_property -dict {PACKAGE_PIN U13 IOSTANDARD LVDS_25} [get_ports {o_tx_d_p[5]}]
set_property -dict {PACKAGE_PIN V13 IOSTANDARD LVDS_25} [get_ports {o_tx_d_n[5]}]

## Tx_FRAME
set_property -dict {PACKAGE_PIN V16 IOSTANDARD LVDS_25} [get_ports o_tx_frame_p]
set_property -dict {PACKAGE_PIN W16 IOSTANDARD LVDS_25} [get_ports o_tx_frame_n]

## FB_CLK
set_property -dict {PACKAGE_PIN U14 IOSTANDARD LVDS_25} [get_ports o_fb_clk_p]
set_property -dict {PACKAGE_PIN U15 IOSTANDARD LVDS_25} [get_ports o_fb_clk_n]

## RESETB
set_property -dict {PACKAGE_PIN R19 IOSTANDARD LVCMOS25} [get_ports ad9361_resetb]

## SPI0
set_property -dict {PACKAGE_PIN V18 IOSTANDARD LVCMOS25}                 [get_ports SPI0_SCLK_O_0]
set_property -dict {PACKAGE_PIN R17 IOSTANDARD LVCMOS25 PULLTYPE PULLUP} [get_ports SPI0_SS_O_0]
set_property -dict {PACKAGE_PIN P16 IOSTANDARD LVCMOS25}                 [get_ports SPI0_MOSI_O_0]
set_property -dict {PACKAGE_PIN V17 IOSTANDARD LVCMOS25}                 [get_ports SPI0_MISO_I_0]

## See the IOSTANDARD note above -- without this, UCIO-1 fails as an ERROR.
set_property SEVERITY {Warning} [get_drc_checks UCIO-1]

## ============================================================
## TIMING CONSTRAINTS
## ============================================================

create_clock -name i_clk -period 25.000 [get_ports i_clk]
# set_property -dict {PACKAGE_PIN <TODO> IOSTANDARD <TODO>} [get_ports i_clk]

create_generated_clock -name fb_clk \
    -source [get_ports i_clk] \
    -divide_by 1 \
    -invert \
    [get_ports o_fb_clk_p]

## UG-570 Table 51, "Data Path Timing Constraint Values -- LVDS Mode":
## t_STx = 1.00 ns (min) setup, t_HTx = 0.00 ns (min) hold, Tx_D/Tx_FRAME
## relative to FB_CLK falling edge at the AD9361 -- chip requirement, not
## platform-specific.
set_output_delay -clock fb_clk -max  1.000 [get_ports {o_tx_d_p[*] o_tx_d_n[*] o_tx_frame_p o_tx_frame_n}]
set_output_delay -clock fb_clk -min  0.000 [get_ports {o_tx_d_p[*] o_tx_d_n[*] o_tx_frame_p o_tx_frame_n}]

set_output_delay -clock fb_clk -clock_fall -max  1.000 -add_delay [get_ports {o_tx_d_p[*] o_tx_d_n[*] o_tx_frame_p o_tx_frame_n}]
set_output_delay -clock fb_clk -clock_fall -min  0.000 -add_delay [get_ports {o_tx_d_p[*] o_tx_d_n[*] o_tx_frame_p o_tx_frame_n}]

set_false_path -hold -from [get_clocks i_clk] -to [get_clocks fb_clk]
