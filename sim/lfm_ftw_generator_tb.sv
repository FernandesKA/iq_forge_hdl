`timescale 1ns/1ns

module lfm_ftw_generator_tb
#(parameter ACC_WIDTH = 24);

    logic clk, rst_n, load, continious;
    logic [ACC_WIDTH - 1 : 0] ftw_start, ftw_stop, ftw_incr, ftw;

    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    initial begin
        #200000;
        $display("TIMEOUT: simulation did not finish in time");
        $stop;
    end

    task automatic step();
        @(posedge clk);
        @(negedge clk);
    endtask

    task automatic check(input logic [ACC_WIDTH-1:0] expected, input string what);
        assert (ftw == expected)
        else begin
            $display("%s: required 0x%x, current is 0x%x", what, expected, ftw);
            $stop;
        end
    endtask

    task automatic apply_reset();
        rst_n      <= 0;
        load       <= 0;
        continious <= 0;
        ftw_start  <= 0;
        ftw_stop   <= 0;
        ftw_incr   <= 0;
        @(negedge clk);
        rst_n <= 1;
    endtask

    task automatic load_test();
        $display("[TEST] load_test");
        apply_reset();
        ftw_start <= 'h100;
        ftw_stop  <= 'h1000;
        ftw_incr  <= 'h10;
        load      <= 1;
        step();
        check('h100, "load");
        step();
        check('h100, "load held");
        load <= 0;
    endtask

    task automatic ramp_test();
        $display("[TEST] ramp_test");
        apply_reset();
        ftw_start <= 'h100;
        ftw_stop  <= 'h1000;
        ftw_incr  <= 'h10;
        load      <= 1;
        step();
        load <= 0;

        for (int i = 1; i <= 20; i++) begin
            step();
            check('h100 + 'h10 * i, $sformatf("ramp step %0d", i));
        end
    endtask

    task automatic saturate_test();
        $display("[TEST] saturate_test");
        apply_reset();
        ftw_start <= 'h100;
        ftw_stop  <= 'h150;
        ftw_incr  <= 'h30;
        load      <= 1;
        step();
        load <= 0;

        step();
        check('h130, "before stop");
        step();
        check('h150, "clamped to stop");
        repeat (5) begin
            step();
            check('h150, "held at stop");
        end
    endtask

    task automatic exact_stop_test();
        $display("[TEST] exact_stop_test");
        apply_reset();
        ftw_start <= 'h100;
        ftw_stop  <= 'h140;
        ftw_incr  <= 'h20;
        load      <= 1;
        step();
        load <= 0;

        step();
        check('h120, "step 1");
        step();
        check('h140, "reached stop exactly");
        step();
        check('h140, "held at stop");
    endtask

    task automatic reload_test();
        $display("[TEST] reload_test");
        apply_reset();
        ftw_start <= 'h100;
        ftw_stop  <= 'h1000;
        ftw_incr  <= 'h10;
        load      <= 1;
        step();
        load <= 0;
        repeat (5) step();
        check('h150, "before reload");

        ftw_start <= 'h200;
        load      <= 1;
        step();
        check('h200, "reload");
        load <= 0;
        step();
        check('h210, "ramp after reload");
    endtask

    task automatic load_priority_test();
        $display("[TEST] load_priority_test");
        apply_reset();
        ftw_start  <= 'h100;
        ftw_stop   <= 'h1000;
        ftw_incr   <= 'h10;
        continious <= 1;
        load       <= 1;
        step();
        check('h100, "load over continious");
        step();
        check('h100, "load over continious held");
        load <= 0;
        step();
        check('h110, "continious ramp");
    endtask

    task automatic continious_wrap_test();
        logic [ACC_WIDTH-1:0] expected;
        $display("[TEST] continious_wrap_test");
        apply_reset();
        ftw_start  <= (1 << ACC_WIDTH) - 'h30;
        ftw_stop   <= 'h10;
        ftw_incr   <= 'h20;
        continious <= 1;
        load       <= 1;
        step();
        load <= 0;
        expected = (1 << ACC_WIDTH) - 'h30;
        check(expected, "loaded near top");

        for (int i = 0; i < 6; i++) begin
            step();
            expected = expected + 'h20;
            check(expected, $sformatf("continious step %0d", i));
        end
    endtask

    task automatic continious_ignores_stop_test();
        $display("[TEST] continious_ignores_stop_test");
        apply_reset();
        ftw_start  <= 'h100;
        ftw_stop   <= 'h120;
        ftw_incr   <= 'h20;
        continious <= 1;
        load       <= 1;
        step();
        load <= 0;

        for (int i = 1; i <= 5; i++) begin
            step();
            check('h100 + 'h20 * i, $sformatf("past stop step %0d", i));
        end
    endtask

    task automatic mode_switch_test();
        $display("[TEST] mode_switch_test");
        apply_reset();
        ftw_start  <= 'h100;
        ftw_stop   <= 'h140;
        ftw_incr   <= 'h20;
        continious <= 1;
        load       <= 1;
        step();
        load <= 0;
        repeat (4) step();
        check('h180, "continious past stop");

        continious <= 0;
        step();
        check('h140, "clamped back to stop after mode switch");
    endtask

    task automatic overflow_saturate_test();
        $display("[TEST] overflow_saturate_test");
        apply_reset();
        ftw_start <= (1 << ACC_WIDTH) - 'h30;
        ftw_stop  <= (1 << ACC_WIDTH) - 'h10;
        ftw_incr  <= 'h20;
        load      <= 1;
        step();
        load <= 0;

        step();
        check((1 << ACC_WIDTH) - 'h10, "clamped to stop");
        step();
        check((1 << ACC_WIDTH) - 'h10, "no wrap past stop");
        step();
        check((1 << ACC_WIDTH) - 'h10, "held at stop");
    endtask

    task automatic zero_incr_test();
        $display("[TEST] zero_incr_test");
        apply_reset();
        ftw_start <= 'h123;
        ftw_stop  <= 'h1000;
        ftw_incr  <= 0;
        load      <= 1;
        step();
        load <= 0;
        repeat (5) begin
            step();
            check('h123, "zero incr");
        end
    endtask

    task automatic async_reset_test();
        $display("[TEST] async_reset_test");
        apply_reset();
        ftw_start <= 'h100;
        ftw_stop  <= 'h1000;
        ftw_incr  <= 'h10;
        load      <= 1;
        step();
        load <= 0;
        step();
        step();

        #7 rst_n <= 0;
        #1;
        check(0, "async reset");
        rst_n <= 1;
    endtask

    task automatic randomized_test(int n_cycles);
        logic [ACC_WIDTH-1:0] model;
        logic [ACC_WIDTH:0]   sum;
        $display("[TEST] randomized_test");
        apply_reset();
        model = 0;

        for (int i = 0; i < n_cycles; i++) begin
            ftw_start  <= $urandom_range((1 << ACC_WIDTH) - 1, 0);
            ftw_stop   <= $urandom_range((1 << ACC_WIDTH) - 1, 0);
            ftw_incr   <= $urandom_range((1 << ACC_WIDTH) - 1, 0);
            continious <= $urandom_range(1, 0);
            load       <= ($urandom_range(7, 0) == 0);
            step();
            if (load)
                model = ftw_start;
            else if (continious)
                model = model + ftw_incr;
            else begin
                sum = {1'b0, model} + ftw_incr;
                model = (sum < {1'b0, ftw_stop}) ? sum[ACC_WIDTH-1:0] : ftw_stop;
            end
            check(model, $sformatf("random step %0d", i));
        end
    endtask

    initial begin
        $dumpfile("lfm_ftw_generator_tb.vcd");
        $dumpvars(0, lfm_ftw_generator_tb);

        load_test();
        ramp_test();
        saturate_test();
        exact_stop_test();
        reload_test();
        load_priority_test();
        continious_wrap_test();
        continious_ignores_stop_test();
        mode_switch_test();
        overflow_saturate_test();
        zero_incr_test();
        async_reset_test();
        randomized_test(500);

        $display("ALL TESTS PASSED");
        $finish;
    end

    lfm_ftw_generator #(.ACC_WIDTH(ACC_WIDTH)) dut (
        .i_clk(clk),
        .i_rst_n(rst_n),
        .i_load(load),
        .i_continious(continious),
        .i_ftw_start(ftw_start),
        .i_ftw_stop(ftw_stop),
        .i_ftw_incr(ftw_incr),
        .o_ftw(ftw)
    );

endmodule
