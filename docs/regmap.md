# Register map

PL side exposes AD9361's three hardware control pins (`pluto_sky` only) and
the DDS TX chain's enable, reset, sine/LFM mode select, frequency tuning word
and LFM (chirp) sweep parameters (both platforms) via AXI GPIO. Register-level AD9361 configuration itself goes over `SPI0`
(PS7 hard SPI0, EMIO'd to `SPI0_{SCLK,SS,MOSI,MISO}_0` -- see AD9361
datasheet for that register map, it's not duplicated here).

> **Новая карта:** управление DDS переезжает в единый блок `iq_forge_regs`
> (`0x4100_0000`, раздел ниже). Разделы `axi_gpio_dds_*` / `axi_gpio_lfm_*`
> устарели и будут удалены в PL-2.7; `axi_gpio_ad9361_ctrl` не меняется.

## `iq_forge_regs` -- base `0x4100_0000`, 4 KiB (обе платформы)

Единый AXI4-Lite блок управления генератором. Заменяет пять AXI GPIO
(`axi_gpio_dds_ctrl`, `axi_gpio_dds_ftw`, `axi_gpio_lfm_{start,stop,incr}`),
а также `dds_rst_inv` / `dds_rst_n_and` в block design. `axi_gpio_ad9361_ctrl`
(`pluto_sky`) остаётся как есть.

Статус: спецификация, RTL ещё нет. Поведение ниже нормативно: RTL и тест
пишутся по этому разделу.

### Размещение

| Параметр          | Значение                                                   |
|-------------------|------------------------------------------------------------|
| Base              | `0x4100_0000`                                              |
| Размер окна       | 4 KiB (`0x4100_0000`..`0x4100_0FFF`), `-range 0x1000` в `assign_bd_address` |
| Почему не `0x43C0_0000` | занят `debug_bridge_0/S_AXI/Reg0` (`rk7020f`, окно 64 KiB `0x43C0_0000`..`0x43C0_FFFF`). На `pluto_sky` он свободен, но база одна на обе платформы, чтобы firmware не ветвилась. |
| Интерфейс         | AXI4-Lite slave, данные 32 бит, `C_S_AXI_ADDR_WIDTH = 12`  |
| Тактирование      | `s_axi_aclk` = `FCLK_CLK0` (50 MHz) -- тот же клок, что и `dds_tx_chain_wrapper_0/i_clk`, поэтому CDC внутри блока нет |
| Сброс             | `s_axi_aresetn` = `rst_ps7_0_40M/peripheral_aresetn`, активный 0 |

### Сводная таблица

Доступ: `RO` -- только чтение, запись игнорируется; `RW` -- чтение/запись;
`WO` -- запись, читается `0`; `RW1C` -- чтение, запись `1` сбрасывает бит.
Все неуказанные биты зарезервированы (см. «Решения»).

| Офсет  | Имя          | Доступ | Reset         | Кратко                                   |
|--------|--------------|--------|---------------|-------------------------------------------|
| `0x00` | `ID`         | RO     | `0x4951_4647` | ASCII `"IQFG"`                            |
| `0x04` | `VERSION`    | RO     | `0x0001_0000` | `major.minor.patch` = 1.0.0               |
| `0x08` | `SCRATCH`    | RW     | `0x0000_0000` | 32 бит, проверка шины                     |
| `0x0C` | --           | --     | `0`           | резерв                                    |
| `0x10` | `CTRL`       | RW     | `0x0000_0000` | `dds_en`, `dds_rst`, `mode`, `lfm_continious` |
| `0x14` | `CMD`        | WO     | `0`           | `lfm_restart` (самосброс)                 |
| `0x18` | `STATUS`     | RO     | `0x0000_0000` | `lfm_done`                                |
| `0x1C` | --           | --     | `0`           | резерв                                    |
| `0x20` | `FTW`        | RW     | `0x0005_1EB8` | FTW синуса, `[23:0]`                      |
| `0x24`..`0x2C` | --   | --     | `0`           | резерв                                    |
| `0x30` | `LFM_START`  | RW     | `0x0005_1EB8` | начальный FTW свипа, `[23:0]`             |
| `0x34` | `LFM_STOP`   | RW     | `0x0028_F5C0` | конечный FTW one-shot свипа, `[23:0]`     |
| `0x38` | `LFM_INCR`   | RW     | `0x0000_002F` | шаг FTW за такт, `[23:0]`                 |
| `0x3C` | --           | --     | `0`           | резерв                                    |
| `0x40` | `IRQ_STATUS` | RW1C   | `0x0000_0000` | `[0] lfm_done`, `[1] soft`                |
| `0x44` | `IRQ_ENABLE` | RW     | `0x0000_0000` | маска, те же биты                         |
| `0x48` | `IRQ_FORCE`  | WO     | `0`           | запись `1` ставит бит в `IRQ_STATUS`      |
| `0x4C` | --           | --     | `0`           | резерв                                    |
| `0x50`..`0x0FC` | --  | --     | `0`           | **зарезервировано под `RX_CTRL` / счётчики**, этим блоком не занимается |
| `0x100`..`0xFFC` | -- | --     | `0`           | задел под режимы sequencer / DMA (см. ниже), сейчас не замаплено |

Reset-значения `FTW` и `LFM_*` взяты из нынешних `C_DOUT_DEFAULT`
(`platforms/{pluto_sky,rk7020f}/bd.tcl`: `axi_gpio_dds_ftw` = `0x00051EB8`,
`axi_gpio_lfm_start` = `0x00051EB8`, `axi_gpio_lfm_stop` = `0x0028F5C0`,
`axi_gpio_lfm_incr` = `0x0000002F`, `axi_gpio_dds_ctrl` = `0x0`). После
загрузки битстрима генератор ведёт себя так же, как с AXI GPIO: молчит до
`dds_en=1`, затем даёт ~500 kHz синус, а в LFM-режиме свип ~500 kHz -> ~4 MHz
за ~1 ms.

### Регистры по битам

#### `0x00 ID` -- RO, reset `0x4951_4647`

| Биты     | Поле | Описание                                             |
|----------|------|-------------------------------------------------------|
| `[31:0]` | `id` | Константа `0x49514647` = `"IQFG"` (старший байт `'I'`). Firmware проверяет его перед любой записью, чтобы не писать в чужой блок/старый битстрим. |

#### `0x04 VERSION` -- RO, reset `0x0001_0000`

| Биты      | Поле    | Описание |
|-----------|---------|----------|
| `[31:16]` | `major` | Несовместимые изменения карты (переезд/смена смысла поля). Старт `1`. |
| `[15:8]`  | `minor` | Совместимые добавления (новый регистр/бит в резерве). Старт `0`. |
| `[7:0]`   | `patch` | Исправления RTL без изменения карты. Старт `0`. |

#### `0x08 SCRATCH` -- RW, reset `0`

| Биты     | Поле      | Описание |
|----------|-----------|----------|
| `[31:0]` | `scratch` | Ни на что не влияет. Для проверки чтения/записи и WSTRB. |

#### `0x10 CTRL` -- RW, reset `0x0000_0000`

| Бит      | Поле             | Reset | Описание |
|----------|------------------|-------|----------|
| `0`      | `dds_en`         | `0`   | `1` = генерация. `0` = аккумулятор фазы заморожен (не сброшен), I/Q = 0. Идёт на `dds_tx_chain/i_en`. |
| `1`      | `dds_rst`        | `0`   | `1` = держать тракт DDS в сбросе (`o_dds_rst_n = 0`, см. «Решения»). Уровень, программа сама снимает. Регистры блока не сбрасывает. |
| `2`      | `mode`           | `0`   | `0` = синус на `FTW`, `1` = LFM из `LFM_*`. Действует сразу, в том числе на ходу. |
| `3`      | `lfm_continious` | `0`   | Только LFM. `0` = one-shot: рампа насыщается на `LFM_STOP`. `1` = пила по модулю 2^24, `LFM_STOP` игнорируется. |
| `[31:4]` | --               | `0`   | резерв (`[5:4]` -- задел под выбор источника, см. ниже) |

Отличие от `axi_gpio_dds_ctrl`: бита `lfm_load` (бывший bit 4) больше нет,
перезапуск свипа -- через `CMD.lfm_restart`.

#### `0x14 CMD` -- WO, самосброс, читается `0`

| Бит      | Поле          | Описание |
|----------|---------------|----------|
| `0`      | `lfm_restart` | Запись `1` даёт импульс длиной ровно 1 такт `s_axi_aclk` на `o_lfm_restart`, в том же такте теневые `LFM_*` копируются в активные (см. «Атомарность LFM»). Свип начинается заново с `LFM_START`, `STATUS.lfm_done` падает. Запись `0` ничего не делает. |
| `[31:1]` | --            | резерв |

Импульс формируется в такте, когда регистр принимает запись (handshake по
AW и W завершён). Если LFM сейчас не запущен (`dds_en=0` или `mode=0`),
импульс безвреден: счётчик и так держится на `LFM_START`.

#### `0x18 STATUS` -- RO, reset `0`

| Бит      | Поле       | Описание |
|----------|------------|----------|
| `0`      | `lfm_done` | Уровень с входа `i_lfm_done`. `1` = one-shot свип дошёл до `LFM_STOP` и стоит на нём. `0` во всех остальных случаях: свип идёт, `lfm_continious=1`, `mode=0`, `dds_en=0`, сброс. |
| `[31:1]` | --         | резерв |

Источник `i_lfm_done` -- новый выход `o_lfm_done` у `lfm_ftw_generator` /
`dds_tx_chain` / `dds_tx_chain_wrapper`, регистровый, в домене `i_clk`:

- в такте с `i_load = 1` -> `0`;
- иначе, если `i_continious = 0` и `ftw_next >= {1'b0, i_ftw_stop}`
  (тот же компаратор, что выбирает насыщение) -> `1`;
- иначе держит значение; при `i_continious = 1` -> `0`.

Так как в такте загрузки флаг гарантированно `0`, каждый one-shot свип даёт
ровно один фронт `0 -> 1`, даже при `LFM_START >= LFM_STOP` (тогда флаг
встаёт через 1 такт после загрузки).

#### `0x20 FTW` -- RW, reset `0x0005_1EB8`

| Биты      | Поле  | Описание |
|-----------|-------|----------|
| `[23:0]`  | `ftw` | FTW синуса, `f_out = FTW * (f_clk / 2) / 2^24`. Действует сразу (24 бита пишутся одной транзакцией, разрыва фазы нет). Идёт на `dds_tx_chain/i_ftw`. |
| `[31:24]` | --    | резерв |

#### `0x30 LFM_START`, `0x34 LFM_STOP`, `0x38 LFM_INCR` -- RW

| Регистр     | Биты     | Reset       | Описание |
|-------------|----------|-------------|----------|
| `LFM_START` | `[23:0]` | `0x05_1EB8` | Первый FTW свипа (~500 kHz). |
| `LFM_STOP`  | `[23:0]` | `0x28_F5C0` | FTW насыщения one-shot (~4 MHz). Игнорируется при `lfm_continious=1`. |
| `LFM_INCR`  | `[23:0]` | `0x00_002F` | Прибавка к FTW **за такт** `f_clk` (47 -> ~1 ms свип для reset-значений). |

Биты `[31:24]` -- резерв. Формулы свипа (наклон, длительность, фолдинг выше
2^23) не меняются, см. раздел `axi_gpio_lfm_*` ниже. Читаются **теневые**
значения, т.е. последнее записанное, а не то, что сейчас в работе.

#### `0x40 IRQ_STATUS` -- RW1C, reset `0`

| Бит      | Поле       | Устанавливается | Сбрасывается |
|----------|------------|-----------------|--------------|
| `0`      | `lfm_done` | фронт `0 -> 1` на `i_lfm_done`; или `IRQ_FORCE[0]=1` | запись `1` в этот бит |
| `1`      | `soft`     | только `IRQ_FORCE[1]=1` | запись `1` в этот бит |
| `[31:2]` | --         | -- | резерв |

Биты статуса ставятся независимо от `IRQ_ENABLE` (как `IPISR` в PG144): маска
влияет только на `o_irq`, по статусу можно опрашивать без прерываний.

#### `0x44 IRQ_ENABLE` -- RW, reset `0`

| Бит      | Поле       | Описание |
|----------|------------|----------|
| `0`      | `lfm_done` | `1` = разрешить `o_irq` от `IRQ_STATUS[0]` |
| `1`      | `soft`     | `1` = разрешить `o_irq` от `IRQ_STATUS[1]` |
| `[31:2]` | --         | резерв |

Отдельного глобального enable (`GIER` из PG144) нет: всё запрещено, пока
`IRQ_ENABLE = 0`, второй уровень маски ничего не добавляет.

#### `0x48 IRQ_FORCE` -- WO, читается `0`

| Бит      | Поле       | Описание |
|----------|------------|----------|
| `0`      | `lfm_done` | запись `1` ставит `IRQ_STATUS[0]` |
| `1`      | `soft`     | запись `1` ставит `IRQ_STATUS[1]` |
| `[31:2]` | --         | резерв |

Запись `0` ничего не сбрасывает. Нужен для проверки цепочки
прерывание -> GIC -> драйвер без запуска свипа.

### Порты модуля

```
module iq_forge_regs #(
    parameter int C_S_AXI_ADDR_WIDTH = 12,
    parameter int ACC_WIDTH          = 24
) (
    // AXI4-Lite slave
    input  logic                            s_axi_aclk,
    input  logic                            s_axi_aresetn,
    input  logic [C_S_AXI_ADDR_WIDTH-1:0]   s_axi_awaddr,
    input  logic [2:0]                      s_axi_awprot,   // игнорируется
    input  logic                            s_axi_awvalid,
    output logic                            s_axi_awready,
    input  logic [31:0]                     s_axi_wdata,
    input  logic [3:0]                      s_axi_wstrb,
    input  logic                            s_axi_wvalid,
    output logic                            s_axi_wready,
    output logic [1:0]                      s_axi_bresp,    // всегда OKAY
    output logic                            s_axi_bvalid,
    input  logic                            s_axi_bready,
    input  logic [C_S_AXI_ADDR_WIDTH-1:0]   s_axi_araddr,
    input  logic [2:0]                      s_axi_arprot,   // игнорируется
    input  logic                            s_axi_arvalid,
    output logic                            s_axi_arready,
    output logic [31:0]                     s_axi_rdata,
    output logic [1:0]                      s_axi_rresp,    // всегда OKAY
    output logic                            s_axi_rvalid,
    input  logic                            s_axi_rready,

    // к dds_tx_chain_wrapper_0 (домен s_axi_aclk == i_clk)
    output logic                            o_dds_en,         // CTRL[0]
    output logic                            o_dds_rst_n,      // -> i_rst_n (и ad9361_rx_lvds_wrapper_0/i_rst_n на rk7020f)
    output logic                            o_mode,           // CTRL[2]
    output logic                            o_lfm_continious, // CTRL[3]
    output logic                            o_lfm_restart,    // импульс 1 такт -> i_lfm_load
    output logic [ACC_WIDTH-1:0]            o_ftw,
    output logic [ACC_WIDTH-1:0]            o_lfm_start,      // активные копии
    output logic [ACC_WIDTH-1:0]            o_lfm_stop,
    output logic [ACC_WIDTH-1:0]            o_lfm_incr,
    input  logic                            i_lfm_done,

    // к processing_system7_0/IRQ_F2P[0]
    output logic                            o_irq
);
```

Все выходы, кроме `o_lfm_restart`, -- прямые выходы триггеров. `i_lfm_done`
уже регистровый и в том же домене, синхронизатор не нужен.

### Решения

1. **Незамапленный адрес -> чтение `0` + `OKAY`, запись игнорируется + `OKAY`.**
   `SLVERR` на `M_AXI_GP0` превращается в external abort в Linux (`devmem`
   получает SIGBUS, в ядре -- oops), а пользы не даёт: опечатка в адресе ловится
   проверкой `ID`/`VERSION`, а будущие регистры в резервных диапазонах можно
   пробовать чтением без риска.
2. **Резервные биты читаются `0`, запись в них игнорируется.** Так новое поле
   в резервном бите не меняет поведение старого ПО, если оно пишет туда `0`
   (а ПО обязано писать `0` -- это контракт для `minor`-версий).
3. **`WSTRB` поддерживается побайтно для всех записываемых регистров.** Байт
   `n` регистра меняется только при `WSTRB[n] = 1`; для `CMD`, `IRQ_STATUS`
   (W1C) и `IRQ_FORCE` действие бита тоже происходит только при поднятом
   строб-бите его байта, -- это то, что ожидают `memcpy`/`writeb` и AXI spec,
   а стоит только маска на запись.
4. **`addr[1:0]` игнорируется**, декодируется `addr[11:2]`: блок 32-битный,
   невыровненный доступ AXI4-Lite не определён, а PS7 его к GP0 и так не
   выдаёт; `awprot`/`arprot` тоже игнорируются.
5. **Атомарность LFM -- теневые регистры.** `LFM_START/STOP/INCR`, видимые по
   шине, -- теневые; в `dds_tx_chain` идут активные копии
   (`o_lfm_start/stop/incr`), которые обновляются из теневых (а) каждый такт,
   пока LFM не запущен (`dds_en = 0` или `mode = 0`), и (б) в такте импульса
   `CMD.lfm_restart`. Пока свип идёт, запись `LFM_*` на него не влияет, и
   рампа никогда не видит смесь старого `START` с новым `STOP`; после
   выключения/включения поведение совпадает с нынешним (свип берёт последние
   записанные значения), а менять параметры на ходу можно без остановки --
   записать три регистра и дать `lfm_restart`. Ограничение «менять только при
   `dds_en = 0`» отвергнуто, потому что даёт разрыв сигнала при каждой
   перенастройке. `FTW` теневым не делается: это одна 24-битная запись, она
   атомарна сама по себе.
6. **`dds_rst` формируется внутри модуля как `o_dds_rst_n`.**
   `o_dds_rst_n` -- триггер с асинхронным сбросом в `0` от `s_axi_aresetn` и
   синхронной загрузкой `~CTRL.dds_rst` (асинхронное взведение, синхронное
   снятие), т.е. `o_dds_rst_n = s_axi_aresetn & ~CTRL.dds_rst`, но без
   комбинационной логики в цепи сброса. `dds_rst_inv` и `dds_rst_n_and` из BD
   удаляются, `o_dds_rst_n` подключается туда же, куда сейчас идёт
   `dds_rst_n_and/Res` (`dds_tx_chain_wrapper_0/i_rst_n`, а на `rk7020f` ещё и
   `ad9361_rx_lvds_wrapper_0/i_rst_n`). Источник сброса меняется с
   `FCLK_RESET0_N` на `peripheral_aresetn` -- он выводится из него же и
   синхронизирован к `FCLK_CLK0`, так что это только убирает асинхронное
   снятие сброса.
7. **IRQ: level-high, `o_irq = |(IRQ_STATUS & IRQ_ENABLE)`, выход
   регистровый.** `o_irq` -- триггер (задержка 1 такт от изменения
   `STATUS`/`ENABLE`), чтобы в `IRQ_F2P` не шёл комбинационный выход;
   уровень, а не импульс, потому что GIC не теряет уровень, а повторное
   событие при неочищенном статусе ничего не ломает. Событие `lfm_done`
   ловится по фронту (`i_lfm_done & ~lfm_done_q`, `lfm_done_q` сбрасывается в
   `0`): уровень `lfm_done` держится всё время после конца свипа, и без
   детектора фронта W1C тут же снова ставил бы статус.
8. **Событие и W1C в одном такте -> побеждает событие.**
   `IRQ_STATUS_next = (IRQ_STATUS & ~w1c_mask) | event_mask`: потерять
   событие хуже, чем получить лишнее прерывание, а ПО после очистки всё равно
   перечитывает статус. `IRQ_FORCE` и W1C прийти в одном такте не могут (это
   разные адреса, а блок обрабатывает одну запись за раз).
9. **AXI4-Lite: одна транзакция чтения и одна записи в работе, AW и W
   принимаются в любом порядке** (регистр пишется, когда пришли оба), ответ
   `B`/`R` держится до `BREADY`/`RREADY`. Так требует AXI spec (A3.3), и так
   ведёт себя `axi_gpio` (PG144); пропускная способность здесь не важна.
10. **Ответ всегда `OKAY`** (`BRESP = RRESP = 2'b00`), включая запись в RO и
    чтение WO регистров -- следствие решения 1, единое правило проще тестировать.

### Интеграция в block design (когда появится RTL)

- `iq_forge_regs` подключается к свободному `M0x_AXI` `ps7_0_axi_periph`
  вместо пяти AXI GPIO; `NUM_MI` уменьшается соответственно.
- `assign_bd_address -offset 0x41000000 -range 0x00001000 ... [get_bd_addr_segs iq_forge_regs_0/S_AXI/reg0]`.
- `processing_system7_0`: `PCW_USE_FABRIC_INTERRUPT = 1`, `PCW_IRQ_F2P_INTR = 1`,
  `o_irq` -> `IRQ_F2P[0]`. Это GIC ID 61, в device tree
  `interrupts = <0 29 4>` (SPI 29, `IRQ_TYPE_LEVEL_HIGH`).
- Удаляются: `axi_gpio_dds_ctrl`, `axi_gpio_dds_ftw`,
  `axi_gpio_lfm_{start,stop,incr}`, `slice_dds_en`, `slice_dds_rst`,
  `slice_dds_mode`, `slice_lfm_continious`, `slice_lfm_load`, `dds_rst_inv`,
  `dds_rst_n_and`. `axi_gpio_ad9361_ctrl` и его слайсы остаются.

### Задел под режимы sequencer и DMA

Планируются два режима, кроме прямого управления с CPU: **sequencer**
(аппаратная программа, переключающая параметры сигнала по таймеру/событиям) и
**DMA** (проигрывание произвольного I/Q из памяти). Этот блок их не реализует,
но карта под них размечена, чтобы не перекраивать её потом:

- `CTRL[5:4]` -- зарезервировано под `src_sel`: `00` = CPU (текущее
  поведение, reset), `01` = sequencer, `10` = DMA. Reset `00` сохраняет
  совместимость, появление поля -- `minor`-версия.
- В режиме sequencer он подменяет параметры (`FTW`, `mode`, `LFM_*`) на входе
  `dds_tx_chain` через мультиплексор; регистры этого блока при этом хранят
  значения CPU и не перезаписываются, чтобы возврат в `src_sel = 00` был
  предсказуемым.
- В режиме DMA источником I/Q становится поток (AXI-Stream от AXI DMA), а не
  DDS; регистры DDS на него не влияют.
- Офсеты `0x100`..`0x1FC` -- под управление sequencer (старт/стоп, указатель,
  статус, счётчик циклов), `0x200`..`0x2FC` -- под управление DMA-плеера
  (длина, повтор, underrun-счётчик), `0x300`..`0xFFC` -- свободно. Память
  программы sequencer и буферы DMA в это окно не кладутся: им нужен отдельный
  BRAM/DDR-регион, 4 KiB окна на них не хватит.
- Новые биты `IRQ_STATUS`/`IRQ_ENABLE`/`IRQ_FORCE` под эти режимы берутся из
  резерва `[31:2]` по порядку (`[2] seq_done`, `[3] dma_done`,
  `[4] dma_underrun` -- предварительно).
- Диапазон `0x50`..`0xFC` под этот задел не используется: он остаётся за
  `RX_CTRL`/счётчиками.

### Примеры `devmem`

`f_clk = 50 MHz`. Базовая проверка:

```
devmem 0x41000000            # -> 0x49514647 ("IQFG")
devmem 0x41000004            # -> 0x00010000 (v1.0.0)
devmem 0x41000008 32 0xA5A55A5A
devmem 0x41000008            # -> 0xA5A55A5A
```

Включить синус 1 MHz:

```
devmem 0x41000020 32 0x000A3D71   # FTW = 1 MHz
devmem 0x41000010 32 0x1          # dds_en=1, mode=0 (sine)
devmem 0x41000010 32 0x0          # выключить
```

LFM one-shot 1 -> 5 MHz за ~200 us, с прерыванием по окончании:

```
devmem 0x41000010 32 0x0          # DDS выключен: теневые LFM_* сразу активны
devmem 0x41000030 32 0x000A3D71   # LFM_START = 1 MHz
devmem 0x41000034 32 0x00333333   # LFM_STOP  = 5 MHz
devmem 0x41000038 32 0x0000010C   # LFM_INCR  = 268 FTW/такт
devmem 0x41000040 32 0x1          # очистить старый IRQ_STATUS.lfm_done
devmem 0x41000044 32 0x1          # IRQ_ENABLE.lfm_done
devmem 0x41000010 32 0x5          # dds_en | mode=LFM, one-shot -> свип пошёл
devmem 0x41000018                 # STATUS -> 0x1 после окончания свипа
devmem 0x41000040                 # IRQ_STATUS -> 0x1
devmem 0x41000040 32 0x1          # W1C
devmem 0x41000014 32 0x1          # CMD.lfm_restart: ещё один свип
```

Сменить параметры на ходу (без выключения): записать `0x30`/`0x34`/`0x38`, затем
`devmem 0x41000014 32 0x1` -- новые значения вступают в силу одновременно.

Тестовое прерывание без свипа:

```
devmem 0x41000044 32 0x2          # IRQ_ENABLE.soft
devmem 0x41000048 32 0x2          # IRQ_FORCE.soft -> o_irq = 1
devmem 0x41000040                 # -> 0x2
devmem 0x41000040 32 0x2          # W1C -> o_irq = 0
devmem 0x41000040                 # -> 0x0
devmem 0x41000044 32 0x0
```

Без драйвера (UIO или свой), который снимает статус в обработчике, уровень
`o_irq` после `IRQ_FORCE` держится до W1C, и ядро может отключить линию как
«nobody cared». Для голой проверки `devmem` без драйвера смотреть
`IRQ_STATUS`, а не `/proc/interrupts`.

## `axi_gpio_ad9361_ctrl` -- base `0x4120_0000` (`pluto_sky` only)

| Offset  | Register    | Access | Reset | Description                          |
|---------|-------------|--------|-------|---------------------------------------|
| `0x00`  | `GPIO_DATA` | RW     | `0x0` | 3-bit output vector, bits below       |

`C_ALL_OUTPUTS=1` (fixed direction, no `GPIO_TRI` register).

### `GPIO_DATA` bits

| Bit | Signal            | AD9361 pin | Idle/reset value | Notes                                     |
|-----|-------------------|------------|-------------------|--------------------------------------------|
| 0   | `ad9361_resetb`   | `RESETB`   | `0` (asserted)    | Active-low. Chip held in reset until set.  |
| 1   | `ad9361_enable`   | `ENABLE`   | `0`               | ENSM pin control input.                    |
| 2   | `ad9361_txnrx`    | `TXNRX`    | `0`               | ENSM pin control input.                    |

After bitstream load the register reads `0x0` -- AD9361 stays in hardware
reset until software writes it. There is no init sequence in this repo (PL
or PS) that does this automatically; whatever brings the chip up is
responsible for the write.

### Bring-up sequence used during bring-up/debugging

```
devmem 0x41200000 32 0x0   # hold reset
devmem 0x41200000 32 0x1   # release resetb, enable/txnrx still low
devmem 0x41200000 32 0x5   # resetb=1, enable=0, txnrx=1
```

`0x5` (`resetb=1, enable=0, txnrx=1`) matches the steady state a working
AD9361 init sequence leaves ENABLE/TXNRX in once ENSM is SPI-controlled
(FDD). It has not been confirmed to bring the chip to a responding state on
real hardware -- SPI reads back a constant `0xFF` regardless of this
sequence, so either the chip still isn't coming up for another reason, or
`SPI0_MISO_I_0` isn't wired to something that drives it. See git history /
project notes for the debugging trail.

## `axi_gpio_dds_ctrl` -- base `0x4121_0000` (identical on both platforms)

> **Устарело.** Заменяется `iq_forge_regs` (`0x4100_0000`, см. выше);
> раздел удаляется в PL-2.7. Оставлен как справка для миграции firmware.

Enables/disables, resets and selects the waveform of the `dds_tx_chain`
generator (`dds_tx_chain_wrapper_0` in the block design): a fixed sine tone
(`axi_gpio_dds_ftw`) or an LFM chirp (`axi_gpio_lfm_*`, below). When disabled the phase
accumulator is held (frozen, not reset) and the I/Q output is forced to zero
-- see `rtl/dds/dds_tx_chain.sv` and `sim/dds_tx_chain_tb.sv`'s `disable_test`
for the exact behavior.

| Offset  | Register    | Access | Reset | Description                          |
|---------|-------------|--------|-------|---------------------------------------|
| `0x00`  | `GPIO_DATA` | RW     | `0x0` | 5-bit output vector, bits below       |

`C_ALL_OUTPUTS=1` (fixed direction, no `GPIO_TRI` register).

### `GPIO_DATA` bits

| Bit | Signal    | Target                                    | Idle/reset value | Notes                                                    |
|-----|-----------|--------------------------------------------|-------------------|-----------------------------------------------------------|
| 0   | `dds_en`  | `dds_tx_chain_wrapper_0/i_en`              | `0` (disabled)    | `1` = sine generation running.                             |
| 1   | `dds_rst` | `dds_tx_chain_wrapper_0/i_rst_n` (via AND) | `0` (not reset)   | `1` = hold the DDS in reset (phase accumulator, LUT, LVDS core), independent of the PS's `FCLK_RESET0_N`. Level-sensitive, active-high; software must write it back to `0` to release. |
| 2   | `dds_mode` | `dds_tx_chain_wrapper_0/i_mode` | `0` (sine)        | `0` = sine at `axi_gpio_dds_ftw`'s FTW, `1` = LFM chirp from `axi_gpio_lfm_*`. Takes effect immediately, also while running. |
| 3   | `lfm_continious` | `dds_tx_chain_wrapper_0/i_lfm_continious` | `0` (one-shot) | LFM only. `0` = the ramp saturates at `lfm_stop` and stays there; `1` = free-running ramp that ignores `lfm_stop` and wraps at 2^24 (a sawtooth over the whole DDS band). |
| 4   | `lfm_load` | `dds_tx_chain_wrapper_0/i_lfm_load` | `0`               | LFM only. **Rising edge** restarts the sweep from `lfm_start` (edge-triggered inside `dds_tx_chain`, so holding it at `1` does not freeze the sweep). Software: write `1`, then `0`. |

`dds_rst` is combined with `FCLK_RESET0_N` (`dds_rst_inv` + `dds_rst_n_and`
in the block design: `i_rst_n = FCLK_RESET0_N & ~dds_rst`) so it can force a
phase-accumulator restart from software without touching the rest of the PL.

After bitstream load the register reads `0x0` -- DDS output stays silent
until software writes `dds_en=1`, and the DDS is not held in software reset.

```
devmem 0x41210000 32 0x1   # enable DDS sine output
devmem 0x41210000 32 0x3   # assert dds_rst while enabled (phase accumulator held at 0)
devmem 0x41210000 32 0x1   # release dds_rst, keep running
devmem 0x41210000 32 0x0   # disable
devmem 0x41210000 32 0x5   # enable + LFM mode (dds_en | dds_mode), one-shot
devmem 0x41210000 32 0xD   # enable + LFM mode, continious
```

## `axi_gpio_dds_ftw` -- base `0x4122_0000` (identical on both platforms)

> **Устарело.** Заменяется `iq_forge_regs` (`0x4100_0000`, см. выше);
> раздел удаляется в PL-2.7. Оставлен как справка для миграции firmware.

Frequency tuning word for the DDS phase accumulator
(`dds_tx_chain_wrapper_0/i_ftw`, `ACC_WIDTH=24`). The phase accumulator in
`rtl/dds/phase_acc.sv` only advances on `i_ce = i_en & lvds_phase_sel`
(`dds_tx_chain.sv`), and `lvds_phase_sel` toggles every `i_clk` cycle
(`ad9361_tx_lvds.sv`'s `phase_sel`) -- so it accumulates at **half** the PL
clock rate, not the full rate. Each accumulate step adds FTW to the 24-bit
phase register, so the output sine frequency is:

```
f_out = FTW * (f_clk / 2) / 2^24
```

`f_clk` is `FCLK_CLK0`: 50 MHz on both platforms (`PCW_FPGA0_PERIPHERAL_FREQMHZ`
in each `bd.tcl`; keep `DDS_CLK_HZ` in `iq_forge_fw`'s `configs/<board>/dds_clk_hz`
in sync). (`iq_forge_fw`'s
`set_dds_frequency_hz`/`get_dds_frequency_hz` do this Hz<->FTW conversion
for you, given `DDS_CLK_HZ` in `manifest.env` -- pass the raw `f_clk`
there, not the halved rate, the /2 is applied internally.)

| Offset  | Register    | Access | Reset       | Description                             |
|---------|-------------|--------|-------------|-------------------------------------------|
| `0x00`  | `GPIO_DATA` | RW     | `0x00051EB8`| 24-bit FTW, low bits of the register      |

`C_ALL_OUTPUTS=1` (fixed direction, no `GPIO_TRI` register). Reset value
`0x00051EB8` = `335544` decimal, the value this was previously hardwired to
(`const_ftw`) -- so a freshly loaded bitstream still produces a tone once
`dds_en` is set, without software having to program the FTW first: ~500 kHz
(50 MHz clock / 2 sample rate).

```
devmem 0x41220000 32 0x51EB8   # reset default: ~500 kHz
devmem 0x41220000 32 0xA3D70   # ~1 MHz
```

## `axi_gpio_lfm_start` / `_stop` / `_incr` -- bases `0x4123_0000` / `0x4124_0000` / `0x4125_0000` (identical on both platforms)

> **Устарело.** Заменяется `iq_forge_regs` (`0x4100_0000`, см. выше);
> раздел удаляется в PL-2.7. Оставлен как справка для миграции firmware.

LFM (chirp) sweep parameters for `dds_tx_chain`'s `lfm_ftw_generator`, used
while `dds_mode = 1` in `axi_gpio_dds_ctrl`. Each is a 24-bit FTW-domain
value (same units as `axi_gpio_dds_ftw`), one AXI GPIO IP apiece -- hence
three 64 KiB windows a fixed `0x10000` apart (the firmware only needs the
first base, `LFM_GPIO_BASE`).

| Base          | Register                  | Access | Reset       | Description |
|---------------|---------------------------|--------|-------------|--------------|
| `0x4123_0000` | `axi_gpio_lfm_start` `0x00` | RW   | `0x00051EB8` | First FTW of the sweep (~500 kHz at 50 MHz). |
| `0x4124_0000` | `axi_gpio_lfm_stop`  `0x00` | RW   | `0x0028F5C0` | FTW a one-shot ramp saturates at (~4 MHz). Ignored when `lfm_continious = 1`. |
| `0x4125_0000` | `axi_gpio_lfm_incr`  `0x00` | RW   | `0x0000002F` | FTW added **per PL clock cycle** to the sweep counter (47 -> ~1 ms sweep for the default start/stop). |

`C_ALL_OUTPUTS=1` on all three (no `GPIO_TRI`). Behavior:

- The sweep counter is held loaded at `lfm_start` whenever the DDS is disabled
  or in sine mode, so every enable / switch into LFM begins at `lfm_start`; a
  rising edge on `lfm_load` restarts a running sweep.
- One-shot (`lfm_continious = 0`): the counter climbs by `lfm_incr` per clock
  and saturates at `lfm_stop`, then the output is a fixed tone at `lfm_stop`
  until the next restart. Start must be below stop.
- Continious (`lfm_continious = 1`): the counter free-runs and wraps modulo 2^24,
  ignoring `lfm_stop`; period `2^24 / (lfm_incr * f_clk)` -- e.g. `lfm_incr = 1678`
  at 50 MHz sweeps the whole 25 MHz DDS band every ~200 us.
- The phase accumulator only steps every second clock, so per output sample the
  FTW moves by `2 * lfm_incr`. The output is a linear chirp:

```
f(t)  = FTW(t) * (f_clk / 2) / 2^24
slope = lfm_incr * f_clk * (f_clk / 2) / 2^24         [Hz/s]   (74.5 MHz/s per unit of lfm_incr at 50 MHz)
T_sweep (one-shot, start -> stop) = (lfm_stop - lfm_start) / (lfm_incr * f_clk)
```

- FTW values above `2^23` (Nyquist of the DDS sample rate) fold to negative
  frequencies; the firmware only accepts start/stop up to Nyquist.

```
# 1 MHz -> 5 MHz in ~200 us, one-shot, at f_clk = 50 MHz:
devmem 0x41230000 32 0xA3D71   # start  = 1 MHz
devmem 0x41240000 32 0x333333  # stop   = 5 MHz
devmem 0x41250000 32 0x10C     # incr   = 268 FTW/clk
devmem 0x41210000 32 0x5       # dds_en | dds_mode  (starts from lfm_start)
devmem 0x41210000 32 0x15      # ... pulse lfm_load (bit 4) to restart the sweep
devmem 0x41210000 32 0x5
```

## Platform coverage

> **Устарело** в части `axi_gpio_dds_*` / `axi_gpio_lfm_*` (удаляется в PL-2.7); `iq_forge_regs` одинаков на обеих платформах.

`axi_gpio_dds_ctrl`, `axi_gpio_dds_ftw` and `axi_gpio_lfm_{start,stop,incr}` are
identical on both platforms (same base addresses, same bit layout, same
block-design wiring around `dds_tx_chain_wrapper_0`). To get there on `rk7020f`, which previously had
no AXI-addressable PS-PL bridge at all (`M_AXI_GP0` disabled), its
`processing_system7_0` now has `PCW_USE_M_AXI_GP0=1` and its own
`ps7_0_axi_periph` / `rst_ps7_0_40M` feeding just these two GPIOs -- see
`platforms/rk7020f/bd.tcl`.

`axi_gpio_ad9361_ctrl` remains `pluto_sky`-only: `rk7020f`'s block design
doesn't even have `ad9361_enable`/`ad9361_txnrx` ports, only
`ad9361_resetb`, and that's still tied to a constant `1` (`const_reset_n`)
rather than driven from a register.
