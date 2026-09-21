# Register map

PL side exposes AD9361's three hardware control pins (`pluto_sky` only) and
the DDS TX chain's enable, reset, sine/LFM mode select, frequency tuning word
and LFM (chirp) sweep parameters (both platforms) via AXI GPIO. Register-level AD9361 configuration itself goes over `SPI0`
(PS7 hard SPI0, EMIO'd to `SPI0_{SCLK,SS,MOSI,MISO}_0` -- see AD9361
datasheet for that register map, it's not duplicated here).

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
