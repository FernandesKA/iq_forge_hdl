# iq_forge_hdl

DDS TX chain (`dds_tx_chain`) for AD936x, targeting two Zynq-7020 boards.

## Platforms

| Platform    | Part              |
|-------------|-------------------|
| `rk7020f`   | xc7z020clg484-2   |
| `pluto_sky` | xc7z020clg400-2   |

Both have PS7 + `dds_tx_chain_wrapper` wired into the block design (top is
`system_wrapper`). Constraints and PS7/BD wiring for both are cross-checked
against real hardware (vendor XDC / schematic for pluto_sky).

Per-platform files live under `platforms/<platform>/` (part, block design) and
`constraints/<platform>/` (XDC).

## Build a project

```
./create_project.sh <platform>
```

Creates `vivado/<platform>/dds_tx_chain.xpr`. Open it in the Vivado GUI to
run synthesis/implementation/bitstream generation.

## Pull GUI changes back

RTL and XDC edits saved in Vivado write directly to `rtl/` and
`constraints/<platform>/` — nothing to do.

For project-level state (new IP, filesets, run strategies):

```
./dump_project.sh <platform>
```

For block design edits (new IP, DMA, wiring):

```
./dump_bd.sh <platform>
```

Both dump into a script for you to diff and merge by hand.

## Simulate

```
make sim        # batch
make sim_gui    # waveform viewer
```

## Build a bitstream (batch, headless)

```
./build.sh <platform> [jobs]
```

Requires the project to already exist (`./create_project.sh <platform>` first).
Runs synthesis then implementation through `write_bitstream`, no GUI. `jobs`
defaults to 4. Bitstream lands in
`vivado/<platform>/dds_tx_chain.runs/impl_1/*.bit`; timing/utilization
reports go to `reports/<platform>/`. Fails loudly (with a pointer to the
relevant `runme.log`) if synthesis or implementation doesn't reach 100%.

## Quick synthesis check (no project, PL only)

```
vivado -mode batch -source scripts/synth_check.tcl -tclargs <platform>
```

Runs synth/place/route on `dds_tx_chain` alone and writes timing/utilization
reports to `reports/`.
