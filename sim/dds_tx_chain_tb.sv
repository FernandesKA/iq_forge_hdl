`timescale 1ns/1ns

module dds_tx_chain_tb;

    localparam int ACC_WIDTH      = 24;
    localparam int LUT_ADDR_WIDTH = 10;
    localparam int DATA_WIDTH     = 12; // должно совпадать с sine_lut.DATA_WIDTH (дефолт)

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
        #1000000;
        $display("TIMEOUT: simulation did not finish in time");
        $stop;
    end

    // ------------------------------------------------------------------
    // Golden receiver -- перенесено без изменений из ad9361_tx_lvds_tb.
    // Реальное фазовое соотношение (см. историю проекта): posedge
    // fb_clk_p несёт Q и совпадает со сменой уровня frame; negedge
    // fb_clk_p несёт I, уровень frame не меняется.
    // ------------------------------------------------------------------
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
        assert (tx_frame_p == 1'b0)
        else begin
            $display("receive_sample: expected frame to drop to LSB half, but tx_frame_p=%b", tx_frame_p);
            $stop;
        end
        q_lsb = tx_d_p;

        @(negedge fb_clk_p);
        #1;
        i_lsb = tx_d_p;

        captured_i = {i_msb, i_lsb};
        captured_q = {q_msb, q_lsb};
    endtask

    // ------------------------------------------------------------------
    // TEST 1: после reset, до включения en, ожидаем нули на выходе --
    // проверяет и сам reset, и то, что en по умолчанию не "протекает"
    // мимо мультиплексора.
    // ------------------------------------------------------------------
    task automatic reset_test();
        logic signed [DATA_WIDTH-1:0] got_i, got_q;
        $display("[TEST] reset_test");

        en  = 0;
        ftw = 24'h100000; // ненулевой ftw -- проверяем, что именно en держит выход в нуле, а не отсутствие ftw

        receive_sample(got_i, got_q);

        assert (got_i == 0)
        else begin
            $display("reset_test: expected I=0 while en=0, got %0d", got_i);
            $stop;
        end

        assert (got_q == 0)
        else begin
            $display("reset_test: expected Q=0 while en=0, got %0d", got_q);
            $stop;
        end
    endtask

    // ------------------------------------------------------------------
    // TEST 2: включаем генерацию, проверяем на протяжении многих
    // отсчётов инвариант единичной окружности I^2+Q^2 ~= const --
    // интеграционная проверка согласованности всей цепочки, без
    // дублирования golden ROM-модели из sine_lut_tb/ad9361_tx_lvds_tb.
    // Допуск взят с запасом на квантование LUT (12 бит, полная шкала
    // 2^11-1) и на неидеальность самого квартально-симметричного LUT.
    // ------------------------------------------------------------------
    task automatic enable_test(int n_samples);
        logic signed [DATA_WIDTH-1:0] got_i, got_q;
        real magnitude_sq, expected_sq, full_scale;
        real tolerance;

        $display("[TEST] enable_test (%0d samples)", n_samples);

        en  = 1;
        ftw = 24'h051EB8; // произвольная ненулевая частота

        full_scale  = (2.0 ** (DATA_WIDTH - 1)) - 1.0;
        expected_sq = full_scale * full_scale;
        tolerance   = expected_sq * 0.05; // 5% запас на квантование LUT

        for (int k = 0; k < n_samples; k++) begin
            receive_sample(got_i, got_q);

            // пропускаем сэмплы возле нуля одной из осей, где абсолютная
            // ошибка квантования относительно свежей величины может быть
            // непропорционально велика -- сфокусируемся на общей форме
            magnitude_sq = real'(got_i) * real'(got_i) + real'(got_q) * real'(got_q);

            assert (magnitude_sq > (expected_sq - tolerance) &&
                     magnitude_sq < (expected_sq + tolerance))
            else begin
                $display("enable_test: sample %0d off unit circle: I=%0d Q=%0d I^2+Q^2=%0f (expected ~%0f +-%0f)",
                          k, got_i, got_q, magnitude_sq, expected_sq, tolerance);
                $stop;
            end
        end
    endtask

    // ------------------------------------------------------------------
    // TEST 3: отключение en в процессе генерации -- следующий же принятый
    // отсчёт должен быть строго нулевым, без "хвоста" от предыдущего
    // ненулевого состояния.
    // ------------------------------------------------------------------
    task automatic disable_test();
        logic signed [DATA_WIDTH-1:0] got_i, got_q;
        $display("[TEST] disable_test");

        en = 0;

        receive_sample(got_i, got_q);

        assert (got_i == 0)
        else begin
            $display("disable_test: expected I=0 right after disabling en, got %0d", got_i);
            $stop;
        end

        assert (got_q == 0)
        else begin
            $display("disable_test: expected Q=0 right after disabling en, got %0d", got_q);
            $stop;
        end
    endtask

    initial begin
        $dumpfile("dds_tx_chain_tb.vcd");
        $dumpvars(0, dds_tx_chain_tb);

        rst_n = 0;
        en    = 0;
        ftw   = 0;
        repeat (2) @(negedge clk);
        rst_n = 1;

        wait (glbl.GSR == 1'b0);
        @(posedge clk);

        reset_test();
        enable_test(30);
        disable_test();

        $display("ALL TESTS PASSED");
        $finish;
    end

    dds_tx_chain #(
        .ACC_WIDTH(ACC_WIDTH),
        .LUT_ADDR_WIDTH(LUT_ADDR_WIDTH)
    ) dut (
        .i_clk(clk),
        .i_rst_n(rst_n),
        .i_en(en),
        .i_ftw(ftw),
        .o_tx_d_p(tx_d_p),
        .o_tx_d_n(tx_d_n),
        .o_tx_frame_p(tx_frame_p),
        .o_tx_frame_n(tx_frame_n),
        .o_fb_clk_p(fb_clk_p),
        .o_fb_clk_n(fb_clk_n)
    );

endmodule