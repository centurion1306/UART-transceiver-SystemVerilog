interface uart_if (input logic clk);
    logic       rst_n;
    logic       wr_en;
    logic [7:0] din;
    wire        tx_full;
    logic       rd_en;
    wire [7:0]  dout;
    wire        rx_empty;
    wire        tx_pin;
    wire        rx_pin;
endinterface