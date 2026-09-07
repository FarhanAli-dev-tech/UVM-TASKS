# 8-bit-synchronous-up-counter-Uvm-Verification

A minimal, self-contained UVM-1.2 testbench for a simple 8-bit up-counter, verified on **Cadence Xcelium 25.03** (also runnable on EDA Playground).

```
UVM_ERROR :    0
UVM_FATAL :    0
Simulation complete via $finish(1) at time 165 NS
```

## Overview

| | |
|---|---|
| **DUT** | 8-bit synchronous up-counter with active-low async reset and an `enable` pin |
| **Verification method** | UVM 1.2 (sequence → sequencer → driver → DUT, monitor sampling in parallel) |
| **Simulator** | Cadence Xcelium 25.03 (tested), should also work on Questa/VCS with minor flag changes |
| **File count** | 2 files — RTL side and TB side |

## Project structure

```
.
├── counter_dut_if.sv   # Interface + DUT (RTL side) — compile FIRST
├── counter_tb.sv        # counter_pkg (all UVM classes) + tb_top module — compile SECOND
└── README.md
```

### `counter_dut_if.sv`
- `counter_if` — SystemVerilog interface with `DRIVER` / `MONITOR` / `DUT` modports
- `counter_dut` — the RTL: `clk`, `rst_n` (active-low async), `enable` → `count[7:0]`

### `counter_tb.sv`
Everything UVM-related, packaged inside `counter_pkg`:

| Class | Role |
|---|---|
| `counter_txn` | `uvm_sequence_item` — `rst_n`, `enable` (driven), `count` (sampled) |
| `counter_sequencer` | `uvm_sequencer #(counter_txn)` |
| `counter_driver` | Drives `rst_n` / `enable` onto the interface every clock edge |
| `counter_monitor` | Passively samples `rst_n` / `enable` / `count` each cycle, publishes on an `uvm_analysis_port` |
| `counter_agent` | Bundles sequencer + driver (active) + monitor |
| `counter_basic_seq` | Directed sequence: 2 cycles reset → 10 cycles enabled counting → 3 cycles disabled (count should hold) |
| `counter_env` | Instantiates the agent |
| `counter_test` | Builds the env, starts `counter_basic_seq`, raises/drops the run-phase objection |

Followed by the `tb_top` module: clock generator, DUT + interface binding, virtual-interface handoff via `uvm_config_db`, `run_test("counter_test")`, and a `$dumpvars` waveform dump.

## Signal / class flow
<img width="1024" height="753" alt="image" src="https://github.com/user-attachments/assets/7a88e31b-54b4-456d-9836-118deb5110de" />


## Prerequisites
- A SystemVerilog simulator with a bundled UVM-1.2 library (Xcelium, Questa, or VCS)
- No external UVM install needed if using Xcelium's `-uvm` flag (see below)


## Waveform result
<img width="1308" height="113" alt="image" src="https://github.com/user-attachments/assets/c4159a34-0593-44ed-ae52-46e815e51711" />

