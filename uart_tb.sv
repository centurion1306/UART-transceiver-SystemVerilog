module uart_tb;
    logic clk = 0;
    always #10 clk = ~clk; 

    uart_if vif(.clk(clk));
    wire loopback_line; // Explicit wire to fix Icarus routing

    uart_top #(
        .SYS_CLK_FREQ(50_000_000),
        .BAUD_RATE(115200)
    ) dut (
        .clk(vif.clk),
        .rst_n(vif.rst_n),
        .wr_en(vif.wr_en),
        .din(vif.din),
        .tx_full(vif.tx_full),
        .rd_en(vif.rd_en),
        .dout(vif.dout),
        .rx_empty(vif.rx_empty),
        .tx_pin(loopback_line),
        .rx_pin(loopback_line)
    );

    int error_count = 0;
    int success_count = 0;

    initial begin
        $dumpfile("uart_sim.vcd");
        $dumpvars(0, uart_tb);
        vif.rst_n  <= 0;
        vif.wr_en  <= 0;
        vif.din    <= 0;
        vif.rd_en  <= 0;

        #200;
        @(posedge clk);
        vif.rst_n <= 1;
        #500;

        run_test_byte(8'hA5);
        run_test_byte(8'h3C);
        run_test_byte(8'h5A);
        run_test_byte(8'hFF);
        run_test_byte(8'h12);

        #50000;
        $display("   TEST SUMMARY:                        ");
        $display("   Successful Matches: %0d              ", success_count);
        $display("   Errors Encountered: %0d              ", error_count);
        if (error_count == 0 && success_count == 5) begin
            $display("   RESULT: TEST PASSED SUCCESSFULLY!    ");
        end else begin
            $display("   RESULT: TEST FAILED!                 ");
        end
        $finish;
    end

    task run_test_byte(input [7:0] val);
        @(posedge clk);
        while (vif.tx_full) @(posedge clk);
        vif.wr_en <= 1;
        vif.din   <= val;
        @(posedge clk);
        vif.wr_en <= 0;

        repeat (35000) @(posedge clk);

        if (!vif.rx_empty) begin
            if (vif.dout === val) begin
                $display("[PASS] Sent: 0x%0h, Received: 0x%0h", val, vif.dout);
                success_count++;
            end else begin
                $error("[FAIL] Sent: 0x%0h, Got: 0x%0h", val, vif.dout);
                error_count++;
            end
            vif.rd_en <= 1;
            @(posedge clk);
            vif.rd_en <= 0;
        end else begin
            $error("[FAIL] RX FIFO is empty when expecting byte 0x%0h", val);
            error_count++;
        end
    endtask
endmodule