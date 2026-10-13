module uart_tx (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       baud_tick,   // 1x baud rate tick
    input  logic       tx_start,    // Trigger transmission
    input  logic [7:0] din,         // Data byte to send
    output logic       tx,          // Serial output line
    output logic       tx_busy      // High when transmitting
);

    typedef enum logic [1:0] {
        IDLE  = 2'b00,
        START = 2'b01,
        DATA  = 2'b10,
        STOP  = 2'b11
    } state_t;

    state_t state, next_state;
    logic [7:0] shift_reg;
    logic [2:0] bit_cnt;

    // FSM State Register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else        state <= next_state;
    end

    // Datapath & Shift Register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= '0;
            bit_cnt   <= '0;
            tx        <= 1'b1; // UART idle state is high
            tx_busy   <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    tx      <= 1'b1;
                    tx_busy <= 1'b0;
                    if (tx_start) begin
                        shift_reg <= din;
                        tx_busy   <= 1'b1;
                    end
                end

                START: begin
                    if (baud_tick) begin
                        tx <= 1'b0; // Start bit (Low)
                    end
                end

                DATA: begin
                    if (baud_tick) begin
                        tx        <= shift_reg[0];
                        shift_reg <= shift_reg >> 1;
                    end
                end

                STOP: begin
                    if (baud_tick) begin
                        tx <= 1'b1; // Stop bit (High)
                    end
                end
            endcase

            // Bit counter logic for DATA state
            if (state == START && baud_tick) begin
                bit_cnt <= '0;
            end else if (state == DATA && baud_tick) begin
                bit_cnt <= bit_cnt + 1;
            end
        end
    end

    // Next State Logic
    always_comb begin
        next_state = state;
        case (state)
            IDLE:  if (tx_start) next_state = START;
            START: if (baud_tick) next_state = DATA;
            DATA:  if (baud_tick && (bit_cnt == 3'd7)) next_state = STOP;
            STOP:  if (baud_tick) next_state = IDLE;
        endcase
    end

endmodule