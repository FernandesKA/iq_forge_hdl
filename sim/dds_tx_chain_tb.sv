`timescale 1ns/1ns

module dds_tx_chain_tb;

    localparam int ACC_WIDTH      = 24;
    localparam int LUT_ADDR_WIDTH = 10;
    localparam int DATA_WIDTH     = 12; // должно совпадать с sine_lut.DATA_WIDTH (дефолт)

    logic clk, rst_n, en;
    logic mode, lfm_continious, lfm_load;
    logic [ACC_WIDTH - 1 : 0] ftw;
    logic [ACC_WIDTH - 1 : 0] lfm_ftw_start, lfm_ftw_stop, lfm_ftw_incr;

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

        // одна лишняя выборка на прогрев дополнительного pipeline-регистра
        // tx_i/tx_q перед ad9361_tx_lvds (dds_tx_chain.sv) -- сразу после
        // en первый принятый отсчёт ещё может быть тем самым "нулевым"
        // значением, что было до включения.
        receive_sample(got_i, got_q);

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
    // TEST 3: отключение en в процессе генерации -- второй принятый
    // отсчёт должен быть строго нулевым, без "хвоста" от предыдущего
    // ненулевого состояния. (Один отсчёт "хвоста" теперь ожидаем и не
    // проверяем -- см. pipeline-регистр tx_i/tx_q в dds_tx_chain.sv,
    // добавленный для timing closure на повышенной i_clk.)
    // ------------------------------------------------------------------
    task automatic disable_test();
        logic signed [DATA_WIDTH-1:0] got_i, got_q;
        $display("[TEST] disable_test");

        en = 0;

        receive_sample(got_i, got_q);
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


    // ------------------------------------------------------------------
    // Измерение мгновенной частоты по фазовому шагу между соседними
    // отсчётами: FTW_est = |d(atan2(Q, I))| / 2pi * 2^ACC_WIDTH. Модуль --
    // чтобы не зависеть от направления вращения LUT. Точность ограничена
    // 12-битным квантованием (~+-3e3 LSB FTW на отсчёт), поэтому проверки
    // ниже сравнивают средние по окну и тренд, а не отдельные отсчёты.
    // ------------------------------------------------------------------
    localparam real PI = 3.14159265358979;
    localparam int MAX_TRACE = 512;
    real ftw_trace [MAX_TRACE];

    task automatic capture_ftw_trace(input int n_samples);
        logic signed [DATA_WIDTH-1:0] got_i, got_q;
        real prev_angle, angle, d;

        receive_sample(got_i, got_q);
        prev_angle = $atan2(real'(got_q), real'(got_i));

        for (int k = 0; k < n_samples; k++) begin
            receive_sample(got_i, got_q);
            angle = $atan2(real'(got_q), real'(got_i));
            d = angle - prev_angle;
            while (d > PI)   d -= 2.0 * PI;
            while (d <= -PI) d += 2.0 * PI;
            if (d < 0.0) d = -d;
            ftw_trace[k] = d / (2.0 * PI) * (2.0 ** ACC_WIDTH);
            prev_angle = angle;
        end
    endtask

    function automatic real trace_avg(input int from_idx, input int count);
        real acc;
        acc = 0.0;
        for (int k = from_idx; k < from_idx + count; k++) acc += ftw_trace[k];
        return acc / real'(count);
    endfunction

    task automatic check_near(input real got, input real expected, input real tol, input string what);
        real diff;
        diff = got - expected;
        if (diff < 0.0) diff = -diff;
        assert (diff <= tol)
        else begin
            $display("%s: expected FTW ~%0f (+-%0f), measured %0f", what, expected, tol, got);
            $stop;
        end
    endtask

    // ------------------------------------------------------------------
    // TEST 4: sine-режим (mode=0) держит именно i_ftw -- раньше
    // LFM был жёстко прошит в цепочку и частота уплывала по рампе.
    // ------------------------------------------------------------------
    task automatic sine_freq_test();
        $display("[TEST] sine_freq_test");

        mode = 0;
        en   = 1;
        ftw  = 24'h051EB8;
        repeat (4) @(negedge clk);

        capture_ftw_trace(40);
        check_near(trace_avg(0, 20),  real'(24'h051EB8), 8000.0, "sine_freq_test (first half)");
        check_near(trace_avg(20, 20), real'(24'h051EB8), 8000.0, "sine_freq_test (second half)");
    endtask

    // ------------------------------------------------------------------
    // TEST 5: LFM. Сначала en=0 -- счётчик удерживается на start; после en=1
    // частота растёт от start (тренд по окнам) и упирается в stop
    // (one-shot, continious=0), после чего держится на stop.
    // ------------------------------------------------------------------
    task automatic lfm_sweep_test();
        $display("[TEST] lfm_sweep_test");

        en             = 0;
        mode           = 1;
        lfm_continious = 0;
        lfm_load       = 0;
        lfm_ftw_start  = 24'h010000;
        lfm_ftw_stop   = 24'h400000;
        lfm_ftw_incr   = 24'h004000; // +0x8000 FTW за отсчёт (2 такта), ~126 отсчётов до stop
        repeat (6) @(negedge clk);

        en = 1;
        capture_ftw_trace(200);

        // первые отсчёты после en (пропускаем прогрев pipeline) -- близко к start
        check_near(trace_avg(3, 6), real'(24'h010000) + 4.0 * real'(24'h008000), 60000.0, "lfm_sweep_test (start of sweep)");

        // середина свипа заметно выше начала, конец -- на stop
        assert (trace_avg(60, 6) > trace_avg(3, 6) + 0.25 * real'(24'h400000 - 24'h010000))
        else begin
            $display("lfm_sweep_test: frequency did not rise (start avg %0f, mid avg %0f)", trace_avg(3, 6), trace_avg(60, 6));
            $stop;
        end

        check_near(trace_avg(190, 10), real'(24'h400000), 16000.0, "lfm_sweep_test (saturated at stop)");
    endtask

    // ------------------------------------------------------------------
    // TEST 6: фронт lfm_load перезапускает свип с start, даже если счётчик
    // уже упёрся в stop (без выключения en).
    // ------------------------------------------------------------------
    task automatic lfm_load_test();
        $display("[TEST] lfm_load_test");

        // lfm_load остаётся в 1 на всё время захвата: перезапуск должен быть
        // по фронту, а не по уровню -- иначе частота осталась бы залипшей на
        // start, а не продолжила растить рампу.
        @(negedge clk); // по negedge -- без гонки с фронтом, по которому DUT семплирует
        lfm_load = 1;

        capture_ftw_trace(30);

        // после перезапуска частота снова около start ...
        assert (trace_avg(4, 6) < 0.5 * real'(24'h400000))
        else begin
            $display("lfm_load_test: sweep did not restart, avg FTW %0f", trace_avg(4, 6));
            $stop;
        end

        // ... и дальше растёт (фронт, а не удержание в загрузке)
        assert (trace_avg(24, 6) > trace_avg(4, 6) + 0.05 * real'(24'h400000))
        else begin
            $display("lfm_load_test: sweep stuck after restart (held load acted as level), avg %0f -> %0f",
                     trace_avg(4, 6), trace_avg(24, 6));
            $stop;
        end

        lfm_load = 0;
    endtask

    // ------------------------------------------------------------------
    // TEST 7: возврат в sine-режим на ходу -- частота снова строго i_ftw.
    // ------------------------------------------------------------------
    task automatic back_to_sine_test();
        $display("[TEST] back_to_sine_test");

        mode = 0;
        ftw  = 24'h0A3D70;
        repeat (4) @(negedge clk);

        capture_ftw_trace(40);
        check_near(trace_avg(10, 20), real'(24'h0A3D70), 8000.0, "back_to_sine_test");
    endtask

    initial begin
        $dumpfile("dds_tx_chain_tb.vcd");
        $dumpvars(0, dds_tx_chain_tb);

        rst_n = 0;
        en    = 0;
        mode  = 0;
        ftw   = 0;
        lfm_continious = 0;
        lfm_load       = 0;
        lfm_ftw_start  = 0;
        lfm_ftw_stop   = 0;
        lfm_ftw_incr   = 0;
        repeat (2) @(negedge clk);
        rst_n = 1;

        wait (glbl.GSR == 1'b0);
        @(posedge clk);

        reset_test();
        enable_test(30);
        sine_freq_test();
        lfm_sweep_test();
        lfm_load_test();
        back_to_sine_test();
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
        .i_mode(mode),
        .i_ftw(ftw),
        .i_lfm_continious(lfm_continious),
        .i_lfm_load(lfm_load),
        .i_lfm_ftw_start(lfm_ftw_start),
        .i_lfm_ftw_stop(lfm_ftw_stop),
        .i_lfm_ftw_incr(lfm_ftw_incr),
        .o_tx_d_p(tx_d_p),
        .o_tx_d_n(tx_d_n),
        .o_tx_frame_p(tx_frame_p),
        .o_tx_frame_n(tx_frame_n),
        .o_fb_clk_p(fb_clk_p),
        .o_fb_clk_n(fb_clk_n)
    );

endmodule