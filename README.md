# iq_forge_hdl

HDL-проект для AD936x на связке с Zynq-7020.

## Платформы

| Платформа   | Part              |
|-------------|-------------------|
| `rk7020f`   | xc7z020clg484-2   |
| `pluto_sky` | xc7z020clg400-2   |

Файлы под платформу: `platforms/<платформа>/` (part, block design),
`constraints/<платформа>.xdc`.

## Развернуть и собрать проект

```
./create_project.sh <платформа>   # -> vivado/<платформа>/iq_forge_hdl.xpr
./build.sh <платформа> [jobs]     # синтез + имплементация + битстрим, без GUI (jobs по умолчанию 4)
```

`create_project.sh` только создаёт проект — открыть `.xpr` можно и в GUI
Vivado вместо `build.sh`.

Результат `build.sh`: `vivado/<платформа>/iq_forge_hdl.runs/impl_1/*.bit`
(рядом — готовый к заливке на плату `*_swapped.bin`, байты переставлены под
Zynq fpga_manager). Отчёты — в `reports/<платформа>/`.

## Забрать правки из GUI (дамп)

RTL и XDC-правки, сохранённые в Vivado, попадают прямо в `rtl/` и
`constraints/<платформа>.xdc` — тут ничего делать не надо.

Для изменений уровня проекта (новый IP, filesets, стратегии запуска):

```
./dump_project.sh <платформа>
```

Для правок block design (новый IP, DMA, разводка):

```
./dump_bd.sh <платформа>
```

Оба дампа пишут в скрипт — дифф и мёрж руками.

## Симуляция

```
make sim        # batch
make sim_gui    # с просмотром waveform
```

## Быстрая проверка синтеза (без проекта, только PL)

```
vivado -mode batch -source scripts/synth_check.tcl -tclargs <платформа>
```
