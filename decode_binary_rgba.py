#!/usr/bin/env python3
"""
Скрипт для декодирования бинарного формата raw RGBA из Flutter.

Формат бинарника:
[Header - 19 bytes для версии 2+]
- Magic number (4 bytes): "RGBA"
- Version (1 byte): 2 (версия 2+ поддерживает сжатие)
- Compression flag (1 byte): 0 или 1 (gzip сжатие)
- Frame count (4 bytes, uint32, little-endian)
- Max width (4 bytes, uint32, little-endian)
- Max height (4 bytes, uint32, little-endian)
- Grayscale flag (1 byte): 0 или 1

[Frames] (может быть сжато gzip)
Для каждого кадра:
- Timestamp milliseconds (8 bytes, int64, little-endian)
- Width (4 bytes, uint32, little-endian)
- Height (4 bytes, uint32, little-endian)
- Pixel data (width * height * 4 bytes, raw RGBA)

Использование:
    python3 decode_binary_rgba.py <input_file> [output_directory]

Примеры:
    # Декодировать все кадры в текущую директорию
    python3 decode_binary_rgba.py recording.bin

    # Декодировать в указанную директорию
    python3 decode_binary_rgba.py recording.bin output_frames/

    # Декодировать из stdin
    cat recording.bin | python3 decode_binary_rgba.py - output_frames/
"""

import sys
import argparse
import gzip
from pathlib import Path
from PIL import Image
import numpy as np


def read_uint32(data, offset):
    """Читает uint32 (little-endian) из данных."""
    return int.from_bytes(data[offset:offset+4], byteorder='little', signed=False)


def read_int64(data, offset):
    """Читает int64 (little-endian) из данных."""
    return int.from_bytes(data[offset:offset+8], byteorder='little', signed=True)


def decode_binary_rgba(input_path: str, output_directory: str = None):
    """
    Декодирует бинарный файл raw RGBA в набор PNG изображений.

    Args:
        input_path: Путь к бинарному файлу или '-' для stdin
        output_directory: Директория для сохранения PNG файлов

    Returns:
        Список путей к сохраненным файлам
    """
    print(f"[Decoder] Начало декодирования бинарного файла")
    print(f"[Decoder] Входной файл: {input_path}")

    # Читаем данные
    if input_path == '-':
        print("[Decoder] Чтение из stdin...")
        binary_data = sys.stdin.buffer.read()
    else:
        input_file = Path(input_path)
        if not input_file.exists():
            print(f"[Decoder] ОШИБКА: Файл не найден: {input_path}")
            sys.exit(1)

        file_size = input_file.stat().st_size
        print(f"[Decoder] Чтение файла: {file_size} байт ({file_size / 1024:.2f} KB)")
        with open(input_file, 'rb') as f:
            binary_data = f.read()

    if len(binary_data) < 19:
        print(f"[Decoder] ОШИБКА: Файл слишком мал (минимум 19 байт для заголовка)")
        sys.exit(1)

    # === ПАРСИНГ ЗАГОЛОВКА ===
    print("[Decoder] Парсинг заголовка...")

    # Magic number
    magic = binary_data[0:4]
    if magic != b'RGBA':
        print(f"[Decoder] ОШИБКА: Неверный magic number: {magic}")
        print(f"[Decoder] Ожидается: b'RGBA'")
        sys.exit(1)
    print("[Decoder] ✓ Magic number: RGBA")

    # Version
    version = binary_data[4]
    print(f"[Decoder] Версия формата: {version}")

    # Compression flag (версия 2+)
    is_compressed = False
    header_offset = 5
    if version >= 2:
        is_compressed = binary_data[5] == 1
        header_offset = 6
        print(f"[Decoder] Сжатие: {'Да (gzip)' if is_compressed else 'Нет'}")
    else:
        print("[Decoder] Старая версия формата (без поддержки сжатия)")

    # Frame count
    frame_count = read_uint32(binary_data, header_offset)
    print(f"[Decoder] Количество кадров: {frame_count}")

    # Max width
    max_width = read_uint32(binary_data, header_offset + 4)
    print(f"[Decoder] Максимальная ширина: {max_width}")

    # Max height
    max_height = read_uint32(binary_data, header_offset + 8)
    print(f"[Decoder] Максимальная высота: {max_height}")

    # Grayscale flag
    grayscale_offset = header_offset + 12
    is_grayscale = binary_data[grayscale_offset] == 1
    print(f"[Decoder] Grayscale: {'Да' if is_grayscale else 'Нет'}")

    # === ДЕКОМПРЕССИЯ ===
    frames_data_start = grayscale_offset + 1
    if is_compressed:
        print("\n[Decoder] Декомпрессия данных...")
        compressed_data = binary_data[frames_data_start:]
        try:
            frames_data = gzip.decompress(compressed_data)
            print(f"[Decoder] ✓ Декомпрессия завершена")
            print(f"[Decoder] Размер сжатых данных: {len(compressed_data)} байт")
            print(f"[Decoder] Размер после декомпрессии: {len(frames_data)} байт")
            compression_ratio = (1 - len(compressed_data) / len(frames_data)) * 100
            print(f"[Decoder] Коэффициент сжатия: {compression_ratio:.1f}%")
        except Exception as e:
            print(f"[Decoder] ОШИБКА при декомпрессии: {e}")
            sys.exit(1)
    else:
        frames_data = binary_data[frames_data_start:]

    # === ПАРСИНГ КАДРОВ ===
    print(f"\n[Decoder] Начало парсинга {frame_count} кадров...")

    # Определяем директорию для сохранения
    if output_directory is None:
        if input_path == '-':
            output_directory = 'decoded_frames'
        else:
            input_file = Path(input_path)
            output_directory = str(input_file.with_suffix('')) + '_frames'
    else:
        output_directory = output_directory

    output_dir = Path(output_directory)
    output_dir.mkdir(parents=True, exist_ok=True)
    print(f"[Decoder] Директория для сохранения: {output_dir.absolute()}")

    offset = 0  # Начинаем с начала frames_data
    saved_files = []

    for frame_index in range(frame_count):
        if offset + 16 > len(frames_data):
            print(f"[Decoder] ПРЕДУПРЕЖДЕНИЕ: Недостаточно данных для кадра {frame_index + 1}")
            break

        # Читаем метаданные кадра
        timestamp_ms = read_int64(frames_data, offset)
        offset += 8

        width = read_uint32(frames_data, offset)
        offset += 4

        height = read_uint32(frames_data, offset)
        offset += 4

        # Вычисляем размер пиксельных данных
        pixel_data_size = width * height * 4

        if offset + pixel_data_size > len(frames_data):
            print(f"[Decoder] ОШИБКА: Недостаточно данных для кадра {frame_index + 1}")
            print(f"[Decoder] Нужно: {pixel_data_size} байт, доступно: {len(frames_data) - offset} байт")
            break

        # Читаем пиксельные данные
        pixel_data = frames_data[offset:offset + pixel_data_size]
        offset += pixel_data_size

        # Конвертируем в numpy array
        pixels = np.frombuffer(pixel_data, dtype=np.uint8)

        # Reshape в массив пикселей (height, width, 4) - RGBA
        image_array = pixels.reshape((height, width, 4))

        # Создаем PIL Image
        img = Image.fromarray(image_array, 'RGBA')

        # Сохраняем PNG
        frame_filename = f'frame_{frame_index + 1:05d}_t{timestamp_ms}ms.png'
        frame_path = output_dir / frame_filename
        img.save(frame_path, 'PNG')

        saved_files.append(str(frame_path))

        if (frame_index + 1) % 10 == 0 or frame_index == frame_count - 1:
            print(
                f"[Decoder] Обработано кадров: {frame_index + 1}/{frame_count} "
                f"({(frame_index + 1) / frame_count * 100:.1f}%)"
            )

    print(f"\n[Decoder] ✓ Декодирование завершено!")
    print(f"[Decoder] Сохранено кадров: {len(saved_files)}")
    print(f"[Decoder] Директория: {output_dir.absolute()}")

    # Создаем файл с информацией
    info_file = output_dir / 'info.txt'
    with open(info_file, 'w') as f:
        f.write(f"Binary RGBA Decode Info\n")
        f.write(f"{'=' * 50}\n\n")
        f.write(f"Source file: {input_path}\n")
        f.write(f"Format version: {version}\n")
        f.write(f"Total frames: {frame_count}\n")
        f.write(f"Max dimensions: {max_width}x{max_height}\n")
        f.write(f"Grayscale: {is_grayscale}\n")
        f.write(f"Decoded frames: {len(saved_files)}\n")
        f.write(f"\nFrames:\n")
        for i, file_path in enumerate(saved_files, 1):
            frame_path = Path(file_path)
            timestamp_ms = int(frame_path.stem.split('_t')[1].replace('ms', ''))
            f.write(f"  {i}. {frame_path.name} (timestamp: {timestamp_ms}ms)\n")

    print(f"[Decoder] Информация сохранена: {info_file}")

    return saved_files


def main():
    parser = argparse.ArgumentParser(
        description='Декодирует бинарный файл raw RGBA из Flutter в набор PNG изображений',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )

    parser.add_argument(
        'input',
        type=str,
        help='Путь к бинарному файлу или "-" для чтения из stdin'
    )

    parser.add_argument(
        'output',
        type=str,
        nargs='?',
        default=None,
        help='Директория для сохранения PNG файлов (по умолчанию: <input>_frames)'
    )

    args = parser.parse_args()

    try:
        decode_binary_rgba(args.input, args.output)
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
