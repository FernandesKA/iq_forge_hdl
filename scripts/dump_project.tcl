# Usage: vivado -mode batch -source scripts/dump_project.tcl -tclargs <platform>

if {$argc > 0} {
    set PLATFORM [lindex $argv 0]
} else {
    set PLATFORM "rk7020f"
}

set XPR "vivado/$PLATFORM/iq_forge_hdl.xpr"

if {![file exists $XPR]} {
    error "No project found at $XPR. Run ./create_project.sh $PLATFORM first."
}

open_project $XPR

file mkdir dumps
set OUT "dumps/${PLATFORM}.tcl"

write_project_tcl -force $OUT

puts "---- Dumped current project state to $OUT ----"
puts "---- Diff it against scripts/create_project.tcl and merge over anything new (IP, properties, filesets, ...) ----"
