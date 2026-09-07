# UVM Verification Tasks

Two small UVM-1.2 testbenches, each self-contained in 2 files, verified on **Cadence Xcelium 25.03**.

| # | Task | Folder | Summary |
|---|---|---|---|
| 1 | [8-bit Synchronous Up-Counter UVM Verification](./counter-uvm) | `counter-uvm/` | Basic UVM testbench for a simple counter DUT — sequence → sequencer → driver → DUT, monitor sampling in parallel |
| 2 | [APB Bus Master UVM Verification](./apb-uvm) | `apb-uvm/` | UVM agent for an APB bus master driving an APB-slave counter DUT — sequencer → driver → DUT, monitor collecting transactions |

Each task folder has its own README with the full file breakdown, class tables, flow diagram, waveform, and run instructions (Xcelium / EDA Playground / Questa / VCS).

## Structure

```
.
├── counter-uvm/
│   ├── counter_dut_if.sv
│   ├── counter_tb.sv
│   └── README.md
├── apb-uvm/
│   ├── apb_dut_if.sv
│   ├── apb_tb.sv
│   └── README.md
└── README.md   (this file)
```


Task 1 exercises this on a plain `enable`/`rst_n` counter; task 2 extends the same skeleton to a full APB agent so it can drive any APB-slave DUT with just a register-map change.

## Prerequisites
- A SystemVerilog simulator with a bundled UVM-1.2 library (Xcelium, Questa, or VCS)
- No external UVM install needed if using Xcelium's `-uvm` flag
