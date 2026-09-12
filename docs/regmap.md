# Register map

PL side exposes AD9361's three hardware control pins (`pluto_sky` only) and
the DDS TX chain's enable, reset and frequency tuning word (both platforms)
via AXI GPIO. Register-level AD9361 configuration itself goes over `SPI0`
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

Enables/disables and resets the `dds_tx_chain` sine generator
(`dds_tx_chain_wrapper_0` in the block design). When disabled the phase
accumulator is held (frozen, not reset) and the I/Q output is forced to zero
-- see `rtl/dds_tx_chain.sv` and `sim/dds_tx_chain_tb.sv`'s `disable_test`
for the exact behavior.

| Offset  | Register    | Access | Reset | Description                          |
|---------|-------------|--------|-------|---------------------------------------|
| `0x00`  | `GPIO_DATA` | RW     | `0x0` | 2-bit output vector, bits below       |

`C_ALL_OUTPUTS=1` (fixed direction, no `GPIO_TRI` register).

### `GPIO_DATA` bits

| Bit | Signal    | Target                                    | Idle/reset value | Notes                                                    |
|-----|-----------|--------------------------------------------|-------------------|-----------------------------------------------------------|
| 0   | `dds_en`  | `dds_tx_chain_wrapper_0/i_en`              | `0` (disabled)    | `1` = sine generation running.                             |
| 1   | `dds_rst` | `dds_tx_chain_wrapper_0/i_rst_n` (via AND) | `0` (not reset)   | `1` = hold the DDS in reset (phase accumulator, LUT, LVDS core), independent of the PS's `FCLK_RESET0_N`. Level-sensitive, active-high; software must write it back to `0` to release. |

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
```

## `axi_gpio_dds_ftw` -- base `0x4122_0000` (identical on both platforms)

Frequency tuning word for the DDS phase accumulator
(`dds_tx_chain_wrapper_0/i_ftw`, `ACC_WIDTH=24`). Each enabled clock the
phase accumulator in `rtl/phase_acc.sv` adds this value to its 24-bit phase
register, so it sets the output sine frequency:

```
f_out = FTW * f_clk / 2^24
```

`f_clk` is `FCLK_CLK0`, which is **not** the same on both platforms:
50 MHz on `pluto_sky`, 40 MHz on `rk7020f` -- the same FTW value therefore
produces a different output frequency on each board.

| Offset  | Register    | Access | Reset       | Description                             |
|---------|-------------|--------|-------------|-------------------------------------------|
| `0x00`  | `GPIO_DATA` | RW     | `0x00051EB8`| 24-bit FTW, low bits of the register      |

`C_ALL_OUTPUTS=1` (fixed direction, no `GPIO_TRI` register). Reset value
`0x00051EB8` = `335544` decimal, the value this was previously hardwired to
(`const_ftw`) -- so a freshly loaded bitstream still produces a tone once
`dds_en` is set, without software having to program the FTW first: ~1 MHz
on `pluto_sky` (50 MHz clock), ~800 kHz on `rk7020f` (40 MHz clock).

```
devmem 0x41220000 32 0x51EB8   # reset default: ~1 MHz on pluto_sky, ~800 kHz on rk7020f
devmem 0x41220000 32 0xA3D70   # ~2 MHz on pluto_sky, ~1.6 MHz on rk7020f
```

## Platform coverage

`axi_gpio_dds_ctrl` and `axi_gpio_dds_ftw` are identical on both platforms
(same base addresses, same bit layout, same block-design wiring around
`dds_tx_chain_wrapper_0`). To get there on `rk7020f`, which previously had
no AXI-addressable PS-PL bridge at all (`M_AXI_GP0` disabled), its
`processing_system7_0` now has `PCW_USE_M_AXI_GP0=1` and its own
`ps7_0_axi_periph` / `rst_ps7_0_40M` feeding just these two GPIOs -- see
`platforms/rk7020f/bd.tcl`.

`axi_gpio_ad9361_ctrl` remains `pluto_sky`-only: `rk7020f`'s block design
doesn't even have `ad9361_enable`/`ad9361_txnrx` ports, only
`ad9361_resetb`, and that's still tied to a constant `1` (`const_reset_n`)
rather than driven from a register.
