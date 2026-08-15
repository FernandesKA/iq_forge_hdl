# synth_check.tcl

set PART "xc7z020clg484-2"

file mkdir reports

read_verilog -sv [glob rtl/*.sv]
read_xdc constraints/dds_tx_chain.xdc

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

puts "---- DONE. Check reports/ for details (timing_summary_route.rpt is the trustworthy one), and console output above for warnings/errors. ----"