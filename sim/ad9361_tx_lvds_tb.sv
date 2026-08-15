`timescale 1ns/1ns

module ad9361_tx_lvds_tb;

    logic clk, rst_n;
    logic signed [11:0] tx_i, tx_q;

    logic [5:0] tx_d_p, tx_d_n;
    logic tx_frame_p, tx_frame_n;
    logic fb_clk_p, fb_clk_n;

    localparam time CLK_HALF_PERIOD = 10;
    // fb_clk_p и tx_d_p/tx_frame_p оба тактируются от clk через ODDR без
    // взаимного фазового сдвига, поэтому их фронты совпадают по времени --
    // данные валидны не сразу после фронта fb_clk_p, а только в середине
    // между двумя соседними фронтами. Эмулируем приёмник с задержкой
    // выборки на четверть периода (как AD9361 делает через калибровку
    // задержки на своей стороне), а не сэмплирование прямо на границе.
    localparam time SAMPLE_DELAY = CLK_HALF_PERIOD / 2;

    // системный клок питает и DUT, и (форвардно) FB_CLK, который DUT сам
    // генерирует у себя внутри через fb_clk_gen
    initial begin
        clk = 0;
        forever #CLK_HALF_PERIOD clk = ~clk;
    end

    initial begin
        #1000000;
        $display("TIMEOUT: simulation did not finish in time");
        $stop;
    end

    // ------------------------------------------------------------------
    // Golden receiver: играет роль AD9361 на другом конце LVDS-линии.
    // Сэмплирует tx_d_p на каждом фронте fb_clk_p, ориентируясь на
    // уровень tx_frame_p, чтобы понять, какая половина (MSB/LSB) сейчас
    // передаётся, и реконструирует полные 12-битные I/Q.
    //
    // Реальный порядок в этом DUT (fb_clk_p и tx_frame_p/tx_d_p тактируются
    // одним и тем же i_clk через отдельные ODDR без фазового сдвига между
    // ними, поэтому фронт fb_clk_p, на котором tx_frame_p меняет уровень,
    // одновременно несёт Q; I появляется на промежуточном фронте):
    //   TX_FRAME=1 период: сразу на фронте, поднявшем frame -- Q[11:6],
    //                       на следующем (противоположном) фронте -- I[11:6]
    //   TX_FRAME=0 период: сразу на фронте, опустившем frame -- Q[5:0],
    //                       на следующем (противоположном) фронте -- I[5:0]
    // Этот же фронт, которым мы ловим начало окна через tx_frame_p, УЖЕ
    // несёт первый отсчёт (Q) -- отдельно ждать после него ещё один
    // @(posedge fb_clk_p) нельзя: это "съест" следующий фронт и сдвинет
    // всю выборку на целый период (так и было раньше).
    // ------------------------------------------------------------------
    task automatic receive_sample(
        output logic [11:0] captured_i,
        output logic [11:0] captured_q
    );
        logic [5:0] i_msb, q_msb, i_lsb, q_lsb;

        // дождаться начала MSB-периода: обязательно свежий фронт, а не
        // просто текущий уровень -- если frame уже 1, мы не знаем, сколько
        // окна уже прошло, и можем начать выборку не с Q_msb, а с середины
        if (tx_frame_p === 1'b1) begin
            @(negedge tx_frame_p);
        end
        @(posedge tx_frame_p);

        // тот же фронт fb_clk_p, что поднял frame, уже несёт Q_msb
        #SAMPLE_DELAY;
        q_msb = tx_d_p;

        // противоположный фронт (середина MSB-окна) несёт I_msb
        @(negedge fb_clk_p);
        #SAMPLE_DELAY;
        i_msb = tx_d_p;

        // должны были попасть точно на границу -- следующий фронт fb_clk_p
        // (posedge) обязан совпасть с переходом tx_frame_p в 0 и нести Q_lsb
        @(posedge fb_clk_p);
        #SAMPLE_DELAY;
        assert (tx_frame_p == 1'b0)
        else begin
            $display("receive_sample: expected frame to drop to LSB half, but tx_frame_p=%b", tx_frame_p);
            $stop;
        end
        q_lsb = tx_d_p;

        @(negedge fb_clk_p);
        #SAMPLE_DELAY;
        i_lsb = tx_d_p;

        captured_i = {i_msb, i_lsb};
        captured_q = {q_msb, q_lsb};
    endtask

    // ------------------------------------------------------------------
    // TEST 1: базовая корректность значений.
    // Подаём известное значение на i_tx_i/i_tx_q заранее (до начала
    // приёма), принимаем один полный отсчёт, сверяем побитово.
    // ------------------------------------------------------------------
    task automatic value_test(input logic [11:0] i_val, input logic [11:0] q_val);
        logic [11:0] got_i, got_q;
        $display("[TEST] value_test i=0x%03x q=0x%03x", i_val, q_val);

        tx_i = i_val;
        tx_q = q_val;

        receive_sample(got_i, got_q);

        assert (got_i == i_val)
        else begin
            $display("value_test: I mismatch: expected 0x%03x, got 0x%03x", i_val, got_i);
            $stop;
        end

        assert (got_q == q_val)
        else begin
            $display("value_test: Q mismatch: expected 0x%03x, got 0x%03x", q_val, got_q);
            $stop;
        end
    endtask

    // ------------------------------------------------------------------
    // TEST 2: проверка стабильности данных внутри полупериода.
    // Убеждаемся, что данные, приходящие на i_tx_i/i_tx_q ПОСЛЕ того как
    // отсчёт уже начал передаваться, не портят уже выставленный на линии
    // отсчёт -- то есть DUT не глядит на i_tx_i/i_tx_q асинхронно
    // где-то в середине передачи текущего отсчёта.
    // (Меняем tx_i/tx_q сразу после старта приёма следующего отсчёта, до
    // того как приём завершится, и проверяем, что ПРИНЯТЫЙ отсчёт
    // остался тем, что было выставлено в начале, а не смесью старого с
    // новым.)
    // ------------------------------------------------------------------
    task automatic stability_test();
        logic [11:0] got_i, got_q;
        $display("[TEST] stability_test");

        tx_i = 12'hAAA;
        tx_q = 12'h555;

        if (tx_frame_p === 1'b1) @(negedge tx_frame_p);
        @(posedge tx_frame_p);

        // старт приёма вручную (повторяем начало receive_sample), меняя
        // tx_i/tx_q сразу после того, как первый кусок уже засэмплирован
        #SAMPLE_DELAY;
        begin
            logic [5:0] i_msb, q_msb, i_lsb, q_lsb;
            q_msb = tx_d_p;

            // подменяем данные в середине передачи текущего отсчёта --
            // корректная реализация не должна на это отреагировать до
            // следующего отсчёта
            tx_i = 12'h001;
            tx_q = 12'h002;

            @(negedge fb_clk_p);
            #SAMPLE_DELAY;
            i_msb = tx_d_p;

            @(posedge fb_clk_p);
            #SAMPLE_DELAY;
            q_lsb = tx_d_p;

            @(negedge fb_clk_p);
            #SAMPLE_DELAY;
            i_lsb = tx_d_p;

            got_i = {i_msb, i_lsb};
            got_q = {q_msb, q_lsb};
        end

        assert (got_i == 12'hAAA)
        else begin
            $display("stability_test: I corrupted mid-sample: got 0x%03x, expected 0xAAA", got_i);
            $stop;
        end

        assert (got_q == 12'h555)
        else begin
            $display("stability_test: Q corrupted mid-sample: got 0x%03x, expected 0x555", got_q);
            $stop;
        end
    endtask

    // ------------------------------------------------------------------
    // TEST 3: несколько последовательных отсчётов подряд, без пауз между
    // ними -- проверяет, что receive_sample() правильно синхронизируется
    // на границе двух подряд идущих кадров, не теряя и не дублируя такты.
    // ------------------------------------------------------------------
    task automatic back_to_back_test(int n_samples);
        $display("[TEST] back_to_back_test (%0d samples)", n_samples);
        for (int k = 0; k < n_samples; k++) begin
            logic [11:0] exp_i, exp_q, got_i, got_q;
            exp_i = $urandom_range(4095, 0);
            exp_q = $urandom_range(4095, 0);

            tx_i = exp_i;
            tx_q = exp_q;

            receive_sample(got_i, got_q);

            assert (got_i == exp_i)
            else begin
                $display("back_to_back_test: sample %0d I mismatch: expected 0x%03x, got 0x%03x", k, exp_i, got_i);
                $stop;
            end

            assert (got_q == exp_q)
            else begin
                $display("back_to_back_test: sample %0d Q mismatch: expected 0x%03x, got 0x%03x", k, exp_q, got_q);
                $stop;
            end
        end
    endtask

    initial begin
        $dumpfile("ad9361_tx_lvds_tb.vcd");
        $dumpvars(0, ad9361_tx_lvds_tb);

        rst_n = 0;
        tx_i  = 0;
        tx_q  = 0;
        repeat (2) @(negedge clk);
        rst_n = 1;

        wait (glbl.GSR == 1'b0);
        @(posedge clk);

        value_test(12'h000, 12'h000);
        value_test(12'hFFF, 12'hFFF);
        value_test(12'hABC, 12'h123);
        value_test(12'h800, 12'h001); // проверка знакового/граничного бита отдельно от остальных
        stability_test();
        back_to_back_test(20);

        $display("ALL TESTS PASSED");
        $finish;
    end

    ad9361_tx_lvds dut (
        .i_clk(clk),
        .i_rst_n(rst_n),
        .i_tx_i(tx_i),
        .i_tx_q(tx_q),
        .o_tx_d_p(tx_d_p),
        .o_tx_d_n(tx_d_n),
        .o_tx_frame_p(tx_frame_p),
        .o_tx_frame_n(tx_frame_n),
        .o_fb_clk_p(fb_clk_p),
        .o_fb_clk_n(fb_clk_n)
    );

endmodule
