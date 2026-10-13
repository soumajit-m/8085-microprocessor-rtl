# ==============================================================================
# Xilinx Vivado Behavioral Simulation TCL Script for 8085 Core
# ==============================================================================
# Usage:
#   vivado -mode batch -source scripts/sim.tcl -tclargs tb_core_basic
# ==============================================================================

set TB_NAME "tb_core_basic"
if { $argc > 0 } {
    set TB_NAME [lindex $argv 0]
}

puts "=================================================================="
puts "Starting Vivado Simulation for: $TB_NAME"
puts "=================================================================="

# Create simulation in-memory project
create_project -in_memory -part xc7a35tcpg236-1

# Read all RTL sources and specified testbench
read_verilog [glob -nocomplain src/*.v]
read_verilog "testbench/${TB_NAME}.v"

# Set top simulation module
set_property top $TB_NAME [get_filesets sim_1]

# Run behavioral simulation
launch_simulation -mode behavioral

# Run simulation until completion
run all

puts "=================================================================="
puts "Simulation for $TB_NAME finished!"
puts "=================================================================="
