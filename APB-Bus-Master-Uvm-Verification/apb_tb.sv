import uvm_pkg::*;
`include "uvm_macros.svh"

package apb_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    class apb_transaction extends uvm_sequence_item;

        rand bit [7:0]  addr;
        rand bit [31:0] wdata;
        rand bit        write;      // 1 = write, 0 = read
             bit [31:0] rdata;      // populated on read
             bit        slverr;

        `uvm_object_utils_begin(apb_transaction)
            `uvm_field_int(addr,   UVM_ALL_ON)
            `uvm_field_int(wdata,  UVM_ALL_ON)
            `uvm_field_int(write,  UVM_ALL_ON)
            `uvm_field_int(rdata,  UVM_ALL_ON)
            `uvm_field_int(slverr, UVM_ALL_ON)
        `uvm_object_utils_end

        function new(string name = "apb_transaction");
            super.new(name);
        endfunction

        constraint c_addr_valid { addr inside {8'h00, 8'h04}; }

    endclass

    class apb_sequencer extends uvm_sequencer #(apb_transaction);
        `uvm_component_utils(apb_sequencer)
        function new(string name = "apb_sequencer", uvm_component parent = null);
            super.new(name, parent);
        endfunction
    endclass

    class apb_driver extends uvm_driver #(apb_transaction);
        `uvm_component_utils(apb_driver)

        virtual apb_if.DRIVER vif;

        function new(string name = "apb_driver", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual apb_if.DRIVER)::get(this, "", "vif", vif))
                `uvm_fatal("APB_DRV", "Virtual interface not found in config_db")
        endfunction

        task run_phase(uvm_phase phase);
            vif.PSEL    <= 1'b0;
            vif.PENABLE <= 1'b0;
            vif.PWRITE  <= 1'b0;
            vif.PADDR   <= '0;
            vif.PWDATA  <= '0;

            wait (vif.PRESETn === 1'b1);

            forever begin
                apb_transaction tr;
                seq_item_port.get_next_item(tr);
                drive_transfer(tr);
                seq_item_port.item_done();
            end
        endtask

        task drive_transfer(apb_transaction tr);
            // SETUP phase
            @(posedge vif.PCLK);
            vif.PSEL    <= 1'b1;
            vif.PENABLE <= 1'b0;
            vif.PWRITE  <= tr.write;
            vif.PADDR   <= tr.addr;
            vif.PWDATA  <= tr.write ? tr.wdata : '0;

            // ACCESS phase
            @(posedge vif.PCLK);
            vif.PENABLE <= 1'b1;

            do begin
                @(posedge vif.PCLK);
            end while (!vif.PREADY);

            if (!tr.write) tr.rdata = vif.PRDATA;
            tr.slverr = vif.PSLVERR;

            // return bus to idle
            vif.PSEL    <= 1'b0;
            vif.PENABLE <= 1'b0;

            `uvm_info("APB_DRV",
                $sformatf("%s addr=0x%0h wdata=0x%0h rdata=0x%0h",
                           tr.write ? "WRITE" : "READ", tr.addr, tr.wdata, tr.rdata),
                UVM_MEDIUM)
        endtask
    endclass

    class apb_monitor extends uvm_monitor;
        `uvm_component_utils(apb_monitor)

        virtual apb_if.MONITOR vif;
        uvm_analysis_port #(apb_transaction) ap;

        function new(string name = "apb_monitor", uvm_component parent = null);
            super.new(name, parent);
            ap = new("ap", this);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual apb_if.MONITOR)::get(this, "", "vif", vif))
                `uvm_fatal("APB_MON", "Virtual interface not found in config_db")
        endfunction

        task run_phase(uvm_phase phase);
            forever begin
                apb_transaction tr;

                // wait for SETUP phase (PSEL=1, PENABLE=0)
                @(posedge vif.PCLK);
                wait (vif.PSEL && !vif.PENABLE);

                tr = apb_transaction::type_id::create("tr");
                tr.addr  = vif.PADDR;
                tr.write = vif.PWRITE;
                tr.wdata = vif.PWDATA;

                // wait for ACCESS phase completion (PENABLE=1 && PREADY=1)
                @(posedge vif.PCLK);
                wait (vif.PENABLE && vif.PREADY);

                if (!tr.write) tr.rdata = vif.PRDATA;
                tr.slverr = vif.PSLVERR;

                `uvm_info("APB_MON",
                    $sformatf("%s addr=0x%0h wdata=0x%0h rdata=0x%0h",
                               tr.write ? "WRITE" : "READ", tr.addr, tr.wdata, tr.rdata),
                    UVM_HIGH)

                ap.write(tr);
            end
        endtask
    endclass

    class apb_agent extends uvm_agent;
        `uvm_component_utils(apb_agent)

        apb_sequencer sequencer;
        apb_driver    driver;
        apb_monitor   monitor;

        function new(string name = "apb_agent", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            monitor = apb_monitor::type_id::create("monitor", this);
            if (get_is_active() == UVM_ACTIVE) begin
                sequencer = apb_sequencer::type_id::create("sequencer", this);
                driver    = apb_driver::type_id::create("driver", this);
            end
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            if (get_is_active() == UVM_ACTIVE)
                driver.seq_item_port.connect(sequencer.seq_item_export);
        endfunction
    endclass

    class apb_basic_seq extends uvm_sequence #(apb_transaction);
        `uvm_object_utils(apb_basic_seq)

        function new(string name = "apb_basic_seq");
            super.new(name);
        endfunction

        task write_reg(bit [7:0] addr, bit [31:0] data);
            apb_transaction tr;
            tr = apb_transaction::type_id::create("tr");
            start_item(tr);
            tr.addr  = addr;
            tr.write = 1'b1;
            tr.wdata = data;
            finish_item(tr);
        endtask

        task read_reg(bit [7:0] addr);
            apb_transaction tr;
            tr = apb_transaction::type_id::create("tr");
            start_item(tr);
            tr.addr  = addr;
            tr.write = 1'b0;
            finish_item(tr);
        endtask

        task body();
            // CTRL: bit0 EN=1, bit1 RSTN=1 -> release reset and enable counting
            write_reg(8'h00, 32'b11);

            repeat (5) read_reg(8'h04);

            // pulse synchronous reset (RSTN=0) then re-enable
            write_reg(8'h00, 32'b00);
            write_reg(8'h00, 32'b11);

            repeat (3) read_reg(8'h04);
        endtask
    endclass

    class apb_env extends uvm_env;
        `uvm_component_utils(apb_env)

        apb_agent agent;

        function new(string name = "apb_env", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            agent = apb_agent::type_id::create("agent", this);
        endfunction
    endclass


    class apb_test extends uvm_test;
        `uvm_component_utils(apb_test)

        apb_env env;

        function new(string name = "apb_test", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = apb_env::type_id::create("env", this);
        endfunction

        task run_phase(uvm_phase phase);
            apb_basic_seq seq;
            phase.raise_objection(this);

            seq = apb_basic_seq::type_id::create("seq");
            seq.start(env.agent.sequencer);

            #20;
            phase.drop_objection(this);
        endtask
    endclass

endpackage

module tb_top;

    import apb_pkg::*;

    logic PCLK;
    logic PRESETn;

    initial PCLK = 0;
    always #5 PCLK = ~PCLK;

    initial begin
        PRESETn = 0;
        repeat (2) @(posedge PCLK);
        PRESETn = 1;
    end

    apb_if apb_if_inst (.PCLK(PCLK), .PRESETn(PRESETn));

    counter_dut dut (
        .PCLK    (PCLK),
        .PRESETn (PRESETn),
        .PADDR   (apb_if_inst.PADDR),
        .PSEL    (apb_if_inst.PSEL),
        .PENABLE (apb_if_inst.PENABLE),
        .PWRITE  (apb_if_inst.PWRITE),
        .PWDATA  (apb_if_inst.PWDATA),
        .PRDATA  (apb_if_inst.PRDATA),
        .PREADY  (apb_if_inst.PREADY),
        .PSLVERR (apb_if_inst.PSLVERR)
    );

    initial begin
        uvm_config_db#(virtual apb_if.DRIVER)::set(null, "uvm_test_top.env.agent.driver",  "vif", apb_if_inst);
        uvm_config_db#(virtual apb_if.MONITOR)::set(null, "uvm_test_top.env.agent.monitor", "vif", apb_if_inst);
    end

    initial begin
        run_test("apb_test");
    end

    initial begin
        $dumpfile("waves.vcd");
        $dumpvars(0, tb_top);
    end

endmodule
