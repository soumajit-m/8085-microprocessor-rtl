# 8085 Microprocessor RTL Core

A fully synthesizable, cycle-accurate RTL implementation of the classic Intel 8085 8-bit microprocessor written in Verilog. This core was engineered from the ground up to support the complete 8085 instruction set, featuring authentic multi-cycle execution, hardware bus multiplexing, and integrated 16-bit datapath operations.

## About the Intel 8085

The Intel 8085 is a historic 8-bit microprocessor introduced by Intel in 1976. It features an 8-bit data bus, a 16-bit address bus capable of accessing up to 64 KB of memory, and a classic CISC (Complex Instruction Set Computer) architecture. 

One of its defining hardware features—which is faithfully reproduced in this Verilog core—is the multiplexed address and data bus (`AD0-AD7`). To reduce the physical pin count on the silicon package, the lower 8 bits of the address and the 8 bits of data share the same pins, requiring an Address Latch Enable (`ALE`) signal to separate them during operation. Because of its elegant design, precise multi-cycle timing, and manageable instruction set, building an 8085 from scratch remains a gold-standard benchmark for mastering digital logic design, control state machines, and computer architecture.

---

## Technical Highlights

* **Complete ISA Support:** Explicitly decodes and executes all 246 valid 8085 opcodes, gracefully defaulting to `NOP` for invalid instructions.
* **Authentic Bus Multiplexing:** Accurately replicates the physical hardware interface. It drives the upper address on `A8-A15` and actively multiplexes the lower address and data on a bidirectional `AD0-AD7` bus, synchronized by the `ALE` strobe.
* **Cycle-Accurate FSM:** A highly optimized control unit manages execution across distinct machine cycles (Fetch, Memory Read, Memory Write, I/O Read, I/O Write, Halt, INTA) with precise T-state sequencing.
* **Native 16-bit Operations:** The register file internally handles 16-bit pointer arithmetic (`INX`, `DCX`, `DAD`), reducing bottlenecking on the 8-bit ALU.

---

## Hardware Architecture

The core is modularized into several key datapaths and control units:

* **`core_8085.v` (Top Level):** Integrates all modules, manages the tri-state bidirectional `AD` bus, and coordinates the execution strobes to prevent continuous write corruption during multi-cycle instructions.
* **`control_fsm.v`:** The heartbeat of the processor. It routes instructions through `M1` (Opcode Fetch) and subsequent read/write machine cycles, handling 2-byte and 3-byte operand fetching seamlessly.
* **`instr_decoder.v`:** A massive combinational block mapping all 246 opcodes to control signals, including specialized routing for conditional branches and I/O requests.
* **`reg_file.v`:** Houses the standard 8085 registers (A, B, C, D, E, H, L). Features priority override logic for 16-bit pair writing (e.g., `LXI`, `POP`) and double-addition (`DAD`).
* **`alu.v`:** Executes 8-bit arithmetic and logic. Includes custom internal carry generation for accumulator specials (e.g., `RLC`, `RAR`, `STC`, `CMC`).
* **`flag_reg.v`:** Maintains the Program Status Word (PSW), correctly formatting the `S`, `Z`, `AC`, `P`, and `CY` flags according to 8085 specifications.
* **`stack_pointer.v` & `addr_mux.v`:** A dedicated 16-bit UP/DOWN counter for stack tracking, and a multiplexer to route the correct 16-bit address (PC, HL, SP, or temporary WZ pair) to the external pins.

---

## Verification & Simulation Suites

The `tb/` directory contains isolated, system-level testbenches. Each testbench instantiates the core alongside a 74LS373 transparent address latch emulator and a simulated 64KB memory array. 

### 1. Basic Operations (`tb_core_basic.v`)
Validates the fundamental 8-bit datapath.
* **Tested:** `MVI`, `MOV`, `ADD`, `SUB`, `INR`, `DCR`, `ANA`, `HLT`.
* **Mechanism:** Pre-loads a short assembly program that increments/decrements registers, performs arithmetic, and checks flag updates.

### 2. 16-bit & Memory Pointers (`tb_core_16bit.v`)
Verifies multi-byte memory writes and 16-bit register pair math.
* **Tested:** `LXI`, `DAD`, `INX`, `SHLD`.
* **Mechanism:** Loads 16-bit addresses into B and H, executes double-addition, increments the pointer, and uses `SHLD` to write a 16-bit word across two memory boundaries. 

### 3. Stack & Conditional Branching (`tb_core_stack_branch.v`)
Ensures the stack pointer operates correctly during context switching and that conditional flags accurately trigger jumps.
* **Tested:** `JNZ`, `CALL`, `RET`, `PUSH`, `POP`, `DCR`.
* **Mechanism:** Executes an active loop bounded by `JNZ`. Once the accumulator reaches zero, it calls a subroutine that pushes and pops registers to the stack before returning.

### 4. System & I/O (`tb_core_sys_io.v`)
Tests accumulator specials and the `IO/M` hardware pin behavior.
* **Tested:** `STC`, `CMC`, `CMA`, `RLC`, `OUT`, `IN`.
* **Mechanism:** Rotates and complements data in the accumulator, writes it to simulated hardware Port `0x01`, and reads returning data from Port `0x02`, validating the active-high `IO/M` signal.

---

## Getting Started

### Prerequisites
This project uses standard Verilog-2001. You can simulate it using:
* [Icarus Verilog](http://iverilog.icarus.com/) & GTKWave (Open Source)
* Xilinx Vivado / AMD Vitis
* Intel Quartus Prime

### Running a Simulation

**Option 1: Automated Script (Recommended)**
If you are on Linux, macOS, or using Git Bash on Windows, you can use the included `run.sh` script to automatically compile and execute any testbench:

```bash
# Make the script executable (first time only)
chmod +x run.sh

# Run a specific testbench (e.g., the 16-bit test)
./run.sh tb_core_16bit

# Open the generated VCD file in GTKWave
gtkwave tb_core_16bit.vcd