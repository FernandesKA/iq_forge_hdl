`timescale 1ns / 1ns

module irq_ctrl_tb #(
    parameter int N = 2
);

  logic clk, rst_n, irq;
  logic [N-1:0] evt, enable, clr, frc, status;

  int errors = 0;

  initial begin
    clk = 0;
    forever #10 clk = ~clk;
  end

  initial begin
    #100000;
    $display("TIMEOUT: simulation did not finish at %0t", $time);
    $stop;
  end

  task automatic tick(int n = 1);
    repeat (n) @(negedge clk);
  endtask

  task automatic check(input logic [N-1:0] exp_status, input logic exp_irq, input string what);
    if (status !== exp_status || irq !== exp_irq) begin
      $display("FAIL @%0t %s: status required %b, current is %b; irq required %b, current is %b",
               $time, what, exp_status, status, exp_irq, irq);
      errors++;
    end
  endtask

  task automatic idle_inputs();
    evt <= '0;
    clr <= '0;
    frc <= '0;
  endtask

  task automatic apply_reset();
    idle_inputs();
    enable <= '0;
    rst_n  <= 0;
    tick();
    rst_n <= 1;
  endtask

  task automatic pulse_evt(input logic [N-1:0] mask);
    evt <= mask;
    tick();
    evt <= '0;
  endtask

  task automatic pulse_clr(input logic [N-1:0] mask);
    clr <= mask;
    tick();
    clr <= '0;
  endtask

  task automatic pulse_frc(input logic [N-1:0] mask);
    frc <= mask;
    tick();
    frc <= '0;
  endtask

  task automatic evt_without_enable();
    apply_reset();
    pulse_evt('1);
    check('1, 0, "evt without enable: status set");
    tick();
    check('1, 0, "evt without enable: irq stays 0");
    enable <= '1;
    tick();
    check('1, 1, "evt without enable: irq after enable");
  endtask

  task automatic clr_test();
    apply_reset();
    enable <= '1;
    pulse_evt('1);
    tick();
    check('1, 1, "clr: irq active before clr");
    pulse_clr('1);
    check('0, 1, "clr: status cleared");
    tick();
    check('0, 0, "clr: irq dropped");
  endtask

  task automatic evt_and_clr();
    apply_reset();
    enable <= '1;
    evt <= '1;
    clr <= '1;
    tick();
    idle_inputs();
    check('1, 0, "evt and clr from idle: status set");
    tick();
    check('1, 1, "evt and clr from idle: irq set");

    evt <= '1;
    clr <= '1;
    tick();
    idle_inputs();
    tick();
    check('1, 1, "evt and clr while pending: still set");
  endtask

  task automatic frc_test();
    apply_reset();
    pulse_frc('1);
    check('1, 0, "frc without enable: status set");
    enable <= '1;
    tick();
    check('1, 1, "frc: irq after enable");
    pulse_clr('1);
    tick();
    check('0, 0, "frc: cleared by clr");

    frc <= '1;
    clr <= '1;
    tick();
    idle_inputs();
    tick();
    check('1, 1, "frc and clr: still set");
  endtask

  task automatic two_sources();
    logic [N-1:0] b0 = N'(1) << 0;
    logic [N-1:0] b1 = N'(1) << 1;

    apply_reset();
    enable <= b1;
    pulse_evt(b0);
    tick();
    check(b0, 0, "two sources: src0 set, masked");
    pulse_evt(b1);
    tick();
    check(b0 | b1, 1, "two sources: src1 set, enabled");
    pulse_clr(b1);
    tick();
    check(b0, 0, "two sources: clr src1 keeps src0");
    enable <= b0;
    tick();
    check(b0, 1, "two sources: enable src0");
    pulse_clr(b0);
    tick();
    check('0, 0, "two sources: clr src0");
  endtask

  task automatic reset_during_irq();
    apply_reset();
    enable <= '1;
    pulse_evt('1);
    tick();
    check('1, 1, "reset during irq: irq active");

    rst_n <= 0;
    tick();
    rst_n <= 1;
    check('0, 0, "reset during irq: cleared by reset");
    tick(2);
    check('0, 0, "reset during irq: stays cleared");

    pulse_evt('1);
    tick();
    check('1, 1, "reset during irq: works after reset");
  endtask

  initial begin
    if (N < 2) $fatal(1, "irq_ctrl_tb needs N >= 2 (two_sources test)");

    rst_n  = 0;
    enable = '0;
    evt    = '0;
    clr    = '0;
    frc    = '0;
    tick();

    evt_without_enable();
    clr_test();
    evt_and_clr();
    frc_test();
    two_sources();
    reset_during_irq();

    if (errors == 0) $display("ALL TESTS PASSED");
    else $display("%0d CHECK(S) FAILED", errors);
    $finish;
  end

  irq_ctrl #(
      .N(N)
  ) dut (
      .i_clk(clk),
      .i_rst_n(rst_n),
      .i_enable(enable),
      .i_event(evt),
      .i_clr(clr),
      .i_force(frc),
      .o_status(status),
      .o_irq(irq)
  );

endmodule
