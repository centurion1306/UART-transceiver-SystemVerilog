module uart_top #(
    parameter int SYS_CLK_FREQ = 50_000_000,
    parameter int BAUD_RATE    = 115200
)(
    input  logic       clk,
    input  logic       rst_n,
    // CPU/Application Write Interface
    input  logic       wr_en,
    input  logic [7:0] din,
    output logic       tx_full,
    // CPU/Application Read Interface
    input  logic       rd_en,
    output logic [7:0] dout,
    output logic       rx_empty,
    // External Pins (or internal loopback)
    output logic       tx_pin,
    input  logic       rx_pin
);

    // Baud Tick Generation Constants
    localparam int CLKS_PER_BIT   = SYS_CLK_FREQ / BAUD_RATE;
    localparam int CLKS_PER_16X   = CLKS_PER_BIT / 16;

    // Internal signals
    logic        baud_tick_1x;
    logic        baud_tick_16x;
    logic [15:0] tick_counter_1x;
    logic [15:0] tick_counter_16x;

    logic        tx_fifo_empty, tx_fifo_rd;
    logic [7:0]  tx_fifo_dout;
    logic        tx_busy, tx_start;

    logic        rx_done;
    logic [7:0]  rx_dout;
    logic        rx_fifo_wr;

    // 1x Baud Generator (for Transmitter)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tick_counter_1x <= '0;
            baud_tick_1x    <= 1'b0;
        end else if (tick_counter_1x == CLKS_PER_BIT - 1) begin
            tick_counter_1x <= '0;
            baud_tick_1x    <= 1'b1;
        end else begin
            tick_counter_1x <= tick_counter_1x + 1;
            baud_tick_1x    <= 1'b0;
        end
    end

    // 16x Baud Generator (for Receiver)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tick_counter_16x <= '0;
            baud_tick_16x    <= 1'b0;
        end else if (tick_counter_16x == CLKS_PER_16X - 1) begin
            tick_counter_16x <= '0;
            baud_tick_16x    <= 1'b1;
        end else begin
            tick_counter_16x <= tick_counter_16x + 1;
            baud_tick_16x    <= 1'b0;
        end
    end

    // TX FIFO Instance
    fifo tx_fifo (
        .clk(clk), .rst_n(rst_n),
        .wr_en(wr_en), .din(din),
        .rd_en(tx_fifo_rd), .dout(tx_fifo_dout),
        .full(tx_full), .empty(tx_fifo_empty), .fifo_count()
    );

    // TX Control logic: Pull from FIFO when transmitter is free and baud tick hits
    assign tx_start = !tx_fifo_empty && !tx_busy && baud_tick_1x;
    assign tx_fifo_rd = tx_start;

    // UART Transmitter Instance
    uart_tx u_tx (
        .clk(clk), .rst_n(rst_n),
        .baud_tick(baud_tick_1x),
        .tx_start(tx_start),
        .din(tx_fifo_dout),
        .tx(tx_pin),
        .tx_busy(tx_busy)
    );

    // UART Receiver Instance
    uart_rx u_rx (
        .clk(clk), .rst_n(rst_n),
        .baud_tick_16x(baud_tick_16x),
        .rx(rx_pin),
        .dout(rx_dout),
        .rx_done(rx_done)
    );

    // RX FIFO Instance
    assign rx_fifo_wr = rx_done;
    fifo rx_fifo (
        .clk(clk), .rst_n(rst_n),
        .wr_en(rx_fifo_wr), .din(rx_dout),
        .rd_en(rd_en), .dout(dout),
        .full(), .empty(rx_empty), .fifo_count()
    );

endmodule