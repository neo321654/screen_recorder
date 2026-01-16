import 'dart:ui' as ui show Image, ImageByteFormat;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Структура данных для raw RGBA изображения
class RawRgbaImage {
  RawRgbaImage({
    required this.pixels,
    required this.width,
    required this.height,
  });

  /// Сырые RGBA байты (каждый пиксель = 4 байта: R, G, B, A)
  final Uint8List pixels;

  /// Ширина изображения в пикселях
  final int width;

  /// Высота изображения в пикселях
  final int height;

  /// Размер данных в байтах
  int get sizeInBytes => pixels.length;

  /// Количество пикселей
  int get pixelCount => width * height;

  /// Проверка корректности данных
  bool get isValid => pixels.length == width * height * 4;

  @override
  String toString() {
    return 'RawRgbaImage(width: $width, height: $height, '
        'pixels: ${pixels.length} bytes, '
        'size: ${(sizeInBytes / 1024).toStringAsFixed(2)} KB)';
  }
}

/// Класс для захвата виджета и экспорта в raw RGBA формат
class RawRgbaExporter {
  RawRgbaExporter({
    this.pixelRatio = 1.0,
    this.enableLogging = true,
  });

  /// Коэффициент масштабирования (1.0 = оригинальный размер)
  final double pixelRatio;

  /// Включить логирование операций
  final bool enableLogging;

  final GlobalKey _repaintBoundaryKey = GlobalKey();

  GlobalKey get repaintBoundaryKey => _repaintBoundaryKey;

  /// Захватывает виджет через RepaintBoundary и экспортирует в raw RGBA
  ///
  /// [widget] - виджет для захвата
  /// [width] - ширина области захвата
  /// [height] - высота области захвата
  ///
  /// Возвращает [RawRgbaImage] с сырыми RGBA байтами или null в случае ошибки
  Future<RawRgbaImage?> captureWidget(
    Widget widget,
    double width,
    double height,
  ) async {
    if (enableLogging) {
      debugPrint('[RawRgbaExporter] Начало захвата виджета');
      debugPrint('[RawRgbaExporter] Размер: ${width}x$height, pixelRatio: $pixelRatio');
    }

    try {
      // Создаем RenderRepaintBoundary через виджет
      final renderObject = _repaintBoundaryKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;

      if (renderObject == null) {
        debugPrint('[RawRgbaExporter] ОШИБКА: RenderRepaintBoundary не найден');
        return null;
      }

      if (enableLogging) {
        debugPrint('[RawRgbaExporter] RenderRepaintBoundary найден');
      }

      // Захватываем ui.Image
      final captureStart = DateTime.now();
      final ui.Image image = await renderObject.toImage(pixelRatio: pixelRatio);
      final captureTime = DateTime.now().difference(captureStart);

      if (enableLogging) {
        debugPrint(
          '[RawRgbaExporter] Изображение захвачено: '
          '${image.width}x${image.height} за ${captureTime.inMilliseconds}ms',
        );
      }

      // Экспортируем в raw RGBA
      final exportStart = DateTime.now();
      final result = await _exportToRawRgba(image);
      final exportTime = DateTime.now().difference(exportStart);

      // Освобождаем память
      image.dispose();

      if (result != null && enableLogging) {
        debugPrint(
          '[RawRgbaExporter] Экспорт завершен за ${exportTime.inMilliseconds}ms',
        );
        debugPrint(
          '[RawRgbaExporter] Результат: $result',
        );
        debugPrint(
          '[RawRgbaExporter] Общее время: '
          '${(captureTime + exportTime).inMilliseconds}ms',
        );
      }

      return result;
    } catch (e, stackTrace) {
      debugPrint('[RawRgbaExporter] ОШИБКА при захвате: $e');
      debugPrint('[RawRgbaExporter] Stack trace: $stackTrace');
      return null;
    }
  }

  /// Захватывает существующий RenderRepaintBoundary и экспортирует в raw RGBA
  ///
  /// [repaintBoundaryKey] - GlobalKey для RepaintBoundary
  ///
  /// Возвращает [RawRgbaImage] с сырыми RGBA байтами или null в случае ошибки
  Future<RawRgbaImage?> captureFromRepaintBoundary(
    GlobalKey repaintBoundaryKey,
  ) async {
    if (enableLogging) {
      debugPrint('[RawRgbaExporter] Захват из существующего RepaintBoundary');
    }

    try {
      final renderObject = repaintBoundaryKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;

      if (renderObject == null) {
        debugPrint(
          '[RawRgbaExporter] ОШИБКА: RenderRepaintBoundary не найден по ключу',
        );
        return null;
      }

      if (enableLogging) {
        debugPrint('[RawRgbaExporter] RenderRepaintBoundary найден');
      }

      // Захватываем ui.Image
      final captureStart = DateTime.now();
      final ui.Image image = await renderObject.toImage(pixelRatio: pixelRatio);
      final captureTime = DateTime.now().difference(captureStart);

      if (enableLogging) {
        debugPrint(
          '[RawRgbaExporter] Изображение захвачено: '
          '${image.width}x${image.height} за ${captureTime.inMilliseconds}ms',
        );
      }

      // Экспортируем в raw RGBA
      final exportStart = DateTime.now();
      final result = await _exportToRawRgba(image);
      final exportTime = DateTime.now().difference(exportStart);

      // Освобождаем память
      image.dispose();

      if (result != null && enableLogging) {
        debugPrint(
          '[RawRgbaExporter] Экспорт завершен за ${exportTime.inMilliseconds}ms',
        );
        debugPrint('[RawRgbaExporter] Результат: $result');
        debugPrint(
          '[RawRgbaExporter] Общее время: '
          '${(captureTime + exportTime).inMilliseconds}ms',
        );
      }

      return result;
    } catch (e, stackTrace) {
      debugPrint('[RawRgbaExporter] ОШИБКА при захвате: $e');
      debugPrint('[RawRgbaExporter] Stack trace: $stackTrace');
      return null;
    }
  }

  /// Экспортирует ui.Image в raw RGBA формат
  Future<RawRgbaImage?> _exportToRawRgba(ui.Image image) async {
    if (enableLogging) {
      debugPrint(
        '[RawRgbaExporter] Начало экспорта в raw RGBA: '
        '${image.width}x${image.height}',
      );
    }

    try {
      // Получаем сырые RGBA байты
      final byteDataStart = DateTime.now();
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      final byteDataTime = DateTime.now().difference(byteDataStart);

      if (byteData == null) {
        debugPrint('[RawRgbaExporter] ОШИБКА: toByteData вернул null');
        return null;
      }

      if (enableLogging) {
        debugPrint(
          '[RawRgbaExporter] ByteData получен за ${byteDataTime.inMilliseconds}ms: '
          '${byteData.lengthInBytes} байт',
        );
      }

      // Конвертируем в Uint8List
      final conversionStart = DateTime.now();
      final Uint8List pixels = byteData.buffer.asUint8List();
      final conversionTime = DateTime.now().difference(conversionStart);

      if (enableLogging) {
        debugPrint(
          '[RawRgbaExporter] Конвертация в Uint8List за '
          '${conversionTime.inMicroseconds}μs',
        );
        debugPrint(
          '[RawRgbaExporter] Размер данных: ${pixels.length} байт '
          '(${(pixels.length / 1024).toStringAsFixed(2)} KB)',
        );
        debugPrint(
          '[RawRgbaExporter] Ожидаемый размер: ${image.width * image.height * 4} байт',
        );
      }

      // Создаем структуру данных
      final result = RawRgbaImage(
        pixels: pixels,
        width: image.width,
        height: image.height,
      );

      // Проверяем корректность
      if (!result.isValid) {
        debugPrint(
          '[RawRgbaExporter] ПРЕДУПРЕЖДЕНИЕ: Размер данных не соответствует '
          'ожидаемому (${result.sizeInBytes} != ${result.pixelCount * 4})',
        );
      }

      if (enableLogging) {
        debugPrint('[RawRgbaExporter] RawRgbaImage создан успешно');
        debugPrint(
          '[RawRgbaExporter] Данные готовы для отправки на backend: '
          '${result.pixelCount} пикселей, ${result.sizeInBytes} байт',
        );
      }

      return result;
    } catch (e, stackTrace) {
      debugPrint('[RawRgbaExporter] ОШИБКА при экспорте: $e');
      debugPrint('[RawRgbaExporter] Stack trace: $stackTrace');
      return null;
    }
  }

  /// Создает виджет с RepaintBoundary для захвата
  Widget buildCaptureWidget(Widget child) {
    return RepaintBoundary(
      key: _repaintBoundaryKey,
      child: child,
    );
  }
}
