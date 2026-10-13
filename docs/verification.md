# 8085 Microprocessor RTL - Verification Plan & Test Specification

This document describes the simulation architecture, testbench infrastructure, coverage metrics, and regression testing suite for the 8085 RTL core.

---

## 1. Verification Strategy

The verification environment tests the core at the **chip boundary**, validating the physical bus interface (`AD0-AD7`, `A8-A15`, `ALE`, `rd_n`, `wr_n`, `io_m`) against standard memory and I/O devices.

### Testbench System Model
Each testbench wraps the `core_8085` DUT with:
1. **74LS373 Address Latch Emulator:** Captures `AD0-AD7` on the high phase/falling edge of `ALE` and combines with `A8-A15` to form the full 16-bit address `full_addr`.
2. **64 KB SRAM Array:** Simulated linear byte-addressable RAM responding to active-low `rd_n` and `wr_n` when `io_m == 0`.
3. **I/O Device Bus Functional Model (BFM):** Responds to port reads and writes when `io_m == 1`.
4. **Self-Checking Oracle:** Automatic verification assertions comparing register and memory contents against expected gold standards upon program completion.

```
       +-----------------------------------------------------------+
       |                     Testbench Top                         |
       |                                                           |
       |   +-------------------+          +---------------------+  |
       |   |                   |--ALE---->| 74LS373 Latch Model |  |
       |   |                   |          +----------+----------+  |
       |   |                   |--A[15:8]------------|             |
       |   |     core_8085     |                     v             |
       |   |       (DUT)       |<========> 16-bit Address Bus =====|
       |   |                   |<--AD[7:0]-------+                 |
       |   |                   |--RD/WR----------|                 |
       |   |                   |--IO/M-----------|                 |
       |   +-------------------+                 v                 |
       |                             +------------------------+    |
       |                             | 64KB Memory & I/O BFM  |    |
       |                             +------------------------+    |
       +-----------------------------------------------------------+
```

---

## 2. Test Suite Breakdown

The test suite consists of 5 modular testbenches located in `testbench/`:

| Testbench File | Domain | Target Instructions | Primary Verification Goal |
| :--- | :--- | :--- | :--- |
| **`tb_core_basic.v`** | 8-bit Datapath | `MVI`, `MOV`, `ADD`, `SUB`, `INR`, `DCR`, `ANA`, `HLT` | ALU operations, register file writes, and flag status updates. |
| **`tb_core_16bit.v`** | 16-bit Math & Pointers | `LXI`, `DAD`, `INX`, `SHLD` | Multi-byte operand loading, double addition, and 16-bit boundary stores. |
| **`tb_core_stack_branch.v`**| Branching & Subroutines | `JNZ`, `CALL`, `RET`, `PUSH`, `POP`, `DCR`, `HLT` | Context switching, stack push/pop, and non-taken conditional branch skipping. |
| **`tb_core_sys_io.v`** | I/O & Accumulator | `STC`, `CMC`, `CMA`, `RLC`, `OUT`, `IN`, `HLT` | Hardware pin `IO/M` strobing, port multiplexing, and bit rotates. |
| **`tb_core_advanced.v`** | Extended Stack & BCD | `LXI SP`, `INX SP`, `DCX SP`, `DAD SP`, `XCHG`, `PCHL`, `DAA`, `PUSH PSW`, `POP PSW` | Full SP arithmetic, register swapping, BCD decimal adjustment, and PSW stack preservation. |

---

## 3. Test Details and Coverage

### 3.1 `tb_core_basic.v`
* **Test Program:**
  ```assembly
  0000: 3E 05   MVI A, 05h    ; A = 05h
  0002: 06 08   MVI B, 08h    ; B = 08h
  0004: 80      ADD B         ; A = 0Dh
  0005: 90      SUB B         ; A = 05h
  0006: 3C      INR A         ; A = 06h
  0007: 05      DCR B         ; B = 07h
  0008: A0      ANA B         ; A = 06h & 07h = 06h (AC flag set to 1)
  0009: 76      HLT
  ```
* **Success Criteria:** Core halts with `A == 06h` and `B == 07h`.

### 3.2 `tb_core_16bit.v`
* **Test Program:**
  ```assembly
  0000: 01 34 12   LXI B, 1234h ; BC = 1234h
  0003: 21 00 20   LXI H, 2000h ; HL = 2000h
  0006: 09         DAD B        ; HL = 3234h
  0007: 23         INX H        ; HL = 3235h
  0008: 22 00 40   SHLD 4000h   ; [4000h] = 35h, [4001h] = 32h
  000B: 76         HLT
  ```
* **Success Criteria:** Memory dump verifies `RAM[4000h] == 35h` and `RAM[4001h] == 32h`.

### 3.3 `tb_core_stack_branch.v`
* **Test Program:**
  ```assembly
  MAIN:
  0000: 31 FF FF   LXI SP, FFFFh ; SP = FFFFh
  0003: 3E 02      MVI A, 02h    ; A = 02h
  LOOP:
  0005: 3D         DCR A         ; A decrements
  0006: C2 05 00   JNZ LOOP      ; Branch while A != 0; fall through when A == 0
  0009: CD 20 00   CALL SUBR     ; Push PC(000Ch), jump to 0020h
  000C: 76         HLT           ; Target of return

  SUBR:
  0020: C5         PUSH B        ; Save B to stack
  0021: C1         POP B         ; Restore B from stack
  0022: C9         RET           ; Pop return address into PC
  ```
* **Success Criteria:** `SP` accurately restored to `0xFFFF`, subroutine executed and returned, core halted at `PC == 000Ch`.

### 3.4 `tb_core_sys_io.v`
* **Test Program:**
  ```assembly
  0000: 37         STC           ; Carry = 1
  0001: 3F         CMC           ; Carry = 0
  0002: 3E AA      MVI A, AAh    ; A = AAh
  0004: 2F         CMA           ; A = 55h
  0005: 07         RLC           ; A = AAh
  0006: D3 01      OUT 01h       ; Write AAh to Port 01h (IO/M = 1)
  0008: DB 02      IN 02h        ; Read BBh from Port 02h (IO/M = 1)
  000A: 76         HLT
  ```
* **Success Criteria:** Port address `01h` and `02h` driven on bus during I/O cycles; accumulator ends with `0xBB`.

### 3.5 `tb_core_advanced.v`
* **Test Program:**
  ```assembly
  0000: 31 00 20   LXI SP, 2000h ; SP = 2000h
  0003: 33         INX SP        ; SP = 2001h
  0004: 3B         DCX SP        ; SP = 2000h
  0005: 21 00 10   LXI H, 1000h  ; HL = 1000h
  0008: 39         DAD SP        ; HL = 3000h
  0009: 11 34 12   LXI D, 1234h  ; DE = 1234h
  000C: EB         XCHG          ; DE = 3000h, HL = 1234h
  000D: 3E 09      MVI A, 09h    ; A = 09h
  000F: C6 08      ADI 08h       ; A = 11h (Hex sum)
  0011: 27         DAA           ; A = 17h (BCD correction)
  0012: F5         PUSH PSW      ; Save A and status flags to stack
  0013: 3E 00      MVI A, 00h    ; Clear A
  0015: F1         POP PSW       ; Restore A = 17h and flags
  0016: 21 30 00   LXI H, 0030h  ; HL = 0030h
  0019: E9         PCHL          ; Jump to [HL] -> 0030h
  0030: 76         HLT
  ```
* **Success Criteria:** `SP == 2000h`, `DE == 3000h`, `A == 17h`, core halted at `0030h`.

---

## 4. How to Run the Tests

### Option 1: Linux / macOS / Bash
```bash
# Make script executable
chmod +x scripts/run.sh

# Run all testbenches
./scripts/run.sh all

# Or run a single testbench
./scripts/run.sh tb_core_advanced
```

### Option 2: Windows PowerShell
```powershell
# Run all testbenches
powershell -ExecutionPolicy Bypass -File .\scripts\run.ps1 all

# Or run a single testbench
powershell -ExecutionPolicy Bypass -File .\scripts\run.ps1 tb_core_advanced
```

### Option 3: Viewing Waveforms
Each simulation run generates a `.vcd` file:
```bash
gtkwave tb_core_advanced.vcd
```
