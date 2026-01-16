import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '/screenrecorder/src/screen_recorder.dart';

/// Виджет-обертка для записи экрана
/// Оборачивает child виджет и предоставляет функционал записи всего экрана
class ScreenRecorderWrapper extends StatefulWidget {
  const ScreenRecorderWrapper({
    super.key,
    required this.child,
    this.pixelRatio = 0.5,
    this.skipFramesBetweenCaptures = 2,
    this.onRecordingStarted,
    this.onRecordingStopped,
    this.onFileSaved,
    this.onError,
  });

  /// Виджет, который будет записываться
  final Widget child;

  /// Соотношение пикселей для записи (меньше = меньше размер файла)
  final double pixelRatio;

  /// Количество кадров, которые пропускаются между захватами
  final int skipFramesBetweenCaptures;

  /// Callback при начале записи
  final VoidCallback? onRecordingStarted;

  /// Callback при остановке записи
  final VoidCallback? onRecordingStopped;

  /// Callback при успешном сохранении файла
  /// Передает путь к файлу, размер файла, длительность записи и расчет размера для одной минуты
  final void Function(String filePath, String fileSize, Duration duration, String estimatedSizePerMinute)? onFileSaved;

  /// Callback при ошибке
  final void Function(String error)? onError;

  @override
  State<ScreenRecorderWrapper> createState() => _ScreenRecorderWrapperState();
}

class _ScreenRecorderWrapperState extends State<ScreenRecorderWrapper> {
  late final ScreenRecorderController _controller;
  
  bool _recording = false;
  bool _exporting = false;
  double? _screenWidth;
  double? _screenHeight;

  @override
  void initState() {
    super.initState();
    // _controller = ScreenRecorderController(
    //
    //   pixelRatio: widget.pixelRatio,
    //   skipFramesBetweenCaptures: widget.skipFramesBetweenCaptures,
    // );

    _controller = ScreenRecorderController(
      pixelRatio: 0.6,
      resizeRatio: 1,
      maxGifWidth: 400,
      maxGifHeight: 800,
      grayscale: false,
      targetFps: 10,
      // Приблизительно получается 4 кадра в секунду.
      skipFramesBetweenCaptures: 17,
    );

    // pixelRatio: 0.6,
    // resizeRatio: 1,
    // maxGifWidth: 400,
    // maxGifHeight: 800,
    // 3.1mb 3.11mb 3.13mb

    
    // Получаем размеры экрана после первого рендера
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getScreenSize();
    });
  }

  void _getScreenSize() {
    try {
      final window = ui.PlatformDispatcher.instance.views.first;
      final physicalSize = window.physicalSize;
      final devicePixelRatio = window.devicePixelRatio;
      final logicalSize = physicalSize / devicePixelRatio;
      
      debugPrint('[ScreenRecorderWrapper] Screen size: ${logicalSize.width} x ${logicalSize.height}');
      
      setState(() {
        _screenWidth = logicalSize.width;
        _screenHeight = logicalSize.height;
      });
    } catch (e) {
      debugPrint('[ScreenRecorderWrapper] ERROR getting screen size: $e');
      setState(() {
        _screenWidth = 400;
        _screenHeight = 800;
      });
    }
  }

  /// Начать запись экрана
  Future<void> startRecording() async {
    if (_recording) {
      debugPrint('[ScreenRecorderWrapper] Already recording');
      return;
    }

    debugPrint('[ScreenRecorderWrapper] Starting recording...');
    _controller.exporter.clear();
    _controller.start();
    
    setState(() {
      _recording = true;
    });
    
    widget.onRecordingStarted?.call();
    debugPrint('[ScreenRecorderWrapper] Recording started');
  }

  /// Остановить запись и сохранить файл
  Future<void> stopRecording() async {
    if (!_recording) {
      debugPrint('[ScreenRecorderWrapper] Not recording');
      return;
    }

    debugPrint('[ScreenRecorderWrapper] ========== ОСТАНОВКА ЗАПИСИ ==========');
    debugPrint('[ScreenRecorderWrapper] Остановка записи...');
    debugPrint('[ScreenRecorderWrapper] Кадров захвачено: ${_controller.exporter.frameCount}');
    debugPrint('[ScreenRecorderWrapper] Есть кадры: ${_controller.exporter.hasFrames}');
    
    _controller.stop();
    
    debugPrint('[ScreenRecorderWrapper] Контроллер остановлен');
    debugPrint('[ScreenRecorderWrapper] Кадров после остановки: ${_controller.exporter.frameCount}');
    
    setState(() {
      _recording = false;
      _exporting = true;
    });
    
    widget.onRecordingStopped?.call();
    
    // Автоматически сохраняем файл
    await _saveRecording();
    
    setState(() {
      _exporting = false;
    });
  }

  Future<void> _saveRecording() async {
    try {
      debugPrint('[ScreenRecorderWrapper] ========== ЭКСПОРТ ==========');
      debugPrint('[ScreenRecorderWrapper] Кадров в экспортере: ${_controller.exporter.frameCount}');
      debugPrint('[ScreenRecorderWrapper] Есть кадры: ${_controller.exporter.hasFrames}');
      
      if (!_controller.exporter.hasFrames) {
        final error = 'Нет кадров для сохранения. Возможно, запись была слишком короткой или кадры не захватывались.';
        debugPrint('[ScreenRecorderWrapper] ERROR: $error');
        widget.onError?.call(error);
        return;
      }
      
      debugPrint('[ScreenRecorderWrapper] Начало экспорта бинарных данных...');
      final binaryData = await _controller.exporter.exportGif();
      
      debugPrint('[ScreenRecorderWrapper] Экспорт завершен. Размер данных: ${binaryData?.length ?? 0} байт');
      
      if (binaryData == null || binaryData.isEmpty) {
        final error = 'Экспорт вернул пустые данные';
        debugPrint('[ScreenRecorderWrapper] ERROR: $error');
        debugPrint('[ScreenRecorderWrapper] Кадров было: ${_controller.exporter.frameCount}');
        widget.onError?.call(error);
        return;
      }
      
      debugPrint('[ScreenRecorderWrapper] Binary RGBA exported, size: ${binaryData.length} bytes');

      // Получаем директорию для сохранения
      final directory = await _getSaveDirectory();
      debugPrint('[ScreenRecorderWrapper] Save directory: ${directory.path}');

      // Убеждаемся, что директория существует
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Создаем имя файла с временной меткой
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final fileName = 'screen_recording_$timestamp.bin';
      final filePath = path.join(directory.path, fileName);
      
      debugPrint('[ScreenRecorderWrapper] Saving to: $filePath');

      // Сохраняем файл
      final file = File(filePath);
      await file.writeAsBytes(binaryData);

      // Получаем размер файла
      final fileSizeInBytes = await file.length();
      final fileSizeFormatted = _formatFileSize(fileSizeInBytes);
      
      // Вычисляем длительность записи
      final exporter = _controller.exporter;
      Duration recordingDuration = Duration.zero;
      
      final firstFrameTime = exporter.firstFrameTimeStamp;
      final lastFrameTime = exporter.lastFrameTimeStamp;
      
      if (firstFrameTime != null && lastFrameTime != null) {
        recordingDuration = lastFrameTime - firstFrameTime;
        
        // Если длительность слишком мала, используем количество кадров для оценки
        if (recordingDuration.inMilliseconds < 100) {
          // Оцениваем на основе количества кадров и skipFramesBetweenCaptures
          const flutterFps = 60.0;
          final framesPerSecond = flutterFps / (widget.skipFramesBetweenCaptures + 1);
          final estimatedSeconds = exporter.frameCount / framesPerSecond;
          recordingDuration = Duration(milliseconds: (estimatedSeconds * 1000).round());
        }
      }
      
      // Рассчитываем размер для одной минуты на основе реальных данных
      final estimatedSizePerMinute = _calculateEstimatedSizePerMinuteFromActual(
        fileSizeInBytes,
        recordingDuration,
      );
      
      debugPrint('[ScreenRecorderWrapper] File saved: $fileSizeFormatted');
      debugPrint('[ScreenRecorderWrapper] Recording duration: ${recordingDuration.inMilliseconds}ms');
      debugPrint('[ScreenRecorderWrapper] Estimated size per minute: $estimatedSizePerMinute');

      // Вызываем callback
      widget.onFileSaved?.call(filePath, fileSizeFormatted, recordingDuration, estimatedSizePerMinute);
      
    } catch (e, stackTrace) {
      final error = 'Ошибка при сохранении: $e';
      debugPrint('[ScreenRecorderWrapper] ERROR: $error');
      debugPrint('[ScreenRecorderWrapper] Stack trace: $stackTrace');
      widget.onError?.call(error);
    }
  }

  Future<Directory> _getSaveDirectory() async {
    if (Platform.isAndroid) {
      try {
        final downloadsDir = Directory('/storage/emulated/0/Download');
        if (await downloadsDir.exists()) {
          return downloadsDir;
        }
        final externalDir = await getExternalStorageDirectory();
        return externalDir ?? await getApplicationDocumentsDirectory();
      } catch (e) {
        return await getApplicationDocumentsDirectory();
      }
    } else if (Platform.isIOS) {
      return await getApplicationDocumentsDirectory();
    } else {
      return await getApplicationDocumentsDirectory();
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
  }

  /// Рассчитывает размер для одной минуты на основе реальных данных записи
  String _calculateEstimatedSizePerMinuteFromActual(int actualFileSizeBytes, Duration actualDuration) {
    try {
      if (actualDuration.inMilliseconds == 0) {
        return 'Не удалось вычислить';
      }
      
      // Конвертируем длительность в секунды
      final durationInSeconds = actualDuration.inMilliseconds / 1000.0;
      
      // Рассчитываем размер в секунду
      final bytesPerSecond = actualFileSizeBytes / durationInSeconds;
      
      // Рассчитываем размер для одной минуты
      final bytesPerMinute = (bytesPerSecond * 60).round();
      
      debugPrint('[ScreenRecorderWrapper] Size calculation from actual data:');
      debugPrint('  Actual file size: ${_formatFileSize(actualFileSizeBytes)}');
      debugPrint('  Actual duration: ${durationInSeconds.toStringAsFixed(2)}s');
      debugPrint('  Bytes per second: ${bytesPerSecond.toStringAsFixed(0)}');
      debugPrint('  Estimated size per minute: ${_formatFileSize(bytesPerMinute)}');
      
      return _formatFileSize(bytesPerMinute);
    } catch (e) {
      debugPrint('[ScreenRecorderWrapper] ERROR calculating estimated size: $e');
      return 'Не удалось вычислить';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Получаем размеры экрана через MediaQuery как fallback
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    
    final recordingWidth = _screenWidth ?? screenSize.width;
    final recordingHeight = _screenHeight ?? screenSize.height;
    
    // Оборачиваем child в ScreenRecorder для записи
    return ScreenRecorderWrapperInherited(
      isRecording: _recording,
      isExporting: _exporting,
      startRecording: startRecording,
      stopRecording: stopRecording,
      child: ScreenRecorder(
        width: recordingWidth,
        height: recordingHeight,
        controller: _controller,
        background: Colors.white,
        child: widget.child,
      ),
    );
  }

  @override
  void dispose() {
    _controller.exporter.clear();
    super.dispose();
  }
}

/// InheritedWidget для доступа к функциям записи из дочерних виджетов
class ScreenRecorderWrapperInherited extends InheritedWidget {
  const ScreenRecorderWrapperInherited({
    super.key,
    required this.isRecording,
    required this.isExporting,
    required this.startRecording,
    required this.stopRecording,
    required super.child,
  });

  final bool isRecording;
  final bool isExporting;
  final Future<void> Function() startRecording;
  final Future<void> Function() stopRecording;

  static ScreenRecorderWrapperInherited? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ScreenRecorderWrapperInherited>();
  }

  @override
  bool updateShouldNotify(ScreenRecorderWrapperInherited oldWidget) {
    return isRecording != oldWidget.isRecording ||
        isExporting != oldWidget.isExporting;
  }
}

/// Вспомогательный виджет для кнопок управления записью
class ScreenRecorderControls extends StatelessWidget {
  const ScreenRecorderControls({
    super.key,
    this.startButtonStyle,
    this.stopButtonStyle,
    this.startButtonLabel,
    this.stopButtonLabel,
  });

  final ButtonStyle? startButtonStyle;
  final ButtonStyle? stopButtonStyle;
  final String? startButtonLabel;
  final String? stopButtonLabel;

  @override
  Widget build(BuildContext context) {
    final inherited = ScreenRecorderWrapperInherited.of(context);
    
    if (inherited == null) {
      debugPrint('[ScreenRecorderControls] ERROR: Not inside ScreenRecorderWrapper');
      return const SizedBox.shrink();
    }

    if (inherited.isExporting) {
      return const Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Сохранение файла...'),
        ],
      );
    }

    if (!inherited.isRecording) {
      return ElevatedButton.icon(
        onPressed: inherited.startRecording,
        icon: const Icon(Icons.play_arrow),
        label: Text(startButtonLabel ?? 'Начать запись'),
        style: startButtonStyle ??
            ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
      );
    }

    return ElevatedButton.icon(
      onPressed: inherited.stopRecording,
      icon: const Icon(Icons.stop),
      label: Text(stopButtonLabel ?? 'Остановить запись'),
      style: stopButtonStyle ??
          ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 12,
            ),
          ),
    );
  }
}
