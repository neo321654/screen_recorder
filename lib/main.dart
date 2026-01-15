import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:screen_recorder/screen_recorder.dart';

import 'sample_animation.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Screen Recorder',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Screen Recorder'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    required this.title,
  });

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // Контроллер для записи экрана
  late final ScreenRecorderController controller;
  
  bool _recording = false;
  bool _exporting = false;
  
  String? _savedFilePath;
  String? _fileSize;
  bool _showFileInfo = false;
  
  // Размеры экрана для записи
  double? _screenWidth;
  double? _screenHeight;

  @override
  void initState() {
    super.initState();
    controller = ScreenRecorderController(
      pixelRatio: 0.5, // Минимальный размер записи
    );
    // Получаем размеры экрана после первого рендера
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getScreenSize();
    });
  }
  
  void _getScreenSize() {
    try {
      // Получаем размеры через Window
      final window = ui.PlatformDispatcher.instance.views.first;
      final physicalSize = window.physicalSize;
      final devicePixelRatio = window.devicePixelRatio;
      
      // Логические размеры экрана
      final logicalSize = physicalSize / devicePixelRatio;
      
      debugPrint('=== SCREEN SIZE DEBUG ===');
      debugPrint('Physical size: ${physicalSize.width} x ${physicalSize.height}');
      debugPrint('Device pixel ratio: $devicePixelRatio');
      debugPrint('Logical size: ${logicalSize.width} x ${logicalSize.height}');
      
      setState(() {
        _screenWidth = logicalSize.width;
        _screenHeight = logicalSize.height;
      });
      
      debugPrint('ScreenRecorder will use: $_screenWidth x $_screenHeight');
      debugPrint('========================');
    } catch (e) {
      debugPrint('ERROR getting screen size: $e');
      // Используем значения по умолчанию
      setState(() {
        _screenWidth = 400;
        _screenHeight = 800;
      });
    }
  }

  Future<void> _startRecording() async {
    debugPrint('=== START RECORDING ===');
    debugPrint('Screen size: $_screenWidth x $_screenHeight');
    debugPrint('Controller has frames: ${controller.exporter.hasFrames}');
    
    // Очищаем предыдущие кадры
    controller.exporter.clear();
    debugPrint('Cleared previous frames');
    
    controller.start();
    debugPrint('Controller started');
    
    setState(() {
      _recording = true;
      _showFileInfo = false;
      _savedFilePath = null;
      _fileSize = null;
    });
    
    debugPrint('Recording state: $_recording');
    debugPrint('=======================');
  }

  Future<void> _stopRecording() async {
    debugPrint('=== STOP RECORDING ===');
    debugPrint('Frames captured: ${controller.exporter.frames.length}');
    
    controller.stop();
    debugPrint('Controller stopped');
    
    setState(() {
      _recording = false;
      _exporting = true;
    });

    // Автоматически сохраняем файл после остановки
    await _saveRecording();

    setState(() {
      _exporting = false;
    });
    
    debugPrint('=====================');
  }

  Future<void> _saveRecording() async {
    debugPrint('=== SAVE RECORDING ===');
    debugPrint('Total frames: ${controller.exporter.frames.length}');
    
    try {
      // Экспортируем GIF
      debugPrint('Exporting GIF...');
      var gif = await controller.exporter.exportGif();
      
      if (gif == null) {
        debugPrint('ERROR: GIF is null');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Нет данных для сохранения')),
          );
        }
        return;
      }
      
      if (gif.isEmpty) {
        debugPrint('ERROR: GIF is empty');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Нет данных для сохранения')),
          );
        }
        return;
      }
      
      debugPrint('GIF exported, size: ${gif.length} bytes');

      // Получаем директорию для сохранения
      Directory directory;
      if (Platform.isAndroid) {
        // Для Android пытаемся использовать Downloads
        try {
          final downloadsDir = Directory('/storage/emulated/0/Download');
          if (await downloadsDir.exists()) {
            directory = downloadsDir;
            debugPrint('Using Downloads directory: ${directory.path}');
          } else {
            // Если Downloads недоступен, используем внешнее хранилище приложения
            final externalDir = await getExternalStorageDirectory();
            directory = externalDir ?? await getApplicationDocumentsDirectory();
            debugPrint('Using external storage: ${directory.path}');
          }
        } catch (e) {
          debugPrint('ERROR accessing Downloads: $e');
          // В случае ошибки используем директорию приложения
          directory = await getApplicationDocumentsDirectory();
          debugPrint('Using app documents: ${directory.path}');
        }
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
        debugPrint('Using iOS documents: ${directory.path}');
      } else {
        directory = await getApplicationDocumentsDirectory();
        debugPrint('Using documents: ${directory.path}');
      }

      // Убеждаемся, что директория существует
      if (!await directory.exists()) {
        await directory.create(recursive: true);
        debugPrint('Created directory: ${directory.path}');
      }

      // Создаем имя файла с временной меткой
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final fileName = 'screen_recording_$timestamp.gif';
      final filePath = path.join(directory.path, fileName);
      
      debugPrint('Saving to: $filePath');

      // Сохраняем файл
      final file = File(filePath);
      await file.writeAsBytes(gif);

      // Получаем размер файла
      final fileSizeInBytes = await file.length();
      final fileSizeFormatted = _formatFileSize(fileSizeInBytes);
      
      debugPrint('File saved successfully');
      debugPrint('File size: $fileSizeFormatted ($fileSizeInBytes bytes)');
      debugPrint('File path: $filePath');

      // Обновляем состояние
      if (mounted) {
        setState(() {
          _savedFilePath = filePath;
          _fileSize = fileSizeFormatted;
          _showFileInfo = true;
        });
      }
      
      debugPrint('===================');
    } catch (e, stackTrace) {
      debugPrint('ERROR saving file: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при сохранении: $e')),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    // Получаем размеры экрана через MediaQuery
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    
    // Используем размеры экрана или зафиксированные размеры
    final recordingWidth = _screenWidth ?? screenSize.width;
    final recordingHeight = _screenHeight ?? screenSize.height;
    
    debugPrint('=== BUILD ===');
    debugPrint('MediaQuery size: ${screenSize.width} x ${screenSize.height}');
    debugPrint('Recording size: $recordingWidth x $recordingHeight');
    debugPrint('Recording: $_recording');
    debugPrint('=============');
    
    // Оборачиваем весь Scaffold в ScreenRecorder для записи всего экрана
    return ScreenRecorder(
      width: recordingWidth,
      height: recordingHeight,
      controller: controller,
      background: Colors.white,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                // Демонстрационный виджет для записи
                Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const SampleAnimation(),
                ),
                const SizedBox(height: 24),
                
                // Индикатор экспорта
                if (_exporting)
                  const Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Сохранение файла...'),
                    ],
                  ),
                
                // Кнопки управления записью
                if (!_exporting) ...[
                  if (!_recording)
                    ElevatedButton.icon(
                      onPressed: _startRecording,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Начать запись'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  if (_recording)
                    ElevatedButton.icon(
                      onPressed: _stopRecording,
                      icon: const Icon(Icons.stop),
                      label: const Text('Остановить запись'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                ],
                
                // Информация о сохраненном файле
                if (_showFileInfo && _savedFilePath != null && _fileSize != null) ...[
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green.shade700),
                            const SizedBox(width: 8),
                            Text(
                              'Файл успешно сохранен',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _InfoRow(
                          label: 'Размер файла:',
                          value: _fileSize!,
                          icon: Icons.storage,
                        ),
                        const SizedBox(height: 8),
                        _InfoRow(
                          label: 'Расположение:',
                          value: _savedFilePath!,
                          icon: Icons.folder,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade700),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
