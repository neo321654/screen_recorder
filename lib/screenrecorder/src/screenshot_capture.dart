import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Компактный класс для захвата и сохранения растрового изображения в PNG
class ScreenshotCapture {
  /// Захватывает виджет через RepaintBoundary и сохраняет в PNG
  ///
  /// [repaintBoundaryKey] - GlobalKey для RepaintBoundary виджета
  /// [filePath] - путь для сохранения PNG файла
  /// [pixelRatio] - коэффициент масштабирования (1.0 = оригинальный размер)
  ///
  /// Возвращает true при успешном сохранении, false при ошибке
  static Future<bool> captureAndSave(
    GlobalKey repaintBoundaryKey,
    String filePath, {
    double pixelRatio = 1.0,
  }) async {
    try {
      // Получаем RenderRepaintBoundary
      final renderObject = repaintBoundaryKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;

      if (renderObject == null) {
        debugPrint('[ScreenshotCapture] ОШИБКА: RepaintBoundary не найден');
        return false;
      }

      // Захватываем изображение
      final image = await renderObject.toImage(pixelRatio: pixelRatio);
      final imageWidth = image.width;
      final imageHeight = image.height;
      
      // Конвертируем в PNG байты
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();

      if (byteData == null) {
        debugPrint('[ScreenshotCapture] ОШИБКА: Не удалось получить PNG данные');
        return false;
      }

      // Сохраняем в файл
      final file = File(filePath);
      await file.writeAsBytes(byteData.buffer.asUint8List());

      final fileSize = await file.length();
      debugPrint('[ScreenshotCapture] ✓ Изображение сохранено: $filePath');
      debugPrint('[ScreenshotCapture] Размер: ${imageWidth}x${imageHeight}');
      debugPrint('[ScreenshotCapture] Размер файла: ${(fileSize / 1024).toStringAsFixed(2)} KB');

      return true;
    } catch (e, stackTrace) {
      debugPrint('[ScreenshotCapture] ОШИБКА: $e');
      debugPrint('[ScreenshotCapture] Stack trace: $stackTrace');
      return false;
    }
  }

  /// Захватывает виджет и возвращает PNG байты (без сохранения в файл)
  ///
  /// [repaintBoundaryKey] - GlobalKey для RepaintBoundary виджета
  /// [pixelRatio] - коэффициент масштабирования (1.0 = оригинальный размер)
  ///
  /// Возвращает Uint8List с PNG данными или null при ошибке
  static Future<Uint8List?> captureToBytes(
    GlobalKey repaintBoundaryKey, {
    double pixelRatio = 1.0,
  }) async {
    try {
      final renderObject = repaintBoundaryKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;

      if (renderObject == null) {
        debugPrint('[ScreenshotCapture] ОШИБКА: RepaintBoundary не найден');
        return null;
      }

      final image = await renderObject.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();

      if (byteData == null) {
        debugPrint('[ScreenshotCapture] ОШИБКА: Не удалось получить PNG данные');
        return null;
      }

      return byteData.buffer.asUint8List();
    } catch (e) {
      debugPrint('[ScreenshotCapture] ОШИБКА: $e');
      return null;
    }
  }

  /// Создает виджет с RepaintBoundary для захвата
  ///
  /// [key] - GlobalKey для RepaintBoundary (создается автоматически, если не указан)
  /// [child] - виджет для захвата
  ///
  /// Возвращает виджет и ключ для использования в captureAndSave()
  static ({Widget widget, GlobalKey key}) buildCaptureWidget(
    Widget child, {
    GlobalKey? key,
  }) {
    final repaintKey = key ?? GlobalKey();
    return (
      widget: RepaintBoundary(
        key: repaintKey,
        child: child,
      ),
      key: repaintKey,
    );
  }
}
