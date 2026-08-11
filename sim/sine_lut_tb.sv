`timescale 1ns/1ns

module sine_lut_tb
#(
    parameter int ACC_WIDTH      = 24,
    parameter int LUT_ADDR_WIDTH = 10,
    parameter int DATA_WIDTH     = 12
);

    localparam int QUAD_ADDR_WIDTH = LUT_ADDR_WIDTH - 2;
    localparam int ROM_DEPTH       = 2 ** QUAD_ADDR_WIDTH;

    logic clk, rst_n;
    logic [ACC_WIDTH - 1 : 0] phase;
    logic signed [DATA_WIDTH - 1 : 0] amplitude;

    // reference copy of the ROM contents, used to build a golden model
    // independent of the DUT's own $readmemh call
    logic [DATA_WIDTH - 1 : 0] rom_model [0 : ROM_DEPTH - 1];

    initial begin
        $readmemh("rtl/sine_lut.hex", rom_model);
    end

    // DDS coarse address = top LUT_ADDR_WIDTH bits of the phase accumulator,
    // so a raw LUT address must be shifted up into those top bits to build
    // a full ACC_WIDTH-wide i_phase value that hits it.
    function automatic logic [ACC_WIDTH - 1 : 0] addr_to_phase(
        input logic [LUT_ADDR_WIDTH - 1 : 0] addr
    );
        addr_to_phase = {addr, {(ACC_WIDTH - LUT_ADDR_WIDTH){1'b0}}};
    endfunction

    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    initial begin
        #100000;
        $display("TIMEOUT: simulation did not finish in time");
        $stop;
    end

    function automatic logic signed [DATA_WIDTH - 1 : 0] golden_amplitude(
        input logic [LUT_ADDR_WIDTH - 1 : 0] addr
    );
        logic [1 : 0] quadrant;
        logic [QUAD_ADDR_WIDTH - 1 : 0] addr_in_quadrant;
        logic [QUAD_ADDR_WIDTH - 1 : 0] bram_addr;
        logic [DATA_WIDTH - 1 : 0] val;
        begin
            quadrant         = addr[LUT_ADDR_WIDTH - 1 -: 2];
            addr_in_quadrant = addr[QUAD_ADDR_WIDTH - 1 : 0];

            case (quadrant)
                2'b00: bram_addr = addr_in_quadrant;
                2'b01: bram_addr = ~addr_in_quadrant;
                2'b10: bram_addr = addr_in_quadrant;
                2'b11: bram_addr = ~addr_in_quadrant;
                default: bram_addr = '0;
            endcase

            val = rom_model[bram_addr];
            golden_amplitude = quadrant[1] ? ((~val) + 1) : val;
        end
    endfunction

    task automatic apply_reset();
        rst_n <= 0;
        phase <= 0;
        @(negedge clk);
        @(negedge clk);
        rst_n <= 1;
    endtask


    task automatic drive_and_capture(
        input  logic [ACC_WIDTH - 1 : 0] phase_val,
        output logic signed [DATA_WIDTH - 1 : 0] captured
    );
        @(negedge clk);
        phase <= phase_val;
        @(posedge clk);
        @(negedge clk);
        captured = amplitude;
    endtask

    task automatic check_phase(input logic [ACC_WIDTH - 1 : 0] phase_val);
        logic signed [DATA_WIDTH - 1 : 0] got, expected;
        drive_and_capture(phase_val, got);
        expected = golden_amplitude(phase_val[ACC_WIDTH - 1 -: LUT_ADDR_WIDTH]);
        assert (got == expected)
        else begin
            $display("phase=0x%06x: required %0d, current is %0d", phase_val, expected, got);
            $stop;
        end
    endtask

    // after reset, the pipeline registers are cleared and amplitude must be 0
    task automatic reset_test();
        $display("[TEST] reset_test");
        apply_reset();
        assert (amplitude == 0)
        else begin
            $display("Required 0, current is %0d", amplitude);
            $stop;
        end
    endtask

    // quadrant boundaries, where the mirroring/sign logic is most likely to break
    task automatic boundary_test();
        $display("[TEST] boundary_test");
        apply_reset();

        check_phase(addr_to_phase(10'h000)); // quadrant 0, addr_in_quadrant = 0
        check_phase(addr_to_phase(10'h0FF)); // quadrant 0, addr_in_quadrant = max
        check_phase(addr_to_phase(10'h100)); // quadrant 1, addr_in_quadrant = 0   -> mirrors to rom[255]
        check_phase(addr_to_phase(10'h1FF)); // quadrant 1, addr_in_quadrant = max -> mirrors to rom[0]
        check_phase(addr_to_phase(10'h200)); // quadrant 2, addr_in_quadrant = 0
        check_phase(addr_to_phase(10'h2FF)); // quadrant 2, addr_in_quadrant = max
        check_phase(addr_to_phase(10'h300)); // quadrant 3, addr_in_quadrant = 0   -> mirrors to rom[255]
        check_phase(addr_to_phase(10'h3FF)); // quadrant 3, addr_in_quadrant = max -> mirrors to rom[0]
    endtask

    // structural invariant of a quarter-wave LUT sine, checked directly on
    // DUT outputs (no dependence on rom_model / the golden function):
    //   quadrant 2 must be the negation of quadrant 0 at the same addr_in_quadrant
    //   quadrant 1 must mirror quadrant 0 (addr_in_quadrant reversed)
    task automatic quadrant_symmetry_test();
        logic signed [DATA_WIDTH - 1 : 0] q0, q1, q2, q3;
        logic [QUAD_ADDR_WIDTH - 1 : 0] addr, mirrored_addr;
        $display("[TEST] quadrant_symmetry_test");
        apply_reset();

        for (int a = 0; a < ROM_DEPTH; a += 37) begin
            addr          = a[QUAD_ADDR_WIDTH-1:0];
            mirrored_addr = (ROM_DEPTH - 1 - a);

            drive_and_capture(addr_to_phase({2'b00, addr}), q0);
            drive_and_capture(addr_to_phase({2'b10, addr}), q2);
            assert (q2 == -q0)
            else begin
                $display("addr_in_quadrant=%0d: quad2 (%0d) != -quad0 (%0d)", a, q2, q0);
                $stop;
            end

            drive_and_capture(addr_to_phase({2'b01, addr}), q1);
            drive_and_capture(addr_to_phase({2'b00, mirrored_addr}), q0);
            assert (q1 == q0)
            else begin
                $display("addr_in_quadrant=%0d: quad1 (%0d) != mirrored quad0 (%0d)", a, q1, q0);
                $stop;
            end

            drive_and_capture(addr_to_phase({2'b11, a[QUAD_ADDR_WIDTH-1:0]}), q3);
            assert (q3 == -q1)
            else begin
                $display("addr_in_quadrant=%0d: quad3 (%0d) != -quad1 (%0d)", a, q3, q1);
                $stop;
            end
        end
    endtask

    // the low (ACC_WIDTH - LUT_ADDR_WIDTH) bits of i_phase are the
    // fine/fractional phase: sine_lut takes its ROM address from the top
    // LUT_ADDR_WIDTH bits only, so the low bits must have no effect on
    // o_amplitude within a single sample
    task automatic unused_bits_test();
        logic [ACC_WIDTH - 1 : 0] phase_val;
        $display("[TEST] unused_bits_test");
        apply_reset();

        for (int i = 0; i < 20; i++) begin
            phase_val = {10'h0AB, $urandom_range((1 << (ACC_WIDTH - LUT_ADDR_WIDTH)) - 1, 0)};
            check_phase(phase_val);
        end
    endtask

    // randomized phases checked against the golden model
    task automatic randomized_test(int n_cycles);
        $display("[TEST] randomized_test");
        apply_reset();

        for (int i = 0; i < n_cycles; i++) begin
            check_phase($urandom_range((1 << ACC_WIDTH) - 1, 0));
        end
    endtask

    initial begin
        $dumpfile("sine_lut_tb.vcd");
        $dumpvars(0, sine_lut_tb);

        reset_test();
        boundary_test();
        quadrant_symmetry_test();
        unused_bits_test();
        randomized_test(200);

        $display("ALL TESTS PASSED");
        $finish;
    end

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
