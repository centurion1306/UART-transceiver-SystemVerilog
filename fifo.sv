module fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4   
)(
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  wr_en,
    input  logic [DATA_WIDTH-1:0] din,
    input  logic                  rd_en,
    output logic [DATA_WIDTH-1:0] dout,
    output logic                  full,
    output logic                  empty,
    output logic [ADDR_WIDTH:0]   fifo_count
);

    localparam DEPTH = 1 << ADDR_WIDTH;
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    logic [ADDR_WIDTH-1:0] wr_ptr, rd_ptr;

    assign empty = (fifo_count == 0);
    assign full  = (fifo_count == DEPTH);

    always_comb begin
        dout = mem[rd_ptr];
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
            for (int i = 0; i < DEPTH; i++) begin
                mem[i] <= '0; // Clear memory to prevent 'x' propagation
            end
        end else if (wr_en && !full) begin
            mem[wr_ptr] <= din;
            wr_ptr <= wr_ptr + 1;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr <= '0;
        end else if (rd_en && !empty) begin
            rd_ptr <= rd_ptr + 1;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fifo_count <= '0;
        end else begin
            case ({wr_en && !full, rd_en && !empty})
                2'b10:   fifo_count <= fifo_count + 1;
                2'b01:   fifo_count <= fifo_count - 1;
                default: fifo_count <= fifo_count;
            endcase
        end
    end
endmodule