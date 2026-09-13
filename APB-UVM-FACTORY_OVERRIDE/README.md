# APB-UVM-Factory-Override

A minimal UVM-1.2 agent for an APB bus master driving an APB-slave counter DUT, extended with **factory-based driver override**. Sequencer → driver (swappable via the UVM factory) → DUT, with a monitor collecting transactions in parallel.

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
| **Verification method** | UVM 1.2 agent (sequence → sequencer → driver → DUT, monitor sampling the bus in parallel) + **factory `type_override`** to swap the driver implementation without touching the agent/env |
| **Simulator** | Cadence Xcelium 25.03 (tested), should also work on Questa/VCS with minor flag changes |
| **File count** | 2 files — RTL side and TB side |

## Project structure

```
.
├── design.sv        # APB interface + DUT (RTL side) — compile FIRST
├── testbench.sv      # apb_pkg (full UVM agent + factory override) + tb_top — compile SECOND
└── README.md
```

### `design.sv`
- `apb_if` — SystemVerilog interface with `DRIVER` / `MONITOR` / `DUT` modports (`PADDR`, `PSEL`, `PENABLE`, `PWRITE`, `PWDATA`, `PRDATA`, `PREADY`, `PSLVERR`)
- `apb_dut` — APB-slave counter RTL: `CTRL` write sets `EN`/`RSTN`, `COUNT` free-runs while enabled

### `testbench.sv`
Everything UVM-related, packaged inside `apb_pkg`:

| Class | Role |
|---|---|
| `apb_transaction` | `uvm_sequence_item` — `addr`, `wdata`, `write` (driven), `rdata`, `slverr` (sampled), constrained to valid register addresses |
| `apb_sequencer` | `uvm_sequencer #(apb_transaction)` |
| `apb_driver` | Drives the APB SETUP/ACCESS phases onto the bus, waits for `PREADY`. `drive_transfer()` declared `virtual` — the factory-override hook |
| `apb_driver_slow` | **Overridden driver** — extends `apb_driver`, adds one extra idle clock before every transfer, tags its log `[APB_DRV_SLOW]`, then calls `super.drive_transfer()` |
| `apb_monitor` | Passively samples the bus, reconstructs completed transactions, publishes them on an `uvm_analysis_port` |
| `apb_agent` | Bundles sequencer + driver (active) + monitor — still calls `apb_driver::type_id::create(...)`, unaware which concrete driver the factory hands back |
| `apb_basic_seq` | Directed sequence: write `CTRL` (EN\|RSTN) → read `COUNT` ×5 → pulse reset → re-enable → read `COUNT` ×3 |
| `apb_env` | Instantiates the agent |
| `apb_test` | Baseline — builds the env, starts `apb_basic_seq` with the **original** `apb_driver` |
| `apb_test_override` | **Factory override test** — calls `apb_driver::type_id::set_type_override(apb_driver_slow::get_type())` in `build_phase()`, before `super.build_phase()` builds the agent |

Followed by the `tb_top` module: clock/reset generation, DUT + interface binding, virtual-interface handoff via `uvm_config_db`, `run_test()` (test picked via `+UVM_TESTNAME`), and a `$dumpvars` waveform dump.

## How the factory override works

```systemverilog
function void build_phase(uvm_phase phase);
    apb_driver::type_id::set_type_override(apb_driver_slow::get_type());
    super.build_phase(phase);   // agent now builds apb_driver_slow instead of apb_driver
endfunction
```
No change is needed inside `apb_agent` or `apb_env` — they still say
`apb_driver::type_id::create("driver", this)`. The factory transparently
substitutes `apb_driver_slow` for every driver built under this test.

## Running

```bash
xrun -Q -unbuffered -timescale 1ns/1ns -sysv -access +rw \
     -uvmnocdnsextra -uvmhome $UVM_HOME \
     $UVM_HOME/src/uvm_macros.svh design.sv testbench.sv \
     +UVM_TESTNAME=<test_name>
```

| `+UVM_TESTNAME=` | Behavior |
|---|---|
| `apb_test` | Baseline — only `[APB_DRV]` log lines |
| `apb_test_override` | Factory override active — `[APB_DRV_SLOW]` log line appears before every `[APB_DRV]` line, proving the override took effect |

## Waveform result
<img width="975" height="238" alt="image" src="https://github.com/user-attachments/assets/1c45af49-8616-418a-820a-4cefbf4d4b2a" />


