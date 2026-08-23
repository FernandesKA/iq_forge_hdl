# Usage: vivado -mode batch -source scripts/dump_bd.tcl -tclargs <platform>

if {$argc > 0} {
    set PLATFORM [lindex $argv 0]
} else {
    set PLATFORM "rk7020f"
}

set XPR "vivado/$PLATFORM/dds_tx_chain.xpr"

if {![file exists $XPR]} {
    error "No project found at $XPR. Run ./create_project.sh $PLATFORM first."
}

open_project $XPR

set bd_files [get_files -filter {FILE_TYPE == "Block Designs"}]
if {[llength $bd_files] == 0} {
    error "No block design found in $XPR."
}

open_bd_design [lindex $bd_files 0]

file mkdir dumps
set OUT "dumps/${PLATFORM}_bd_raw.tcl"
write_bd_tcl -force $OUT

puts "---- Dumped block design to $OUT ----"
