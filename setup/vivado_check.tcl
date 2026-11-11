# Vivado installation check for the FPGA_ROUTE labs.
#
# Usage (Ubuntu, after sourcing settings64.sh):
#     cd <repo>/setup
#     vivado -mode batch -source vivado_check.tcl
# Usage (Windows, in "Vivado 2023.1 Tcl Shell"):
#     cd C:/path/to/FPGA_ROUTE/setup
#     source vivado_check.tcl
#
# Checks:
#   1. Vivado version (the labs assume 2023.1)
#   2. XCZU5EV and XCZU4EV device libraries are installed
#   3. A small synthesis run on XCZU5EV succeeds (device and free license OK)
# Prints "CHECK PASSED" at the end when everything succeeds.
# This file is ASCII-only on purpose, so the Windows console shows it correctly.

set ok 1
set script_dir [file dirname [file normalize [info script]]]

# 1. Version
set ver [version -short]
puts "INFO: Vivado version: $ver"
if {$ver ne "2023.1"} {
    puts "WARN: the labs assume Vivado 2023.1, found $ver"
}

# 2. Device libraries
foreach fam {xczu5ev xczu4ev} {
    set parts [get_parts -quiet "${fam}*"]
    if {[llength $parts] == 0} {
        puts "ERROR: no $fam parts installed. Re-run the installer and select Zynq UltraScale+ MPSoC."
        set ok 0
    } else {
        puts "INFO: $fam: [llength $parts] parts installed, e.g. [lindex $parts 0]"
    }
}

# 3. Synthesis test on XCZU5EV with the counter from s1/01_first_tb
set src [file join $script_dir .. s1 01_first_tb counter.v]
set parts [get_parts -quiet "xczu5ev*"]
if {![file exists $src]} {
    puts "ERROR: cannot find $src. Run this script from the setup directory of the repository."
    set ok 0
} elseif {[llength $parts] > 0} {
    set part [lindex $parts 0]
    puts "INFO: synthesizing counter.v for $part ..."
    if {[catch {
        read_verilog $src
        synth_design -top counter -part $part -mode out_of_context
    } err]} {
        puts "ERROR: synthesis failed: $err"
        puts "ERROR: if the message mentions a license, the device is not covered by the installed edition."
        set ok 0
    } else {
        puts "INFO: synthesis finished. Utilization summary:"
        report_utilization
    }
}

if {$ok} {
    puts "CHECK PASSED"
} else {
    puts "CHECK FAILED"
}
