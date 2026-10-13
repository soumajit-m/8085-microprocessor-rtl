# ==============================================================================
# Xilinx Vivado Synthesis Script for 8085 Microprocessor RTL Core
# ==============================================================================
# Usage:
#   vivado -mode batch -source scripts/synth.tcl
# ==============================================================================

# Target FPGA Part (Xilinx Artix-7 default)
set PART_NAME "xc7a35tcpg236-1"
set TOP_MODULE "core_8085"

puts "=================================================================="
puts "Starting Synthesis for $TOP_MODULE on $PART_NAME"
puts "=================================================================="

# Create in-memory project
create_project -in_memory -part $PART_NAME

# Read design sources
read_verilog [glob -nocomplain src/*.v]

# Run Synthesis
synth_design -top $TOP_MODULE -part $PART_NAME -flatten_hierarchy rebuilt

# Constraint: 100 MHz Clock (10.0 ns period)
create_clock -period 10.000 -name clk [get_ports clk]

# Generate Reports
file mkdir reports
report_utilization -file reports/utilization_synth.rpt
report_timing_summary -file reports/timing_summary_synth.rpt
report_drc -file reports/drc_synth.rpt

# Export Checkpoint and Netlist
file mkdir checkpoints
write_checkpoint -force checkpoints/${TOP_MODULE}_synth.dcp
write_verilog -force -mode synth_stub checkpoints/${TOP_MODULE}_stub.v

puts "=================================================================="
puts "Synthesis Completed Successfully!"
puts "Reports generated in reports/ directory."
puts "=================================================================="
