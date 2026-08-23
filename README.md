# iq_forge_hdl

DDS TX chain (`dds_tx_chain`) for AD936x, targeting two Zynq-7020 boards.

## Platforms

| Platform    | Part              | Top              |
|-------------|-------------------|------------------|
| `rk7020f`   | xc7z020clg484-2   | `system_wrapper` (PS7 + PL block design) |
| `pluto_sky` | xc7z020clg400-2   | `dds_tx_chain` (PL only, no block design yet) |

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

## Quick synthesis check (no project, PL only)

```
vivado -mode batch -source scripts/synth_check.tcl -tclargs <platform>
```

Runs synth/place/route on `dds_tx_chain` alone and writes timing/utilization
reports to `reports/`.
