# Register map (pluto_sky)

PL side exposes AD9361's three hardware control pins and the DDS TX chain's
enable via AXI GPIO. Register-level AD9361 configuration itself goes over
`SPI0` (PS7 hard SPI0, EMIO'd to `SPI0_{SCLK,SS,MOSI,MISO}_0` -- see AD9361
datasheet for that register map, it's not duplicated here).

## `axi_gpio_ad9361_ctrl` -- base `0x4120_0000`

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

## `axi_gpio_dds_ctrl` -- base `0x4121_0000`

Enables/disables the `dds_tx_chain` sine generator (`dds_tx_chain_wrapper_0`
in the block design). When disabled the phase accumulator is held (frozen,
not reset) and the I/Q output is forced to zero -- see
`rtl/dds_tx_chain.sv` and `sim/dds_tx_chain_tb.sv`'s `disable_test` for the
exact behavior.

| Offset  | Register    | Access | Reset | Description                          |
|---------|-------------|--------|-------|---------------------------------------|
| `0x00`  | `GPIO_DATA` | RW     | `0x0` | 1-bit output vector, bit below        |

`C_ALL_OUTPUTS=1` (fixed direction, no `GPIO_TRI` register).

### `GPIO_DATA` bits

| Bit | Signal   | Target                       | Idle/reset value | Notes                          |
|-----|----------|-------------------------------|-------------------|--------------------------------|
| 0   | `dds_en` | `dds_tx_chain_wrapper_0/i_en` | `0` (disabled)    | `1` = sine generation running. |

After bitstream load the register reads `0x0` -- DDS output stays silent
until software writes `0x1`. The frequency tuning word (`i_ftw`) is still
hardwired to a constant (`const_ftw`, `335544`) on both platforms -- no
register for frequency control yet.

```
devmem 0x41210000 32 0x1   # enable DDS sine output
devmem 0x41210000 32 0x0   # disable
```

## Platform coverage

`pluto_sky` only for both registers above. `rk7020f`'s block design still
ties the AD9361 control pins and the DDS `i_en` to fixed constants
(`platforms/rk7020f/bd.tcl`, `i_en` tied to `1` -- DDS always on) -- it has
no AXI-addressable PS-PL bridge at all yet (`M_AXI_GP0` disabled), so
wiring either register up there is a larger change than adding the GPIO
itself.
