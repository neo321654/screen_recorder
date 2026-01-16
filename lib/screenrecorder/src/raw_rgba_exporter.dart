import 'dart:ui' as ui show ImageByteFormat;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;
import 'frame.dart';

/// Структура данных для raw RGBA кадра
class RawRgbaFrame {
  RawRgbaFrame({
    required this.timeStamp,
    required this.pixels,
    required this.width,
    required this.height,
  });

  final Duration timeStamp;
  final Uint8List pixels;
  final int width;
  final int height;

  /// Размер данных в байтах
  int get sizeInBytes => pixels.length;

  /// Количество пикселей
  int get pixelCount => width * height;

  /// Проверка корректности данных
  bool get isValid => pixels.length == width * height * 4;

  @override
  String toString() {
    return 'RawRgbaFrame(timestamp: ${timeStamp.inMilliseconds}ms, '
        'size: ${width}x$height, '
        'pixels: ${pixels.length} bytes)';
  }
}

/// Экспортер для raw RGBA формата с бинарным сохранением
class RawRgbaExporter {
  RawRgbaExporter({
    this.resizeRatio = 0.3,
    this.maxWidth = 360,
    this.maxHeight = 640,
    this.grayscale = false,
    this.enableLogging = true,
  });

  final double resizeRatio;
  final int? maxWidth;
  final int? maxHeight;
  final bool grayscale;
  final bool enableLogging;

  final List<RawRgbaFrame> _frames = [];

  int _maxFrameWidth = 0;
  int _maxFrameHeight = 0;

  /// === ЗАХВАТ КАДРА ===
  Future<void> onNewFrame(Frame frame) async {
    try {
      final originalWidth = frame.image.width;
      final originalHeight = frame.image.height;

      if (enableLogging) {
        debugPrint(
          '[RawRgbaExporter] Обработка кадра: ${originalWidth}x$originalHeight',
        );
      }

      // Получаем raw RGBA байты
      final byteDataStart = DateTime.now();
      final byteData = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );

      if (byteData == null) {
        debugPrint('[RawRgbaExporter] ОШИБКА: toByteData вернул null');
        frame.image.dispose();
        return;
      }

      final byteDataTime = DateTime.now().difference(byteDataStart);
      if (enableLogging) {
        debugPrint(
          '[RawRgbaExporter] ByteData получен за ${byteDataTime.inMilliseconds}ms: '
          '${byteData.lengthInBytes} байт',
        );
      }

      // Создаем image.Image для обработки
      final srcImg = image.Image.fromBytes(
        width: originalWidth,
        height: originalHeight,
        bytes: byteData.buffer,
        numChannels: 4,
      );

      // Вычисляем целевые размеры с учетом resizeRatio
      int targetWidth = (originalWidth * resizeRatio).round();
      int targetHeight = (originalHeight * resizeRatio).round();

      if (enableLogging) {
        debugPrint(
          '[RawRgbaExporter] Целевой размер после resizeRatio: '
          '${targetWidth}x$targetHeight',
        );
      }

      // Применяем ограничения по максимальным размерам
      if (maxWidth != null && targetWidth > maxWidth!) {
        final scale = maxWidth! / targetWidth;
        targetWidth = maxWidth!;
        targetHeight = (targetHeight * scale).round();
        if (enableLogging) {
          debugPrint(
            '[RawRgbaExporter] Ограничение по ширине: '
            '${targetWidth}x$targetHeight',
          );
        }
      }

      if (maxHeight != null && targetHeight > maxHeight!) {
        final scale = maxHeight! / targetHeight;
        targetHeight = maxHeight!;
        targetWidth = (targetWidth * scale).round();
        if (enableLogging) {
          debugPrint(
            '[RawRgbaExporter] Ограничение по высоте: '
            '${targetWidth}x$targetHeight',
          );
        }
      }

      // Изменяем размер изображения
      final resizeStart = DateTime.now();
      image.Image processed = image.copyResize(
        srcImg,
        width: targetWidth,
        height: targetHeight,
        interpolation: image.Interpolation.average,
      );
      final resizeTime = DateTime.now().difference(resizeStart);

      if (enableLogging) {
        debugPrint(
          '[RawRgbaExporter] Изображение изменено за ${resizeTime.inMilliseconds}ms: '
          '${processed.width}x${processed.height}',
        );
      }

      // Применяем grayscale, если нужно
      if (grayscale) {
        final grayscaleStart = DateTime.now();
        processed = image.grayscale(processed);
        final grayscaleTime = DateTime.now().difference(grayscaleStart);
        if (enableLogging) {
          debugPrint(
            '[RawRgbaExporter] Grayscale применен за ${grayscaleTime.inMilliseconds}ms',
          );
        }
      }

      // Конвертируем обратно в raw RGBA байты
      // image.Image хранит данные в формате RGBA
      final convertStart = DateTime.now();
      // Используем getBytes() для получения всех байтов изображения
      final processedPixels = Uint8List.fromList(processed.getBytes());
      final convertTime = DateTime.now().difference(convertStart);

      if (enableLogging) {
        debugPrint(
          '[RawRgbaExporter] Конвертация в raw RGBA за ${convertTime.inMicroseconds}μs: '
          '${processedPixels.length} байт',
        );
        debugPrint(
          '[RawRgbaExporter] Ожидаемый размер: ${targetWidth * targetHeight * 4} байт',
        );
      }

      // Создаем кадр
      final rawFrame = RawRgbaFrame(
        timeStamp: frame.timeStamp,
        pixels: processedPixels,
        width: targetWidth,
        height: targetHeight,
      );

      if (!rawFrame.isValid) {
        debugPrint(
          '[RawRgbaExporter] ПРЕДУПРЕЖДЕНИЕ: Размер данных не соответствует '
          'ожидаемому (${rawFrame.sizeInBytes} != ${rawFrame.pixelCount * 4})',
        );
      }

      _frames.add(rawFrame);

      _maxFrameWidth = _maxFrameWidth < processed.width ? processed.width : _maxFrameWidth;
      _maxFrameHeight =
          _maxFrameHeight < processed.height ? processed.height : _maxFrameHeight;

      frame.image.dispose();

      if (enableLogging) {
        debugPrint(
          '[RawRgbaExporter] Кадр сохранен: ${originalWidth}x$originalHeight → '
          '${processed.width}x${processed.height}'
          '${grayscale ? ' (grayscale)' : ''}',
        );
        debugPrint(
          '[RawRgbaExporter] Всего кадров: ${_frames.length}, '
          'Макс. размер: ${_maxFrameWidth}x$_maxFrameHeight',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('[RawRgbaExporter] ОШИБКА при обработке кадра: $e');
      debugPrint('[RawRgbaExporter] Stack trace: $stackTrace');
      frame.image.dispose();
    }
  }

  void clear() {
    if (enableLogging) {
      debugPrint('[RawRgbaExporter] Очистка кадров: ${_frames.length} кадров');
    }
    _frames.clear();
    _maxFrameWidth = 0;
    _maxFrameHeight = 0;
  }

  bool get hasFrames => _frames.isNotEmpty;

  /// Количество захваченных кадров
  int get frameCount => _frames.length;

  /// Временная метка первого кадра
  Duration? get firstFrameTimeStamp =>
      _frames.isNotEmpty ? _frames.first.timeStamp : null;

  /// Временная метка последнего кадра
  Duration? get lastFrameTimeStamp =>
      _frames.isNotEmpty ? _frames.last.timeStamp : null;

  /// Максимальная ширина среди всех кадров
  int get maxFrameWidth => _maxFrameWidth;

  /// Максимальная высота среди всех кадров
  int get maxFrameHeight => _maxFrameHeight;

  /// === ЭКСПОРТ В БИНАРНЫЙ ФОРМАТ ===
  /// 
  /// Формат бинарника:
  /// [Header]
  /// - Magic number (4 bytes): "RGBA"
  /// - Version (1 byte): 1
  /// - Frame count (4 bytes, uint32)
  /// - Max width (4 bytes, uint32)
  /// - Max height (4 bytes, uint32)
  /// - Grayscale flag (1 byte): 0 или 1
  /// 
  /// [Frames]
  /// Для каждого кадра:
  /// - Timestamp milliseconds (8 bytes, int64)
  /// - Width (4 bytes, uint32)
  /// - Height (4 bytes, uint32)
  /// - Pixel data (width * height * 4 bytes, raw RGBA)
  Future<Uint8List?> exportBinary() async {
    if (_frames.isEmpty) {
      debugPrint('[RawRgbaExporter] Нет кадров для экспорта');
      return null;
    }

      if (enableLogging) {
        debugPrint('[RawRgbaExporter] Начало экспорта в бинарный формат');
        debugPrint('[RawRgbaExporter] Кадров: ${_frames.length}');
        debugPrint('[RawRgbaExporter] Макс. размер: ${_maxFrameWidth}x$_maxFrameHeight');
      }

    try {
      final exportStart = DateTime.now();

      // Вычисляем размер бинарника
      int totalSize = 4 + 1 + 4 + 4 + 4 + 1; // Header
      for (final frame in _frames) {
        totalSize += 8 + 4 + 4 + frame.pixels.length; // Frame data
      }

      if (enableLogging) {
        debugPrint(
          '[RawRgbaExporter] Размер бинарника: ${(totalSize / 1024).toStringAsFixed(2)} KB',
        );
      }

      final buffer = BytesBuilder();

      // === HEADER ===
      // Magic number: "RGBA"
      buffer.addByte(0x52); // 'R'
      buffer.addByte(0x47); // 'G'
      buffer.addByte(0x42); // 'B'
      buffer.addByte(0x41); // 'A'

      // Version: 1
      buffer.addByte(1);

      // Frame count (uint32)
      buffer.add(_uint32ToBytes(_frames.length));

      // Max width (uint32)
      buffer.add(_uint32ToBytes(_maxFrameWidth));

      // Max height (uint32)
      buffer.add(_uint32ToBytes(_maxFrameHeight));

      // Grayscale flag (1 byte)
      buffer.addByte(grayscale ? 1 : 0);

      if (enableLogging) {
        debugPrint('[RawRgbaExporter] Заголовок записан: 18 байт');
      }

      // === FRAMES ===
      int frameIndex = 0;
      for (final frame in _frames) {
        // Timestamp (int64, milliseconds)
        buffer.add(_int64ToBytes(frame.timeStamp.inMilliseconds));

        // Width (uint32)
        buffer.add(_uint32ToBytes(frame.width));

        // Height (uint32)
        buffer.add(_uint32ToBytes(frame.height));

        // Pixel data (raw RGBA)
        buffer.add(frame.pixels);

        frameIndex++;
        if (enableLogging && frameIndex % 10 == 0) {
          debugPrint(
            '[RawRgbaExporter] Обработано кадров: $frameIndex/${_frames.length}',
          );
        }
      }

      final result = buffer.takeBytes();
      final exportTime = DateTime.now().difference(exportStart);

      if (enableLogging) {
        debugPrint(
          '[RawRgbaExporter] Экспорт завершен за ${exportTime.inMilliseconds}ms',
        );
        debugPrint(
          '[RawRgbaExporter] Размер бинарника: ${result.length} байт '
          '(${(result.length / 1024).toStringAsFixed(2)} KB)',
        );
        debugPrint(
          '[RawRgbaExporter] Бинарник готов для декодирования',
        );
      }

      return result;
    } catch (e, stackTrace) {
      debugPrint('[RawRgbaExporter] ОШИБКА при экспорте: $e');
      debugPrint('[RawRgbaExporter] Stack trace: $stackTrace');
      return null;
    }
  }

  /// Конвертирует uint32 в 4 байта (little-endian)
  Uint8List _uint32ToBytes(int value) {
    final bytes = Uint8List(4);
    bytes[0] = value & 0xFF;
    bytes[1] = (value >> 8) & 0xFF;
    bytes[2] = (value >> 16) & 0xFF;
    bytes[3] = (value >> 24) & 0xFF;
    return bytes;
  }

  /// Конвертирует int64 в 8 байт (little-endian)
  Uint8List _int64ToBytes(int value) {
    final bytes = Uint8List(8);
    for (int i = 0; i < 8; i++) {
      bytes[i] = value & 0xFF;
      value = value >> 8;
    }
    return bytes;
  }
}
