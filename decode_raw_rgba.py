#!/usr/bin/env python3
"""
Скрипт для декодирования raw RGBA изображений, экспортированных из Flutter.

Использование:
    python3 decode_raw_rgba.py <input_file> <width> <height> [output_file]

Примеры:
    # Декодировать с автоматическим именем выходного файла
    python3 decode_raw_rgba.py image.raw 800 600

    # Указать выходной файл
    python3 decode_raw_rgba.py image.raw 800 600 output.png

    # Декодировать из stdin (для pipe)
    cat image.raw | python3 decode_raw_rgba.py - 800 600 output.png
"""

import sys
import argparse
from pathlib import Path
from PIL import Image
import numpy as np


def decode_raw_rgba(input_path: str, width: int, height: int, output_path: str = None):
    """
    Декодирует raw RGBA файл в PNG изображение.

    Args:
        input_path: Путь к raw RGBA файлу или '-' для stdin
        width: Ширина изображения в пикселях
        height: Высота изображения в пикселях
        output_path: Путь для сохранения PNG (если None, генерируется автоматически)

    Returns:
        Путь к сохраненному файлу
    """
    print(f"[Decoder] Начало декодирования raw RGBA")
    print(f"[Decoder] Входной файл: {input_path}")
    print(f"[Decoder] Размер: {width}x{height}")

    # Читаем данные
    if input_path == '-':
        print("[Decoder] Чтение из stdin...")
        raw_data = sys.stdin.buffer.read()
    else:
        input_file = Path(input_path)
        if not input_file.exists():
            print(f"[Decoder] ОШИБКА: Файл не найден: {input_path}")
            sys.exit(1)

        print(f"[Decoder] Чтение файла: {input_file.stat().st_size} байт")
        with open(input_file, 'rb') as f:
            raw_data = f.read()

    # Проверяем размер данных
    expected_size = width * height * 4
    actual_size = len(raw_data)

    print(f"[Decoder] Размер данных: {actual_size} байт")
    print(f"[Decoder] Ожидаемый размер: {expected_size} байт")

    if actual_size < expected_size:
        print(f"[Decoder] ПРЕДУПРЕЖДЕНИЕ: Недостаточно данных!")
        print(f"[Decoder] Не хватает {expected_size - actual_size} байт")
        sys.exit(1)
    elif actual_size > expected_size:
        print(f"[Decoder] ПРЕДУПРЕЖДЕНИЕ: Избыточные данные!")
        print(f"[Decoder] Лишних {actual_size - expected_size} байт (будут проигнорированы)")

    # Берем только нужное количество байт
    raw_data = raw_data[:expected_size]

    # Конвертируем в numpy array
    print("[Decoder] Конвертация в numpy array...")
    pixels = np.frombuffer(raw_data, dtype=np.uint8)

    # Reshape в массив пикселей (height, width, 4) - RGBA
    print("[Decoder] Формирование массива пикселей...")
    image_array = pixels.reshape((height, width, 4))

    # Создаем PIL Image
    print("[Decoder] Создание PIL Image...")
    image = Image.fromarray(image_array, 'RGBA')

    # Генерируем имя выходного файла, если не указано
    if output_path is None:
        if input_path == '-':
            output_path = 'decoded_output.png'
        else:
            input_file = Path(input_path)
            output_path = str(input_file.with_suffix('.png'))
        print(f"[Decoder] Автоматическое имя выходного файла: {output_path}")

    # Сохраняем PNG
    print(f"[Decoder] Сохранение PNG: {output_path}")
    image.save(output_path, 'PNG')

    print(f"[Decoder] ✓ Успешно декодировано!")
    print(f"[Decoder] Результат: {output_path}")
    print(f"[Decoder] Размер изображения: {width}x{height}")
    print(f"[Decoder] Формат: RGBA")

    return output_path


def main():
    parser = argparse.ArgumentParser(
        description='Декодирует raw RGBA изображение из Flutter в PNG',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )

    parser.add_argument(
        'input',
        type=str,
        help='Путь к raw RGBA файлу или "-" для чтения из stdin'
    )

    parser.add_argument(
        'width',
        type=int,
        help='Ширина изображения в пикселях'
    )

    parser.add_argument(
        'height',
        type=int,
        help='Высота изображения в пикселях'
    )

    parser.add_argument(
        'output',
        type=str,
        nargs='?',
        default=None,
        help='Путь для сохранения PNG (по умолчанию: <input>.png)'
    )

    args = parser.parse_args()

    try:
        decode_raw_rgba(
            args.input,
            args.width,
            args.height,
            args.output
        )
    except KeyboardInterrupt:
        print("\n[Decoder] Прервано пользователем")
        sys.exit(1)
    except Exception as e:
        print(f"[Decoder] ОШИБКА: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
