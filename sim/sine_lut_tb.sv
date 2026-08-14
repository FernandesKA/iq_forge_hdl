`timescale 1ns/1ns

module sine_lut_tb
#(
    parameter int ACC_WIDTH      = 24,
    parameter int LUT_ADDR_WIDTH = 10,
    parameter int DATA_WIDTH     = 12
);

    localparam int QUAD_ADDR_WIDTH = LUT_ADDR_WIDTH - 2;
    localparam int ROM_DEPTH       = 2 ** QUAD_ADDR_WIDTH;

    localparam logic [ACC_WIDTH - 1 : 0] QUARTER_TURN = (ACC_WIDTH'(1)) << (ACC_WIDTH - 2);

    logic clk, rst_n;
    logic [ACC_WIDTH - 1 : 0] phase;
    logic signed [DATA_WIDTH - 1 : 0] amplitude_i, amplitude_q;

    logic [DATA_WIDTH - 1 : 0] rom_model [0 : ROM_DEPTH - 1];

    initial begin
        $readmemh("rtl/sine_lut.hex", rom_model);
    end

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

    function automatic logic signed [DATA_WIDTH - 1 : 0] golden_q(
        input logic [ACC_WIDTH - 1 : 0] phase_val
    );
        golden_q = golden_amplitude(phase_val[ACC_WIDTH - 1 -: LUT_ADDR_WIDTH]);
    endfunction

    function automatic logic signed [DATA_WIDTH - 1 : 0] golden_i(
        input logic [ACC_WIDTH - 1 : 0] phase_val
    );
        logic [ACC_WIDTH - 1 : 0] shifted_phase;
        shifted_phase = phase_val + QUARTER_TURN;
        golden_i = golden_amplitude(shifted_phase[ACC_WIDTH - 1 -: LUT_ADDR_WIDTH]);
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
        output logic signed [DATA_WIDTH - 1 : 0] captured_i,
        output logic signed [DATA_WIDTH - 1 : 0] captured_q
    );
        @(negedge clk);
        phase <= phase_val;
        @(posedge clk);
        @(negedge clk);
        captured_i = amplitude_i;
        captured_q = amplitude_q;
    endtask

    task automatic check_phase(input logic [ACC_WIDTH - 1 : 0] phase_val);
        logic signed [DATA_WIDTH - 1 : 0] got_i, got_q, expected_i, expected_q;
        drive_and_capture(phase_val, got_i, got_q);
        expected_i = golden_i(phase_val);
        expected_q = golden_q(phase_val);
        assert (got_i == expected_i)
        else begin
            $display("phase=0x%06x: o_i required %0d, current is %0d", phase_val, expected_i, got_i);
            $stop;
        end
        assert (got_q == expected_q)
        else begin
            $display("phase=0x%06x: o_q required %0d, current is %0d", phase_val, expected_q, got_q);
            $stop;
        end
    endtask

    task automatic reset_test();
        $display("[TEST] reset_test");
        apply_reset();
        assert (amplitude_i == 0)
        else begin
            $display("o_i: required 0, current is %0d", amplitude_i);
            $stop;
        end
        assert (amplitude_q == 0)
        else begin
            $display("o_q: required 0, current is %0d", amplitude_q);
            $stop;
        end
    endtask

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

    task automatic quadrant_symmetry_test();
        logic signed [DATA_WIDTH - 1 : 0] unused_i, q0, q1, q2, q3;
        logic [QUAD_ADDR_WIDTH - 1 : 0] addr, mirrored_addr;
        $display("[TEST] quadrant_symmetry_test");
        apply_reset();

        for (int a = 0; a < ROM_DEPTH; a += 37) begin
            addr          = a[QUAD_ADDR_WIDTH-1:0];
            mirrored_addr = (ROM_DEPTH - 1 - a);

            drive_and_capture(addr_to_phase({2'b00, addr}), unused_i, q0);
            drive_and_capture(addr_to_phase({2'b10, addr}), unused_i, q2);
            assert (q2 == -q0)
            else begin
                $display("addr_in_quadrant=%0d: quad2 (%0d) != -quad0 (%0d)", a, q2, q0);
                $stop;
            end

            drive_and_capture(addr_to_phase({2'b01, addr}), unused_i, q1);
            drive_and_capture(addr_to_phase({2'b00, mirrored_addr}), unused_i, q0);
            assert (q1 == q0)
            else begin
                $display("addr_in_quadrant=%0d: quad1 (%0d) != mirrored quad0 (%0d)", a, q1, q0);
                $stop;
            end

            drive_and_capture(addr_to_phase({2'b11, a[QUAD_ADDR_WIDTH-1:0]}), unused_i, q3);
            assert (q3 == -q1)
            else begin
                $display("addr_in_quadrant=%0d: quad3 (%0d) != -quad1 (%0d)", a, q3, q1);
                $stop;
            end
        end
    endtask


    task automatic unused_bits_test();
        logic [ACC_WIDTH - 1 : 0] phase_val;
        $display("[TEST] unused_bits_test");
        apply_reset();

        for (int i = 0; i < 20; i++) begin
            phase_val = {10'h0AB, $urandom_range((1 << (ACC_WIDTH - LUT_ADDR_WIDTH)) - 1, 0)};
            check_phase(phase_val);
        end
    endtask

    task automatic randomized_test(int n_cycles);
        $display("[TEST] randomized_test");
        apply_reset();

        for (int i = 0; i < n_cycles; i++) begin
            check_phase($urandom_range((1 << ACC_WIDTH) - 1, 0));
        end
    endtask

    task automatic quadrature_relationship_test(int n_cycles);
        logic [ACC_WIDTH - 1 : 0] p;
        logic signed [DATA_WIDTH - 1 : 0] i_at_p, q_at_p, unused_i, q_at_p_plus_90;
        $display("[TEST] quadrature_relationship_test");
        apply_reset();

        for (int k = 0; k < n_cycles; k++) begin
            p = $urandom_range((1 << ACC_WIDTH) - 1, 0);
            drive_and_capture(p, i_at_p, q_at_p);
            drive_and_capture(p + QUARTER_TURN, unused_i, q_at_p_plus_90);
            assert (i_at_p == q_at_p_plus_90)
            else begin
                $display("phase=0x%06x: o_i (%0d) != o_q at phase+90deg (%0d)", p, i_at_p, q_at_p_plus_90);
                $stop;
            end
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
        quadrature_relationship_test(100);

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
        .o_i(amplitude_i),
        .o_q(amplitude_q)
    );

endmodule
