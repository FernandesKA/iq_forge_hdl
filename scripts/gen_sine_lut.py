#!/usr/bin/env python3
"""
Генератор .hex файла для sine_lut.sv (Vivado $readmemh).

Хранит только ОДНУ ЧЕТВЕРТЬ периода синуса (0 .. pi/2, верхнюю
границу — сама верхняя граница получается зеркалированием из соседнего
квадранта), закодированную в fixed-point дополнительном коде.

Параметры ниже должны совпадать с parameter'ами модуля sine_lut.sv:
    LUT_ADDR_WIDTH -> полная ширина адреса (с учётом quadrant, 2 бита)
    DATA_WIDTH     -> разрядность одного отсчёта (signed, доп. код)
"""

from pathlib import Path

import numpy as np

LUT_ADDR_WIDTH = 10   # как в sine_lut.sv
DATA_WIDTH     = 12   # как в sine_lut.sv

QUARTER_ADDR_WIDTH = LUT_ADDR_WIDTH - 2      # ширина addr_in_quadrant
QUARTER_DEPTH      = 2 ** QUARTER_ADDR_WIDTH  # число отсчётов в ROM

# Кладём рядом с sine_lut.sv: $readmemh должен находить файл и при
# симуляции, и при синтезе, поэтому путь фиксирован относительно
# расположения скрипта, а не текущей рабочей директории вызова.
OUT_FILE = Path(__file__).resolve().parent.parent / "rtl" / "sine_lut.hex"


def to_twos_complement_hex(value_int: int, width: int) -> str:
    """Упаковать целое число (может быть отрицательным) в hex-строку
    фиксированной битовой ширины width, в дополнительном коде."""
    mask = (1 << width) - 1
    return format(value_int & mask, f"0{ (width + 3) // 4 }x")


def main():
    # Максимальная амплитуда для signed fixed-point с шириной DATA_WIDTH:
    # диапазон [-2^(DATA_WIDTH-1), +2^(DATA_WIDTH-1) - 1]
    full_scale = 2 ** (DATA_WIDTH - 1) - 1

    lines = []
    for addr in range(QUARTER_DEPTH):
        # Угол от 0 до (почти) pi/2, ровно QUARTER_DEPTH точек на четверть.
        # Используем (addr + 0.5) / QUARTER_DEPTH, чтобы избежать
        # дублирования точки 0 между соседними квадрантами при реверсе
        angle = (addr + 0.5) / QUARTER_DEPTH * (np.pi / 2)

        sample_float = np.sin(angle)
        sample_int = int(round(sample_float * full_scale))

        sample_int = max(-full_scale - 1, min(full_scale, sample_int))

        hex_str = to_twos_complement_hex(sample_int, DATA_WIDTH)
        lines.append(hex_str)

    with open(OUT_FILE, "w") as f:
        f.write("\n".join(lines) + "\n")

    print(f"Записано {QUARTER_DEPTH} отсчётов ({DATA_WIDTH} бит каждый) в {OUT_FILE}")
    print(f"addr_in_quadrant ширина: {QUARTER_ADDR_WIDTH} бит")
    print(f"Первые 5 отсчётов: {lines[:5]}")
    print(f"Последние 5 отсчётов: {lines[-5:]}")


if __name__ == "__main__":
    main()