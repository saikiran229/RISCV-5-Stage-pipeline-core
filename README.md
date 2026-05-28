# RISC-V 5-Stage Pipeline Core (SystemVerilog)

A simplified 32-bit RISC-V pipelined processor implemented in **SystemVerilog** featuring a classic 5-stage pipeline architecture.

This project demonstrates the fundamentals of pipelined CPU design including:
- Instruction Fetch (IF)
- Instruction Decode (ID)
- Execute (EX)
- Memory Access (MEM)
- Write Back (WB)

The design supports a subset of the RV32I instruction set and includes:
- Pipeline registers
- Instruction memory
- Data memory
- Register file
- ALU operations
- Branch handling
- Simple hazard avoidance using inserted NOPs

---

## Features

- 32-bit RISC-V pipeline
- 5-stage architecture
- Modular SystemVerilog design
- Separate instruction and data memories
- Register forwarding inside register file
- Branch flushing support
- Memory load/store support
- VCD waveform dumping for debugging

---

## Supported Instructions

| Type | Instructions |
|------|------|
| R-Type | `add` |
| I-Type | `addi` |
| Load | `lw` |
| Store | `sw` |
| Branch | `beq` |

---

## Pipeline Architecture

```text
IF  ->  ID  ->  EX  ->  MEM  ->  WB
```

### Stages

| Stage | Description |
|------|------|
| IF | Fetch instruction from instruction memory |
| ID | Decode instruction and read registers |
| EX | Execute ALU operations / branch comparison |
| MEM | Access data memory |
| WB | Write results back to register file |

---

## Project Structure

```text
RISCV-5-Stage-pipeline-core/
│
├── rtl/
│   └── design.sv
│
├── tb/
│   └── testbench.sv
│
├── mem/
│   └── program.mem
│
└── simulation_waveform/

```

---

## Example Program

The included `program.mem` initializes and executes:

```assembly
addi x1, x0, 5
addi x2, x0, 10
nop
nop
add  x3, x1, x2
sw   x3, 0(x0)
```

Expected result:

```text
x1 = 5
x2 = 10
x3 = 15
MEM[0] = 15
```

---

## Simulation

### Using Icarus Verilog

Compile:

```bash
iverilog -g2012 -o riscv_sim rtl/design.sv tb/testbench.sv
```

Run:

```bash
vvp riscv_sim
```

Open waveform:

```bash
gtkwave dump.vcd
```

---

## Waveform Dump

The testbench automatically generates:

```text
dump.vcd
```

This can be viewed using GTKWave.

---

## Current Limitations

This project is intended for educational purposes and currently includes:

- No hazard detection unit
- No forwarding unit
- Limited RV32I instruction support
- No cache or MMU
- No exception handling

NOP instructions are manually inserted to avoid data hazards.

---

## Future Improvements

- Data forwarding unit
- Hazard detection and stalling
- Full RV32I support
- Jump instructions
- Branch prediction
- UART integration
- FPGA deployment support

---

## Tools Used

- SystemVerilog
- Icarus Verilog
- GTKWave
- Vivado / ModelSim compatible


## License

This project is licensed under the MIT License.
