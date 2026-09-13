`timescale 1ns/1ns

// Wires ad9361_tx_lvds directly into ad9361_rx_lvds (no real AD9361 -
// this simulates the digital wiring only, not the chip's internal
// analog loopback path or the LVDS skew already characterized in
// ad9361_tx_lvds_tb.sv), to validate that ad9361_rx_lvds's IDDR-based
// mirror of the TX bit convention actually reconstructs the transmitted
// I/Q samples correctly before trusting it on real hardware.
module ad9361_rx_lvds_tb;

    logic clk, rst_n;
    logic signed [11:0] tx_i, tx_q;

    logic [5:0] tx_d_p, tx_d_n;
    logic tx_frame_p, tx_frame_n;
    logic fb_clk_p, fb_clk_n;

    logic rx_clk;
    logic [11:0] rx_data_i, rx_data_q;
    logic rx_valid;

    localparam time CLK_HALF_PERIOD = 12.5;

    initial begin
        clk = 0;
        forever #CLK_HALF_PERIOD clk = ~clk;
    end

    initial begin
        #1000000;
        $display("TIMEOUT: simulation did not finish in time");
        $stop;
    end

    logic phase_sel;

    ad9361_tx_lvds tx_dut (
        .i_clk(clk),
        .i_rst_n(rst_n),
        .i_tx_i(tx_i),
        .i_tx_q(tx_q),
        .o_tx_d_p(tx_d_p),
        .o_tx_d_n(tx_d_n),
        .o_tx_frame_p(tx_frame_p),
        .o_tx_frame_n(tx_frame_n),
        .o_fb_clk_p(fb_clk_p),
        .o_fb_clk_n(fb_clk_n),
        .o_phase_sel(phase_sel)
    );

    ad9361_rx_lvds rx_dut (
        .i_clk_p(fb_clk_p),
        .i_clk_n(fb_clk_n),
        .i_rst_n(rst_n),
        .i_rx_frame_p(tx_frame_p),
        .i_rx_frame_n(tx_frame_n),
        .i_rx_d_p(tx_d_p),
        .i_rx_d_n(tx_d_n),
        .o_clk(rx_clk),
        .o_data_i(rx_data_i),
        .o_data_q(rx_data_q),
        .o_valid(rx_valid)
    );

    // Change tx_i/tx_q only right as a fresh MSB half is starting (mirrors
    // ad9361_tx_lvds_tb.sv's own frame-boundary sync) - changing mid-frame
    // races the TX side's own hold registers and tears the in-flight
    // sample, which is a testbench hazard, not an RTL bug.
    task automatic sync_to_frame_start();
        if (phase_sel === 1'b1) @(negedge phase_sel);
        @(posedge phase_sel);
    endtask

    task automatic receive_one(output logic [11:0] got_i, output logic [11:0] got_q);
        @(posedge rx_clk);
        while (!rx_valid) @(posedge rx_clk);
        got_i = rx_data_i;
        got_q = rx_data_q;
        $display("        receive_one: got i=0x%03x q=0x%03x @ %0t", got_i, got_q, $time);
    endtask

    task automatic value_test(input logic [11:0] i_val, input logic [11:0] q_val);
        logic [11:0] got_i, got_q;
        $display("[TEST] value_test i=0x%03x q=0x%03x", i_val, q_val);

        sync_to_frame_start();
        tx_i = i_val;
        tx_q = q_val;

        receive_one(got_i, got_q);
        receive_one(got_i, got_q);
        receive_one(got_i, got_q);

        assert (got_i == i_val)
        else begin
            $display("value_test: I mismatch: expected 0x%03x, got 0x%03x", i_val, got_i);
            $stop;
        end

        assert (got_q == q_val)
        else begin
            $display("value_test: Q mismatch: expected 0x%03x, got 0x%03x", q_val, got_q);
            $stop;
        end
    endtask

    // receive_one() needs 2 extra flush reads before a freshly-set value
    // shows up (pipeline latency through IDDR + the hold/output
    // registers) - see value_test's 3x receive_one. Pipeline the
    // expected values through a queue by that same 2-sample depth
    // instead of re-deriving/hardcoding the latency number here.
    task automatic back_to_back_test(int n_samples);
        logic [11:0] exp_i_q[$], exp_q_q[$];
        const int LATENCY = 2;

        $display("[TEST] back_to_back_test (%0d samples)", n_samples);

        for (int k = 0; k < n_samples + LATENCY; k++) begin
            logic [11:0] exp_i, exp_q, got_i, got_q;

            if (k < n_samples) begin
                exp_i = $urandom_range(4095, 0);
                exp_q = $urandom_range(4095, 0);
                exp_i_q.push_back(exp_i);
                exp_q_q.push_back(exp_q);

                sync_to_frame_start();
                tx_i = exp_i;
                tx_q = exp_q;
            end else begin
                sync_to_frame_start();
            end

            receive_one(got_i, got_q);

            if (k >= LATENCY) begin
                exp_i = exp_i_q.pop_front();
                exp_q = exp_q_q.pop_front();

                assert (got_i == exp_i)
                else begin
                    $display("back_to_back_test: sample %0d I mismatch: expected 0x%03x, got 0x%03x", k - LATENCY,
                              exp_i, got_i);
                    $stop;
                end

                assert (got_q == exp_q)
                else begin
                    $display("back_to_back_test: sample %0d Q mismatch: expected 0x%03x, got 0x%03x", k - LATENCY,
                              exp_q, got_q);
                    $stop;
                end
            end
        end
    endtask

    initial begin
        $dumpfile("ad9361_rx_lvds_tb.vcd");
        $dumpvars(0, ad9361_rx_lvds_tb);

        rst_n = 0;
        tx_i  = 0;
        tx_q  = 0;
        repeat (4) @(negedge clk);
        rst_n = 1;

        wait (glbl.GSR == 1'b0);
        repeat (4) @(posedge clk);

        value_test(12'h000, 12'h000);
        value_test(12'hFFF, 12'hFFF);
        value_test(12'hABC, 12'h123);
        value_test(12'h800, 12'h001);
        back_to_back_test(30);

        $display("ALL TESTS PASSED");
        $finish;
    end

endmodule
