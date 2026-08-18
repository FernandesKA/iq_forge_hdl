# synth_check.tcl
# Usage: vivado -mode batch -source scripts/synth_check.tcl -tclargs <platform>

if {$argc > 0} {
    set PLATFORM [lindex $argv 0]
} else {
    set PLATFORM "rk7020f"
}

array set PART_OF {
    rk7020f    xc7z020clg484-2
    pluto_sky  xc7z020clg400-2
}

if {![info exists PART_OF($PLATFORM)]} {
    error "Unknown platform '$PLATFORM'. Known platforms: [array names PART_OF]"
}

set PART $PART_OF($PLATFORM)
set XDC "constraints/$PLATFORM/dds_tx_chain.xdc"

file mkdir reports

read_verilog -sv [glob rtl/*.sv]
read_xdc $XDC

synth_design -top dds_tx_chain -part $PART

opt_design
place_design
route_design

report_timing_summary -file reports/timing_summary_route.rpt

report_timing -hold -max_paths 20 -sort_by group \
    -file reports/hold_paths_route.rpt

report_utilization -file reports/utilization_route.rpt

puts "---- ODDR instances found in design ----"
foreach cell [get_cells -hier -filter {REF_NAME == ODDR}] {
    puts $cell
}

puts "---- DONE. Platform: $PLATFORM, Part: $PART. Check reports/ for details (timing_summary_route.rpt is the trustworthy one), and console output above for warnings/errors. ----"
