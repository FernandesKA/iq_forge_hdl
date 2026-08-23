# build_bitstream.tcl
# Usage: vivado -mode batch -source scripts/build_bitstream.tcl -tclargs <platform> [jobs]

if {$argc > 0} {
    set PLATFORM [lindex $argv 0]
} else {
    set PLATFORM "rk7020f"
}

set JOBS 4
if {$argc > 1} {
    set JOBS [lindex $argv 1]
}

set PROJ_DIR "vivado/$PLATFORM"
set XPR "$PROJ_DIR/dds_tx_chain.xpr"

if {![file exists $XPR]} {
    error "No project found at $XPR. Run ./create_project.sh $PLATFORM first."
}

open_project $XPR

# Zynq FPGA manager wants the headerless .bin, not the raw .bit.
set_property STEPS.WRITE_BITSTREAM.ARGS.BIN_FILE true [get_runs impl_1]

# Retries reset_run once -- a run killed mid-flight can leave itself stuck
# needing a reset that the first reset_run call doesn't clear.
proc reset_and_launch {run jobs args} {
    catch {reset_run $run}
    if {[catch {launch_runs $run -jobs $jobs {*}$args} err]} {
        puts "launch_runs $run failed ($err), retrying reset_run..."
        reset_run $run
        launch_runs $run -jobs $jobs {*}$args
    }
    wait_on_run $run
}

reset_and_launch synth_1 $JOBS

if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    error "Synthesis failed for $PLATFORM -- check $PROJ_DIR/dds_tx_chain.runs/synth_1/runme.log"
}

reset_and_launch impl_1 $JOBS -to_step write_bitstream

if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    error "Implementation/bitstream generation failed for $PLATFORM -- check $PROJ_DIR/dds_tx_chain.runs/impl_1/runme.log"
}

open_run impl_1

set REPORT_DIR "reports/$PLATFORM"
file mkdir $REPORT_DIR
report_timing_summary -file "$REPORT_DIR/timing_summary.rpt"
report_utilization -file "$REPORT_DIR/utilization.rpt"

set BIT [glob -nocomplain "$PROJ_DIR/dds_tx_chain.runs/impl_1/*.bit"]
set BIN [glob -nocomplain "$PROJ_DIR/dds_tx_chain.runs/impl_1/*.bin"]

# Board's fpga_manager wants the .bin byte-swapped per 32-bit word (else:
# "could not find a sync word" in dmesg) -- write a deploy-ready copy.
set DEPLOY_BIN ""
if {$BIN ne ""} {
    set fin [open $BIN rb]
    fconfigure $fin -translation binary
    set data [read $fin]
    close $fin

    if {[string length $data] % 4 == 0} {
        binary scan $data i* words
        set swapped [binary format I* $words]

        set DEPLOY_BIN "$PROJ_DIR/dds_tx_chain.runs/impl_1/[file rootname [file tail $BIN]]_swapped.bin"
        set fout [open $DEPLOY_BIN wb]
        fconfigure $fout -translation binary
        puts -nonewline $fout $swapped
        close $fout
    } else {
        puts "WARNING: $BIN size not a multiple of 4 -- skipped byte-swap"
    }
}

puts "---- DONE. Platform: $PLATFORM ----"
puts "Bitstream:  $BIT"
puts "Deploy bin: $DEPLOY_BIN  (byte-swapped -- copy this one to the board, not the plain .bin)"
puts "Reports:    $REPORT_DIR"
