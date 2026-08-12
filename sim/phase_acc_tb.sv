`timescale 1ps/1ps

module phase_acc_tb
#(parameter ACC_WIDTH = 24);

    logic clk, rst, ce;
    logic [ACC_WIDTH - 1 : 0] phase, ftw;

    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    // safety net so a stuck test doesn't hang the sim
    initial begin
        #100000;
        $display("TIMEOUT: simulation did not finish in time");
        $stop;
    end

    task automatic apply_reset();
        rst <= 0;
        ce  <= 0;
        ftw <= 0;
        @(negedge clk);
        rst <= 1;
    endtask

    // basic increment: fixed ftw, ce=1, check phase == ftw*(i+1)
    task automatic basic_increment_test();
        $display("[TEST] basic_increment_test");
        apply_reset();
        ftw <= 'h20;
        ce  <= 1;

        for (int i = 0; i < 10; i++) begin
            @(posedge clk);
            @(negedge clk);
            assert (phase == ftw * (i + 1))
            else begin
                $display("Required 0x%x, current is 0x%x", ftw * (i + 1), phase);
                $stop;
            end
        end
    endtask

    // ce=0 must freeze the accumulator
    task automatic ce_freeze_test();
        logic [ACC_WIDTH-1:0] snapshot;
        $display("[TEST] ce_freeze_test");
        apply_reset();
        ftw <= 'h20;
        ce  <= 1;

        @(posedge clk);
        @(negedge clk);
        snapshot = phase;
        ce <= 0;

        repeat (5) begin
            @(posedge clk);
            @(negedge clk);
            assert (phase == snapshot)
            else begin
                $display("Phase changed while ce=0: expected 0x%x, got 0x%x", snapshot, phase);
                $stop;
            end
        end
        ce <= 1;
    endtask

    // changing ftw mid-run must take effect on the following cycle
    task automatic ftw_change_test();
        logic [ACC_WIDTH-1:0] expected;
        $display("[TEST] ftw_change_test");
        apply_reset();
        ftw <= 'h10;
        ce  <= 1;

        @(posedge clk);
        @(negedge clk);
        expected = 'h10;
        assert (phase == expected)
        else begin
            $display("Required 0x%x, current is 0x%x", expected, phase);
            $stop;
        end

        ftw <= 'h05;
        @(posedge clk);
        @(negedge clk);
        expected = expected + 'h05;
        assert (phase == expected)
        else begin
            $display("ftw change not applied: required 0x%x, current is 0x%x", expected, phase);
            $stop;
        end
    endtask

    // accumulator must wrap around modulo 2**ACC_WIDTH
    task automatic overflow_test();
        logic [ACC_WIDTH-1:0] half;
        $display("[TEST] overflow_test");
        apply_reset();
        half = 1 << (ACC_WIDTH - 1);
        ftw <= half;
        ce  <= 1;

        @(posedge clk);
        @(negedge clk);
        assert (phase == half)
        else begin
            $display("Required 0x%x, current is 0x%x", half, phase);
            $stop;
        end

        @(posedge clk);
        @(negedge clk);
        assert (phase == 0)
        else begin
            $display("Overflow wrap failed: required 0x0, current is 0x%x", phase);
            $stop;
        end
    endtask

    // async reset must clear phase immediately, independent of the clock edge
    task automatic async_reset_test();
        $display("[TEST] async_reset_test");
        apply_reset();
        ftw <= 'h20;
        ce  <= 1;

        @(posedge clk);
        @(negedge clk);
        @(posedge clk);
        @(negedge clk);

        #7 rst <= 0;
        #1;
        assert (phase == 0)
        else begin
            $display("Async reset failed, phase=0x%x", phase);
            $stop;
        end
        rst <= 1;
    endtask

    // randomized ftw checked against a reference accumulator model
    task automatic randomized_test(int n_cycles);
        logic [ACC_WIDTH-1:0] phase_model;
        $display("[TEST] randomized_test");
        apply_reset();
        ce <= 1;
        phase_model = 0;

        for (int i = 0; i < n_cycles; i++) begin
            ftw <= $urandom_range((1 << ACC_WIDTH) - 1, 0);
            @(posedge clk);
            @(negedge clk);
            phase_model = phase_model + ftw;
            assert (phase == phase_model)
            else begin
                $display("Random step %0d: required 0x%x, current is 0x%x", i, phase_model, phase);
                $stop;
            end
        end
    endtask

    initial begin
        $dumpfile("phase_acc_tb.vcd");
        $dumpvars(0, phase_acc_tb);

        basic_increment_test();
        ce_freeze_test();
        ftw_change_test();
        overflow_test();
        async_reset_test();
        randomized_test(50);

        $display("ALL TESTS PASSED");
        $finish;
    end

    phase_acc phase_acc_dut(
        .i_clk(clk),
        .i_rst_n(rst),
        .i_ce(ce),
        .i_ftw(ftw),
        .o_phase(phase)
    );

endmodule
