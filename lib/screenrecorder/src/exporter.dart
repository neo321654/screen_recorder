import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'raw_rgba_exporter.dart';
import 'frame.dart';

/// Экспортер для raw RGBA формата с бинарным сохранением
/// Заменяет старый GIF экспортер на новый бинарный формат
class Exporter {
  Exporter({
    this.resizeRatio = 0.3,
    this.maxGifWidth = 360,
    this.maxGifHeight = 640,
    this.grayscale = false,
    this.targetFps = 10,
    this.enableLogging = true,
  });

  final double resizeRatio;
  final int? maxGifWidth;
  final int? maxGifHeight;
  final bool grayscale;
  final int targetFps;
  final bool enableLogging;

  // Используем RawRgbaExporter для обработки кадров
  late final RawRgbaExporter _rawRgbaExporter = RawRgbaExporter(
    resizeRatio: resizeRatio,
    maxWidth: maxGifWidth,
    maxHeight: maxGifHeight,
    grayscale: grayscale,
    enableLogging: enableLogging,
  );

  /// === ЗАХВАТ КАДРА ===
  Future<void> onNewFrame(Frame frame) async {
    await _rawRgbaExporter.onNewFrame(frame);
  }

  void clear() {
    _rawRgbaExporter.clear();
  }

  bool get hasFrames => _rawRgbaExporter.hasFrames;

  /// Количество захваченных кадров
  int get frameCount => _rawRgbaExporter.frameCount;

  /// Временная метка первого кадра
  Duration? get firstFrameTimeStamp =>
      _rawRgbaExporter.firstFrameTimeStamp;

  /// Временная метка последнего кадра
  Duration? get lastFrameTimeStamp =>
      _rawRgbaExporter.lastFrameTimeStamp;

  /// === ЭКСПОРТ В БИНАРНЫЙ ФОРМАТ ===
  /// 
  /// Возвращает бинарные данные в формате raw RGBA
  /// Формат: см. RawRgbaExporter.exportBinary()
  Future<Uint8List?> exportGif() async {
    // Для обратной совместимости метод называется exportGif,
    // но теперь возвращает бинарный формат raw RGBA
    return await _rawRgbaExporter.exportBinary();
  }
}
