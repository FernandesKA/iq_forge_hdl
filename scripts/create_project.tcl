# Usage: vivado -mode batch -source scripts/create_project.tcl -tclargs <platform>

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

set XDC      "constraints/$PLATFORM.xdc"
set BD_TCL   "platforms/$PLATFORM/bd.tcl"
set PROJ_DIR "vivado/$PLATFORM"

create_project -force iq_forge_hdl $PROJ_DIR -part $PART

add_files -fileset sources_1 [glob rtl/*.sv rtl/*.v]
set_property top dds_tx_chain [get_filesets sources_1]

if {[file exists $BD_TCL]} {
    set design_name "system"
    create_bd_design $design_name
    source $BD_TCL
    create_root_design ""

    set wrapper [make_wrapper -files [get_files "${design_name}.bd"] -top]
    add_files -norecurse $wrapper

    set_property top [file rootname [file tail $wrapper]] [get_filesets sources_1]
}

add_files -fileset constrs_1 $XDC

update_compile_order -fileset sources_1

puts "---- Project created for platform '$PLATFORM' (part $PART) at $PROJ_DIR/iq_forge_hdl.xpr ----"
