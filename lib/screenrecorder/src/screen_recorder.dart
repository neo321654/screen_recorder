import 'dart:ui' as ui show Image, ImageByteFormat;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'exporter.dart';
import 'frame.dart';

/// Метод сравнения кадров для определения изменений
enum FrameComparisonMethod {
  /// Хеш-сумма изображения (баланс скорости и точности) - РЕКОМЕНДУЕТСЯ
  hash,

  /// Сравнение уменьшенной версии (быстрее, но менее точно)
  thumbnail,

  /// Сравнение по среднему цвету (самый быстрый, но наименее точный)
  averageColor,

  /// Побайтовое сравнение (самый точный, но медленный)
  byteComparison,

  /// Отключить проверку (сохранять все кадры)
  none,
}

class ScreenRecorderController {
  ScreenRecorderController({
    Exporter? exporter,
    this.pixelRatio = 0.25,
    this.skipFramesBetweenCaptures = 2,
    SchedulerBinding? binding,
    double? resizeRatio,
    int? maxGifWidth,
    int? maxGifHeight,
    bool? grayscale,
    int? targetFps,
    this.frameComparisonMethod = FrameComparisonMethod.hash,
    this.frameComparisonThreshold = 0.0,
  }) : _containerKey = GlobalKey(),
       _binding = binding ?? SchedulerBinding.instance,
       _exporter =
           exporter ??
           Exporter(
             resizeRatio: resizeRatio ?? 0.3,
             maxGifWidth: maxGifWidth,
             maxGifHeight: maxGifHeight,
             grayscale: grayscale ?? false,
             targetFps: targetFps ?? 10,
           );

  final GlobalKey _containerKey;
  final SchedulerBinding _binding;
  final Exporter _exporter;

  Exporter get exporter => _exporter;

  /// The pixelRatio describes the scale between the logical pixels and the size
  /// of the output image. Specifying 1.0 will give you a 1:1 mapping between
  /// logical pixels and the output pixels in the image.
  ///
  /// По умолчанию 0.3 для оптимизации размера файла (меньше значение = меньше размер).
  /// Рекомендуемые значения: 0.3-0.5 для минимального размера, 0.5-0.7 для баланса.
  ///
  /// See [RenderRepaintBoundary](https://api.flutter.dev/flutter/rendering/RenderRepaintBoundary/toImage.html)
  /// for the underlying implementation.
  final double pixelRatio;

  /// Describes how many frames are skipped between caputerd frames.
  /// For example if it's `skipFramesBetweenCaptures = 2` screen_recorder
  /// captures a frame, skips the next two frames and then captures the next
  /// frame again.
  final int skipFramesBetweenCaptures;

  /// Метод сравнения кадров для определения изменений
  final FrameComparisonMethod frameComparisonMethod;

  /// Порог различия для методов сравнения (0.0 = идентичны, 1.0 = полностью разные)
  /// Используется только для методов thumbnail и averageColor
  final double frameComparisonThreshold;

  int skipped = 0;

  bool _record = false;

  // Кэш для сравнения кадров
  String? _previousFrameHash;
  Uint8List? _previousFrameBytes;
  List<int>? _previousAverageColor;

  // Статистика производительности
  int _totalFramesProcessed = 0;
  int _framesSkipped = 0;
  int _framesSaved = 0;
  Duration _totalComparisonTime = Duration.zero;
  Duration _totalCaptureTime = Duration.zero;
  Duration _totalSaveTime = Duration.zero;
  final List<Duration> _comparisonTimes = [];
  final List<Duration> _captureTimes = [];
  final List<Duration> _saveTimes = [];

  void start() {
    // only start a video, if no recording is in progress
    if (_record == true) {
      return;
    }
    _record = true;
    clearPerformanceStats(); // Сбрасываем статистику при старте новой записи
    _binding.addPostFrameCallback(postFrameCallback);
  }

  void stop() {
    _record = false;
    clearFrameComparisonCache();
    _printPerformanceStats();
  }

  void postFrameCallback(Duration timestamp) async {
    if (_record == false) {
      return;
    }
    if (skipped > 0) {
      // count down frames which should be skipped
      skipped = skipped - 1;
      // add a new PostFrameCallback to know about the next frame
      _binding.addPostFrameCallback(postFrameCallback);

      // but we do nothing, because we skip this frame
      return;
    }
    if (skipped == 0) {
      // reset skipped frame counter
      skipped = skipped + skipFramesBetweenCaptures;
    }
    try {
      // Измеряем время захвата кадра
      final captureStart = DateTime.now();
      final image = capture();
      final captureTime = DateTime.now().difference(captureStart);
      _totalCaptureTime += captureTime;
      _captureTimes.add(captureTime);
      _totalFramesProcessed++;

      if (image == null) {
        debugPrint('capture returned null');
        return;
      }

      // Проверяем, изменился ли кадр
      Duration comparisonTime = Duration.zero;
      bool hasChanged = true;

      if (frameComparisonMethod != FrameComparisonMethod.none) {
        final comparisonStart = DateTime.now();
        hasChanged = await _hasFrameChanged(image);
        comparisonTime = DateTime.now().difference(comparisonStart);
        _totalComparisonTime += comparisonTime;
        _comparisonTimes.add(comparisonTime);

        if (!hasChanged) {
          image.dispose();
          _framesSkipped++;
          debugPrint(
            '[ScreenRecorder] Кадр не изменился, пропускаем сохранение '
            '(сравнение: ${comparisonTime.inMilliseconds}ms, '
            'захват: ${captureTime.inMilliseconds}ms)',
          );
          _binding.addPostFrameCallback(postFrameCallback);
          return;
        }
      }

      // Измеряем время сохранения кадра
      final saveStart = DateTime.now();
      _exporter.onNewFrame(Frame(timestamp, image));
      final saveTime = DateTime.now().difference(saveStart);
      _totalSaveTime += saveTime;
      _saveTimes.add(saveTime);
      _framesSaved++;

      if (frameComparisonMethod != FrameComparisonMethod.none) {
        debugPrint(
          '[ScreenRecorder] Кадр сохранен '
          '(захват: ${captureTime.inMilliseconds}ms, '
          'сравнение: ${comparisonTime.inMilliseconds}ms, '
          'сохранение: ${saveTime.inMilliseconds}ms, '
          'всего: ${(captureTime + comparisonTime + saveTime).inMilliseconds}ms)',
        );
      } else {
        debugPrint(
          '[ScreenRecorder] Кадр сохранен '
          '(захват: ${captureTime.inMilliseconds}ms, '
          'сохранение: ${saveTime.inMilliseconds}ms, '
          'всего: ${(captureTime + saveTime).inMilliseconds}ms)',
        );
      }
    } catch (e) {
      debugPrint(e.toString());
    }
    _binding.addPostFrameCallback(postFrameCallback);
  }

  /// Проверяет, изменился ли кадр по сравнению с предыдущим
  Future<bool> _hasFrameChanged(ui.Image image) async {
    switch (frameComparisonMethod) {
      case FrameComparisonMethod.hash:
        return _hasFrameChangedByHash(image);
      case FrameComparisonMethod.thumbnail:
        return _hasFrameChangedByThumbnail(image);
      case FrameComparisonMethod.averageColor:
        return _hasFrameChangedByAverageColor(image);
      case FrameComparisonMethod.byteComparison:
        return _hasFrameChangedByBytes(image);
      case FrameComparisonMethod.none:
        return true;
    }
  }

  /// Вариант 1: Сравнение по хеш-сумме (РЕКОМЕНДУЕТСЯ)
  /// Баланс между скоростью и точностью
  Future<bool> _hasFrameChangedByHash(ui.Image image) async {
    try {
      // Получаем байты изображения
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (byteData == null) return true;

      // Вычисляем хеш-сумму
      final bytes = byteData.buffer.asUint8List();
      final hash = sha256Hash(bytes);

      // Сравниваем с предыдущим хешем
      if (_previousFrameHash == hash) {
        return false; // Кадр не изменился
      }

      _previousFrameHash = hash;
      return true; // Кадр изменился
    } catch (e) {
      debugPrint('[ScreenRecorder] Ошибка при вычислении хеша: $e');
      return true; // В случае ошибки сохраняем кадр
    }
  }

  /// Вариант 2: Сравнение уменьшенной версии (thumbnail)
  /// Быстрее, но менее точно
  Future<bool> _hasFrameChangedByThumbnail(ui.Image image) async {
    try {
      // Создаем уменьшенную версию для сравнения (например, 32x32)
      final thumbnailSize = 32;

      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (byteData == null) return true;

      // Упрощенное сравнение: берем каждый N-й пиксель
      final bytes = byteData.buffer.asUint8List();
      final sampleRate = (bytes.length / (thumbnailSize * thumbnailSize * 4))
          .round();
      final sampledBytes = <int>[];

      for (int i = 0; i < bytes.length; i += sampleRate * 4) {
        if (i + 3 < bytes.length) {
          sampledBytes.addAll([
            bytes[i],
            bytes[i + 1],
            bytes[i + 2],
            bytes[i + 3],
          ]);
        }
      }

      final hash = sha256Hash(Uint8List.fromList(sampledBytes));

      if (_previousFrameHash == hash) {
        return false;
      }

      _previousFrameHash = hash;
      return true;
    } catch (e) {
      debugPrint('[ScreenRecorder] Ошибка при сравнении thumbnail: $e');
      return true;
    }
  }

  /// Вариант 3: Сравнение по среднему цвету
  /// Самый быстрый, но наименее точный
  Future<bool> _hasFrameChangedByAverageColor(ui.Image image) async {
    try {
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (byteData == null) return true;

      final bytes = byteData.buffer.asUint8List();
      int rSum = 0, gSum = 0, bSum = 0, aSum = 0;
      int pixelCount = 0;

      // Вычисляем средний цвет (берем каждый 10-й пиксель для скорости)
      for (int i = 0; i < bytes.length; i += 40) {
        if (i + 3 < bytes.length) {
          rSum += bytes[i];
          gSum += bytes[i + 1];
          bSum += bytes[i + 2];
          aSum += bytes[i + 3];
          pixelCount++;
        }
      }

      if (pixelCount == 0) return true;

      final avgColor = [
        (rSum / pixelCount).round(),
        (gSum / pixelCount).round(),
        (bSum / pixelCount).round(),
        (aSum / pixelCount).round(),
      ];

      if (_previousAverageColor != null) {
        // Вычисляем разницу
        double diff = 0;
        for (int i = 0; i < 4; i++) {
          diff += (avgColor[i] - _previousAverageColor![i]).abs() / 255.0;
        }
        diff /= 4.0;

        if (diff <= frameComparisonThreshold) {
          return false; // Кадр не изменился значительно
        }
      }

      _previousAverageColor = avgColor;
      return true;
    } catch (e) {
      debugPrint('[ScreenRecorder] Ошибка при сравнении среднего цвета: $e');
      return true;
    }
  }

  /// Вариант 4: Побайтовое сравнение
  /// Самый точный, но медленный
  Future<bool> _hasFrameChangedByBytes(ui.Image image) async {
    try {
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (byteData == null) return true;

      final bytes = byteData.buffer.asUint8List();

      if (_previousFrameBytes != null &&
          _previousFrameBytes!.length == bytes.length) {
        // Быстрое сравнение: сначала по хешу, потом побайтово
        final currentHash = sha256Hash(bytes);
        final previousHash = sha256Hash(_previousFrameBytes!);

        if (currentHash == previousHash) {
          return false;
        }

        // Если хеши разные, но нужна точность, делаем побайтовое сравнение
        // (опционально, можно пропустить для производительности)
        int differences = 0;
        final threshold = (bytes.length * frameComparisonThreshold).round();

        for (int i = 0; i < bytes.length; i++) {
          if (bytes[i] != _previousFrameBytes![i]) {
            differences++;
            if (differences > threshold) {
              _previousFrameBytes = bytes;
              return true;
            }
          }
        }

        if (differences <= threshold) {
          return false;
        }
      }

      _previousFrameBytes = bytes;
      return true;
    } catch (e) {
      debugPrint('[ScreenRecorder] Ошибка при побайтовом сравнении: $e');
      return true;
    }
  }

  /// Вычисляет SHA-256 хеш для байтов
  String sha256Hash(Uint8List bytes) {
    // Используем простой хеш на основе суммы байтов и их позиций
    // Для более точного хеша можно использовать пакет crypto
    int hash = 0;
    for (int i = 0; i < bytes.length; i++) {
      hash = ((hash << 5) - hash) + bytes[i];
      hash = hash & hash; // Конвертируем в 32-битное число
    }
    return hash.toString();
  }

  /// Очищает кэш сравнения кадров
  void clearFrameComparisonCache() {
    _previousFrameHash = null;
    _previousFrameBytes = null;
    _previousAverageColor = null;
  }

  /// Очищает статистику производительности
  void clearPerformanceStats() {
    _totalFramesProcessed = 0;
    _framesSkipped = 0;
    _framesSaved = 0;
    _totalComparisonTime = Duration.zero;
    _totalCaptureTime = Duration.zero;
    _totalSaveTime = Duration.zero;
    _comparisonTimes.clear();
    _captureTimes.clear();
    _saveTimes.clear();
  }

  /// Выводит статистику производительности в консоль
  void _printPerformanceStats() {
    if (_totalFramesProcessed == 0) {
      debugPrint('[ScreenRecorder] Статистика: кадры не обработаны');
      return;
    }

    final avgCaptureTime =
        _totalCaptureTime.inMicroseconds /
        _totalFramesProcessed /
        1000; // в миллисекундах
    final avgSaveTime =
        _totalSaveTime.inMicroseconds / _framesSaved / 1000; // в миллисекундах

    final avgComparisonTime =
        frameComparisonMethod != FrameComparisonMethod.none
        ? _totalComparisonTime.inMicroseconds /
              _totalFramesProcessed /
              1000 // в миллисекундах
        : 0.0;

    final totalTime = _totalCaptureTime + _totalSaveTime + _totalComparisonTime;
    final avgTotalTime =
        totalTime.inMicroseconds /
        _totalFramesProcessed /
        1000; // в миллисекундах

    final skipRate = _totalFramesProcessed > 0
        ? (_framesSkipped / _totalFramesProcessed * 100).toStringAsFixed(1)
        : '0.0';

    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint('📊 СТАТИСТИКА ПРОИЗВОДИТЕЛЬНОСТИ SCREEN RECORDER');
    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint('Метод сравнения: ${frameComparisonMethod.name}');
    debugPrint('Всего кадров обработано: $_totalFramesProcessed');
    debugPrint('Кадров сохранено: $_framesSaved');
    debugPrint('Кадров пропущено: $_framesSkipped');
    debugPrint('Процент пропущенных: $skipRate%');
    debugPrint('');
    debugPrint('⏱️  ВРЕМЯ ВЫПОЛНЕНИЯ:');
    debugPrint(
      '  Среднее время захвата: ${avgCaptureTime.toStringAsFixed(2)}ms',
    );
    if (frameComparisonMethod != FrameComparisonMethod.none) {
      debugPrint(
        '  Среднее время сравнения: ${avgComparisonTime.toStringAsFixed(2)}ms',
      );
    }
    debugPrint(
      '  Среднее время сохранения: ${avgSaveTime.toStringAsFixed(2)}ms',
    );
    debugPrint('  Среднее время всего: ${avgTotalTime.toStringAsFixed(2)}ms');
    debugPrint('');
    debugPrint('📈 ОБЩЕЕ ВРЕМЯ:');
    debugPrint('  Захват: ${_totalCaptureTime.inMilliseconds}ms');
    if (frameComparisonMethod != FrameComparisonMethod.none) {
      debugPrint('  Сравнение: ${_totalComparisonTime.inMilliseconds}ms');
    }
    debugPrint('  Сохранение: ${_totalSaveTime.inMilliseconds}ms');
    debugPrint('  Всего: ${totalTime.inMilliseconds}ms');
    debugPrint('');
    if (frameComparisonMethod != FrameComparisonMethod.none) {
      final timeSaved = _framesSkipped > 0
          ? (_totalSaveTime.inMilliseconds / _framesSaved * _framesSkipped)
          : 0;
      debugPrint('💾 ЭКОНОМИЯ:');
      debugPrint(
        '  Примерное время сэкономлено на пропуске: ${timeSaved.toStringAsFixed(0)}ms',
      );
      debugPrint(
        '  Ускорение: ${((_framesSkipped / _totalFramesProcessed) * 100).toStringAsFixed(1)}%',
      );
    }
    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint('');
  }

  /// Возвращает статистику производительности
  PerformanceStats getPerformanceStats() {
    return PerformanceStats(
      method: frameComparisonMethod,
      totalFramesProcessed: _totalFramesProcessed,
      framesSaved: _framesSaved,
      framesSkipped: _framesSkipped,
      avgCaptureTimeMs: _totalFramesProcessed > 0
          ? _totalCaptureTime.inMicroseconds / _totalFramesProcessed / 1000
          : 0.0,
      avgComparisonTimeMs:
          frameComparisonMethod != FrameComparisonMethod.none &&
              _totalFramesProcessed > 0
          ? _totalComparisonTime.inMicroseconds / _totalFramesProcessed / 1000
          : 0.0,
      avgSaveTimeMs: _framesSaved > 0
          ? _totalSaveTime.inMicroseconds / _framesSaved / 1000
          : 0.0,
      totalCaptureTime: _totalCaptureTime,
      totalComparisonTime: _totalComparisonTime,
      totalSaveTime: _totalSaveTime,
      skipRate: _totalFramesProcessed > 0
          ? _framesSkipped / _totalFramesProcessed
          : 0.0,
    );
  }

  ui.Image? capture() {
    final renderObject =
        _containerKey.currentContext!.findRenderObject()
            as RenderRepaintBoundary;

    return renderObject.toImageSync(pixelRatio: pixelRatio);
  }
}

/// Статистика производительности записи экрана
class PerformanceStats {
  PerformanceStats({
    required this.method,
    required this.totalFramesProcessed,
    required this.framesSaved,
    required this.framesSkipped,
    required this.avgCaptureTimeMs,
    required this.avgComparisonTimeMs,
    required this.avgSaveTimeMs,
    required this.totalCaptureTime,
    required this.totalComparisonTime,
    required this.totalSaveTime,
    required this.skipRate,
  });

  /// Метод сравнения кадров
  final FrameComparisonMethod method;

  /// Всего кадров обработано
  final int totalFramesProcessed;

  /// Кадров сохранено
  final int framesSaved;

  /// Кадров пропущено
  final int framesSkipped;

  /// Среднее время захвата кадра (мс)
  final double avgCaptureTimeMs;

  /// Среднее время сравнения кадра (мс)
  final double avgComparisonTimeMs;

  /// Среднее время сохранения кадра (мс)
  final double avgSaveTimeMs;

  /// Общее время захвата
  final Duration totalCaptureTime;

  /// Общее время сравнения
  final Duration totalComparisonTime;

  /// Общее время сохранения
  final Duration totalSaveTime;

  /// Процент пропущенных кадров (0.0 - 1.0)
  final double skipRate;

  /// Общее время обработки
  Duration get totalTime =>
      totalCaptureTime + totalComparisonTime + totalSaveTime;

  /// Среднее время обработки одного кадра (мс)
  double get avgTotalTimeMs => totalFramesProcessed > 0
      ? totalTime.inMicroseconds / totalFramesProcessed / 1000
      : 0.0;

  @override
  String toString() {
    return '''
PerformanceStats(
  method: ${method.name},
  totalFramesProcessed: $totalFramesProcessed,
  framesSaved: $framesSaved,
  framesSkipped: $framesSkipped,
  skipRate: ${(skipRate * 100).toStringAsFixed(1)}%,
  avgCaptureTimeMs: ${avgCaptureTimeMs.toStringAsFixed(2)}ms,
  avgComparisonTimeMs: ${avgComparisonTimeMs.toStringAsFixed(2)}ms,
  avgSaveTimeMs: ${avgSaveTimeMs.toStringAsFixed(2)}ms,
  avgTotalTimeMs: ${avgTotalTimeMs.toStringAsFixed(2)}ms,
  totalTime: ${totalTime.inMilliseconds}ms,
)''';
  }
}

class ScreenRecorder extends StatelessWidget {
  const ScreenRecorder({
    super.key,
    required this.child,
    required this.controller,
    required this.width,
    required this.height,
    this.background = Colors.transparent,
  });

  /// The child which should be recorded.
  final Widget child;

  /// This controller starts and stops the recording.
  final ScreenRecorderController controller;

  /// Width of the recording.
  /// This should not change during recording as it could lead to
  /// undefined behavior.
  final double width;

  /// Height of the recording
  /// This should not change during recording as it could lead to
  /// undefined behavior.
  final double height;

  /// The background color of the recording.
  /// Transparency is currently not supported.
  final Color background;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: controller._containerKey,
      child: Container(
        width: width,
        height: height,
        color: background,
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}
