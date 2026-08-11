`timescale 1ns/1ns

module sine_lut_sweep_tb
#(
    parameter int ACC_WIDTH      = 24,
    parameter int LUT_ADDR_WIDTH = 10,
    parameter int DATA_WIDTH     = 12,
    parameter int PERIODS        = 3 // full sine periods to sweep through
);

    localparam logic [ACC_WIDTH - 1 : 0] LUT_STEP = ACC_WIDTH'(1) << (ACC_WIDTH - LUT_ADDR_WIDTH);
    localparam int LUT_PERIOD_CYCLES = 2 ** LUT_ADDR_WIDTH;

    logic clk, rst_n, ce;
    logic [ACC_WIDTH - 1 : 0] ftw, phase;
    logic signed [DATA_WIDTH - 1 : 0] amplitude;

    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    initial begin
        #(PERIODS * LUT_PERIOD_CYCLES * 20 + 10000);
        $display("TIMEOUT: simulation did not finish in time");
        $stop;
    end

    initial begin
        $dumpfile("sine_lut_sweep_tb.vcd");
        $dumpvars(0, sine_lut_sweep_tb);

        rst_n = 0;
        ce    = 0;
        ftw   = 0;
        repeat (2) @(negedge clk);
        rst_n = 1;
        ftw   = LUT_STEP;
        ce    = 1;

        repeat (PERIODS * LUT_PERIOD_CYCLES) @(posedge clk);

        $display("Swept %0d full sine period(s) over %0d cycles - inspect o_amplitude in the waveform viewer",
                  PERIODS, PERIODS * LUT_PERIOD_CYCLES);
        $finish;
    end

    phase_acc #(
        .ACC_WIDTH(ACC_WIDTH)
    ) phase_acc_dut (
        .i_clk(clk),
        .i_rst_n(rst_n),
        .i_ce(ce),
        .i_ftw(ftw),
        .o_phase(phase)
    );

    sine_lut #(
        .ACC_WIDTH(ACC_WIDTH),
        .LUT_ADDR_WIDTH(LUT_ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) sine_lut_dut (
        .i_clk(clk),
        .i_rst_n(rst_n),
        .i_phase(phase),
        .o_amplitude(amplitude)
    );

endmodule
