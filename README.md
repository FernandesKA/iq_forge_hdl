# iq_forge_hdl

DDS TX chain (`dds_tx_chain`) for AD936x, two Zynq-7020 boards.

## Platforms

| Platform    | Part              |
|-------------|-------------------|
| `rk7020f`   | xc7z020clg484-2   |
| `pluto_sky` | xc7z020clg400-2   |

Per-platform files: `platforms/<platform>/` (part, block design), `constraints/<platform>/` (XDC).

## Build

```
./create_project.sh <platform>   # -> vivado/<platform>/dds_tx_chain.xpr
./build.sh <platform> [jobs]     # synth + impl + bitstream, headless (jobs default 4)
```

Bitstream: `vivado/<platform>/dds_tx_chain.runs/impl_1/*.bit` (deploy-ready
byte-swapped `*_swapped.bin` next to it). Reports: `reports/<platform>/`.

Or open the `.xpr` from `create_project.sh` in the Vivado GUI instead of `build.sh`.

## Pull GUI changes back

RTL/XDC edits from Vivado land directly in `rtl/` / `constraints/<platform>/`.
For project or block-design state:

```
./dump_project.sh <platform>
./dump_bd.sh <platform>
```

Dumps to a script — diff and merge by hand.

## Simulate

```
make sim        # batch
make sim_gui    # waveform viewer
```

## Quick synth check (PL only, no project)

```
vivado -mode batch -source scripts/synth_check.tcl -tclargs <platform>
```
