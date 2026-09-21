`timescale 1ns/1ns
//
// Диагностический тестбенч (не часть штатного sim/): dds_tx_chain_tb.sv
// проверяет только magnitude (I^2+Q^2 ~= const), что НЕ чувствительно к
// фиксированному временному сдвигу между I и Q -- такой сдвиг сохраняет
// magnitude, но портит фазовую прогрессию (= портит представленную
// частоту). Этот тестбенч меряет реальный фазовый прирост между
// последовательными переданными сэмплами через $atan2 и сравнивает его с
// ожидаемым из FTW, для двух разных FTW -- если баг есть, измеренный
// прирост не будет пропорционален FTW.
//
module dds_freq_probe_tb;

    localparam int ACC_WIDTH      = 24;
    localparam int LUT_ADDR_WIDTH = 10;
    localparam int DATA_WIDTH     = 12;
    localparam int N_SAMPLES      = 60;
    localparam int SKIP_SAMPLES   = 8; // дать пайплайну LUT устаканиться

    logic clk, rst_n, en;
    logic [ACC_WIDTH - 1 : 0] ftw;

    logic [5:0] tx_d_p, tx_d_n;
    logic tx_frame_p, tx_frame_n;
    logic fb_clk_p, fb_clk_n;

    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    initial begin
        #2000000;
        $display("TIMEOUT");
        $stop;
    end

    task automatic receive_sample(
        output logic signed [DATA_WIDTH-1:0] captured_i,
        output logic signed [DATA_WIDTH-1:0] captured_q
    );
        logic [5:0] i_msb, q_msb, i_lsb, q_lsb;

        do begin
            @(posedge fb_clk_p);
            #1;
        end while (tx_frame_p !== 1'b1);
        q_msb = tx_d_p;

        @(negedge fb_clk_p);
        #1;
        i_msb = tx_d_p;

        @(posedge fb_clk_p);
        #1;
        q_lsb = tx_d_p;

        @(negedge fb_clk_p);
        #1;
        i_lsb = tx_d_p;

        captured_i = {i_msb, i_lsb};
        captured_q = {q_msb, q_lsb};
    endtask

    task automatic measure_phase_step(input logic [ACC_WIDTH-1:0] test_ftw, output real avg_step);
        logic signed [DATA_WIDTH-1:0] got_i, got_q;
        real phase [0:N_SAMPLES-1];
        real d, sum;
        int  n;

        en  = 1;
        ftw = test_ftw;

        for (int k = 0; k < SKIP_SAMPLES; k++) begin
            receive_sample(got_i, got_q);
        end

        for (int k = 0; k < N_SAMPLES; k++) begin
            receive_sample(got_i, got_q);
            phase[k] = $atan2(real'(got_q), real'(got_i));
        end

        sum = 0;
        n = 0;
        for (int k = 1; k < N_SAMPLES; k++) begin
            d = phase[k] - phase[k-1];
            // развернуть скачок через +-pi
            if (d > 3.14159265358979)  d -= 2.0 * 3.14159265358979;
            if (d < -3.14159265358979) d += 2.0 * 3.14159265358979;
            sum += d;
            n++;
        end
        avg_step = sum / real'(n);
    endtask

    initial begin
        real step1, step2, expected1, expected2;
        logic [ACC_WIDTH-1:0] FTW1, FTW2;

        rst_n = 0;
        en    = 0;
        ftw   = 0;
        repeat (2) @(negedge clk);
        rst_n = 1;
        wait (glbl.GSR == 1'b0);
        @(posedge clk);

        FTW1 = 24'h080000; // 524288
        FTW2 = 24'h100000; // 1048576 = 2x FTW1

        measure_phase_step(FTW1, step1);
        measure_phase_step(FTW2, step2);

        expected1 = real'(FTW1) * 2.0 * 3.14159265358979 / real'(2**ACC_WIDTH);
        expected2 = real'(FTW2) * 2.0 * 3.14159265358979 / real'(2**ACC_WIDTH);

        $display("FTW1=0x%06h expected_step=%0f measured_step=%0f", FTW1, expected1, step1);
        $display("FTW2=0x%06h expected_step=%0f measured_step=%0f", FTW2, expected2, step2);
        $display("ratio measured2/measured1 = %0f (expected ~2.0 if FTW controls frequency)", step2/step1);

        $finish;
    end

    dds_tx_chain #(
        .ACC_WIDTH(ACC_WIDTH),
        .LUT_ADDR_WIDTH(LUT_ADDR_WIDTH)
    ) dut (
        .i_clk(clk),
        .i_rst_n(rst_n),
        .i_en(en),
        .i_mode(1'b0),
        .i_ftw(ftw),
        .i_lfm_continious(1'b0),
        .i_lfm_load(1'b0),
        .i_lfm_ftw_start('0),
        .i_lfm_ftw_stop('0),
        .i_lfm_ftw_incr('0),
        .o_tx_d_p(tx_d_p),
        .o_tx_d_n(tx_d_n),
        .o_tx_frame_p(tx_frame_p),
        .o_tx_frame_n(tx_frame_n),
        .o_fb_clk_p(fb_clk_p),
        .o_fb_clk_n(fb_clk_n)
    );

endmodule
