interface counter_if (input logic clk);
    logic       rst_n;
    logic       enable;
    logic [7:0] count;

    modport DRIVER  (input clk, count, output rst_n, enable);
    modport MONITOR (input clk, rst_n, enable, count);
    modport DUT     (input clk, rst_n, enable, output count);

endinterface

module counter_dut (
    input  logic       clk,
    input  logic       rst_n,   
    input  logic       enable,  
    output logic [7:0] count
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            count <= 8'h00;
        else if (enable)
            count <= count + 1'b1;
    end
endmodule