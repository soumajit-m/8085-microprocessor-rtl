#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "========================================"
echo "   8085 Verilog Core - Simulation Runner"
echo "========================================"

# Check if Icarus Verilog is installed
if ! command -v iverilog &> /dev/null; then
    echo "Error: Icarus Verilog (iverilog) is not installed or not in your system PATH."
    echo "Please install it to run these simulations:"
    echo "  - Windows: Download from https://bleyer.org/icarus/"
    echo "  - macOS: brew install icarus-verilog"
    echo "  - Linux: sudo apt install iverilog"
    echo "========================================"
    exit 1
fi

# Check if a testbench name was provided
if [ -z "$1" ]; then
    echo "Usage: ./run.sh <testbench_name>"
    echo "Available testbenches in testbench/ directory:"
    echo "  1) tb_core_basic"
    echo "  2) tb_core_16bit"
    echo "  3) tb_core_stack_branch"
    echo "  4) tb_core_sys_io"
    echo ""
    echo "Example: ./run.sh tb_core_basic"
    exit 1
fi

TB_NAME=$1

# Check if the testbench file exists
if [ ! -f "testbench/${TB_NAME}.v" ]; then
    echo "Error: Testbench testbench/${TB_NAME}.v not found!"
    exit 1
fi

echo ">> Compiling source files and ${TB_NAME}.v..."
# Compile all source files and the selected testbench using Icarus Verilog
iverilog -o ${TB_NAME}.vvp src/*.v testbench/${TB_NAME}.v

echo ">> Running simulation..."
# Run the simulation
vvp ${TB_NAME}.vvp

echo "========================================"
echo ">> Simulation complete."
echo ">> The waveform file (${TB_NAME}.vcd) has been generated."
echo ">> To view the waveform, run: gtkwave ${TB_NAME}.vcd"