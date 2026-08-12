`timescale 1ns/1ns

module fb_clk_gen_tb;

    logic clk;
    logic fb_clk_p, fb_clk_n;

    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    initial begin
        #100000;
        $display("TIMEOUT: simulation did not finish in time");
        $stop;
    end

    task automatic toggle_test();
        logic prev_val;
        $display("[TEST] toggle_test");
        for (int i = 0; i < 10; i++) begin
            @(posedge clk or negedge clk);
            #1
            if (i > 0) begin
                assert(prev_val != fb_clk_p)
                else begin
                    $display("iter %0d: fb_clk_p did not toggle: prev=%b current=%b", i, prev_val, fb_clk_p);
                    $stop;
                end
            end
            prev_val = fb_clk_p;
        end
    endtask

    task automatic ddr_edge_test();
        time t_prev, t_curr, delta;
        localparam time CLK_PERIOD = 20;
        $display("[TEST] ddr_edge_test");

        @(fb_clk_p);
        t_prev = $time;

        for (int i = 0; i < 10; i++) begin
            @(fb_clk_p);
            t_curr = $time;
            delta = t_curr - t_prev;
            assert(delta == CLK_PERIOD / 2)
            else begin
                $display("iter %0d: unexpected toggle interval: got %0t, expected %0t",
                          i, delta, CLK_PERIOD / 2);
                $stop;
            end
            t_prev = t_curr;
        end
    endtask

    logic checks_enabled;

    initial begin
        checks_enabled = 0;
        @(posedge clk);
        checks_enabled = 1;
    end

    always @(fb_clk_p or fb_clk_n) begin
        if (checks_enabled) begin
            assert (fb_clk_n == ~fb_clk_p)
            else begin
                $display("complementary check failed at time %0t: fb_clk_p=%b fb_clk_n=%b",
                        $realtime, fb_clk_p, fb_clk_n);
                $stop;
            end
        end
    end

    initial begin
        $dumpfile("fb_clk_gen_tb.vcd");
        $dumpvars(0, fb_clk_gen_tb);

        // glbl asserts GSR for the first ROC_WIDTH ns of simulation; UNISIM
        // primitives (e.g. ODDR) hold their Q output at INIT while GSR is
        // high, so tests must not sample before it deasserts.
        wait (glbl.GSR == 1'b0);
        @(posedge clk);

        toggle_test();
        ddr_edge_test();

        $display("ALL TESTS PASSED");
        $finish;
    end

    fb_clk_gen fb_clk_gen_dut (
        .i_clk(clk),
        .o_fb_clk_p(fb_clk_p),
        .o_fb_clk_n(fb_clk_n)
    );

endmodule