interface apb_if (input logic PCLK, input logic PRESETn);
    logic [7:0]  PADDR;
    logic        PSEL;
    logic        PENABLE;
    logic        PWRITE;
    logic [31:0] PWDATA;
    logic [31:0] PRDATA;
    logic        PREADY;
    logic        PSLVERR;

    modport DRIVER (
        input  PCLK, PRESETn, PRDATA, PREADY, PSLVERR,
        output PADDR, PSEL, PENABLE, PWRITE, PWDATA
    );

    modport MONITOR (
        input PCLK, PRESETn, PADDR, PSEL, PENABLE, PWRITE,
              PWDATA, PRDATA, PREADY, PSLVERR
    );

    modport DUT (
        input  PCLK, PRESETn, PADDR, PSEL, PENABLE, PWRITE, PWDATA,
        output PRDATA, PREADY, PSLVERR
    );
endinterface


module apb_dut (
    input  logic        PCLK,
    input  logic        PRESETn,
    input  logic [7:0]  PADDR,
    input  logic         PSEL,
    input  logic         PENABLE,
    input  logic         PWRITE,
    input  logic [31:0]  PWDATA,
    output logic [31:0]  PRDATA,
    output logic         PREADY,
    output logic         PSLVERR
);
    localparam ADDR_CTRL  = 8'h00;
    localparam ADDR_COUNT = 8'h04;

    logic [31:0] ctrl_reg;
    logic [31:0] count_reg;

    wire apb_write = PSEL && PENABLE && PWRITE;
    wire apb_read  = PSEL && PENABLE && !PWRITE;

    assign PREADY  = 1'b1;
    assign PSLVERR = 1'b0;

    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            ctrl_reg <= 32'h0;
        else if (apb_write && PADDR == ADDR_CTRL)
            ctrl_reg <= PWDATA;
    end

    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            count_reg <= 32'h0;
        else if (!ctrl_reg[1])
            count_reg <= 32'h0;
        else if (ctrl_reg[0])
            count_reg <= count_reg + 1'b1;
    end

    always_comb begin
        PRDATA = 32'h0;
        if (apb_read) begin
            case (PADDR)
                ADDR_CTRL:  PRDATA = ctrl_reg;
                ADDR_COUNT: PRDATA = count_reg;
                default:    PRDATA = 32'h0;
            endcase
        end
    end
endmodule
