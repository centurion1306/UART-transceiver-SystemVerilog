module uart_rx (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       baud_tick_16x,
    input  logic       rx,
    output logic [7:0] dout,
    output logic       rx_done
);

    typedef enum logic [1:0] {
        IDLE  = 2'b00,
        START = 2'b01,
        DATA  = 2'b10,
        STOP  = 2'b11
    } state_t;

    state_t state, next_state;
    logic [3:0] sample_cnt;
    logic [2:0] bit_cnt;
    logic [7:0] shift_reg;
    logic       rx_sync1, rx_sync2;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
        end else begin
            rx_sync1 <= rx;
            rx_sync2 <= rx_sync1;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else        state <= next_state;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sample_cnt <= '0;
            bit_cnt    <= '0;
            shift_reg  <= '0;
            dout       <= '0;
            rx_done    <= 1'b0;
        end else begin
            rx_done <= 1'b0;
            case (state)
                IDLE: begin
                    sample_cnt <= '0;
                    bit_cnt    <= '0;
                end
                START: begin
                    if (baud_tick_16x) begin
                        if (sample_cnt == 4'd7) begin
                            sample_cnt <= '0;
                        end else begin
                            sample_cnt <= sample_cnt + 1;
                        end
                    end
                end
                DATA: begin
                    if (baud_tick_16x) begin
                        if (sample_cnt == 4'd15) begin
                            sample_cnt <= '0;
                            shift_reg  <= {rx_sync2, shift_reg[7:1]};
                            bit_cnt    <= bit_cnt + 1;
                        end else begin
                            sample_cnt <= sample_cnt + 1;
                        end
                    end
                end
                STOP: begin
                    if (baud_tick_16x) begin
                        if (sample_cnt == 4'd15) begin
                            sample_cnt <= '0;
                            dout       <= shift_reg;
                            rx_done    <= 1'b1;
                        end else begin
                            sample_cnt <= sample_cnt + 1;
                        end
                    end
                end
            endcase
        end
    end

    always_comb begin
        next_state = state;
        case (state)
            IDLE:  if (rx_sync2 == 1'b0) next_state = START;
            START: if (baud_tick_16x && (sample_cnt == 4'd7)) begin
                       if (rx_sync2 == 1'b0) next_state = DATA;
                       else                  next_state = IDLE;
                   end
            DATA:  if (baud_tick_16x && (sample_cnt == 4'd15) && (bit_cnt == 3'd7)) next_state = STOP;
            STOP:  if (baud_tick_16x && (sample_cnt == 4'd15)) next_state = IDLE;
        endcase
    end

endmodule