# APB-Bus-Master-Uvm-Verification
A minimal, self-contained UVM-1.2 agent for an APB bus master, driving an APB-slave counter DUT. Sequencer → driver → DUT, with a monitor collecting transactions in parallel.

```
UVM_ERROR :    0
UVM_FATAL :    0
Simulation complete via $finish(1)
```
*(expected result — run it once and drop your own log/screenshot here)*

## Overview

| | |
|---|---|
| **DUT** | APB-slave 8-bit up-counter — `CTRL` register @ `0x00` (bit0 `EN`, bit1 `RSTN`), `COUNT` register @ `0x04` (read-only) |
| **Verification method** | UVM 1.2 agent (sequence → sequencer → driver → DUT, monitor sampling the bus in parallel) |
| **Simulator** | Cadence Xcelium 25.03 (tested), should also work on Questa/VCS with minor flag changes |
| **File count** | 2 files — RTL side and TB side |

## Project structure

```
.
├── apb_dut.sv   # APB interface + DUT (RTL side) — compile FIRST
├── apb_tb.sv        # apb_pkg (full UVM agent) + tb_top module — compile SECOND
└── README.md
```

### `apb_dut_if.sv`
- `apb_if` — SystemVerilog interface with `DRIVER` / `MONITOR` / `DUT` modports (`PADDR`, `PSEL`, `PENABLE`, `PWRITE`, `PWDATA`, `PRDATA`, `PREADY`, `PSLVERR`)
- `counter_dut` — APB-slave counter RTL: `CTRL` write sets `EN`/`RSTN`, `COUNT` free-runs while enabled

### `apb_tb.sv`
Everything UVM-related, packaged inside `apb_pkg`:

| Class | Role |
|---|---|
| `apb_transaction` | `uvm_sequence_item` — `addr`, `wdata`, `write` (driven), `rdata`, `slverr` (sampled) |
| `apb_sequencer` | `uvm_sequencer #(apb_transaction)` |
| `apb_driver` | Drives the APB SETUP/ACCESS phases onto the bus, waits for `PREADY` |
| `apb_monitor` | Passively samples the bus, reconstructs completed transactions, publishes them on an `uvm_analysis_port` |
| `apb_agent` | Bundles sequencer + driver (active) + monitor |
| `apb_basic_seq` | Directed sequence: write `CTRL` (EN\|RSTN) → read `COUNT` ×5 → pulse reset → re-enable → read `COUNT` ×3 |
| `apb_env` | Instantiates the agent |
| `apb_test` | Builds the env, starts `apb_basic_seq`, raises/drops the run-phase objection |

Followed by the `tb_top` module: clock/reset generation, DUT + interface binding, virtual-interface handoff via `uvm_config_db`, `run_test("apb_test")`, and a `$dumpvars` waveform dump.

## Signal / class flow

<img width="1024" height="753" alt="image" src="https://github.com/user-attachments/assets/1bc6bb1a-29c1-4731-ac63-77eff449d37d" />

## Waveform result
<img width="975" height="259" alt="image" src="https://github.com/user-attachments/assets/e0fcfe09-8ed1-487f-b586-9388eb8cdf8a" />
