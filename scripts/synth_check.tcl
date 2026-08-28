# synth_check.tcl
# Usage: vivado -mode batch -source scripts/synth_check.tcl -tclargs <platform>

if {$argc > 0} {
    set PLATFORM [lindex $argv 0]
} else {
    set PLATFORM "rk7020f"
}

set PART_FILE "platforms/$PLATFORM/part.txt"
if {![file exists $PART_FILE]} {
    error "Unknown platform '$PLATFORM'. No $PART_FILE found."
}
set fh [open $PART_FILE r]
set PART [string trim [read $fh]]
close $fh

set XDC "constraints/$PLATFORM.xdc"

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
