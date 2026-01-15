import 'dart:io';

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
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _recording = false;
  bool _exporting = false;
  ScreenRecorderController controller = ScreenRecorderController(
    pixelRatio: 0.5, // Минимальный размер записи
  );
  
  String? _savedFilePath;
  String? _fileSize;
  bool _showFileInfo = false;

  Future<void> _startRecording() async {
    controller.start();
    setState(() {
      _recording = true;
      _showFileInfo = false;
      _savedFilePath = null;
      _fileSize = null;
    });
  }

  Future<void> _stopRecording() async {
    controller.stop();
    setState(() {
      _recording = false;
      _exporting = true;
    });

    // Автоматически сохраняем файл после остановки
    await _saveRecording();

    setState(() {
      _exporting = false;
    });
  }

  Future<void> _saveRecording() async {
    try {
      // Экспортируем GIF
      var gif = await controller.exporter.exportGif();
      if (gif == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Нет данных для сохранения')),
          );
        }
        return;
      }
      
      if (gif.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Нет данных для сохранения')),
          );
        }
        return;
      }

      // Получаем директорию для сохранения
      Directory directory;
      if (Platform.isAndroid) {
        // Для Android пытаемся использовать Downloads
        try {
          final downloadsDir = Directory('/storage/emulated/0/Download');
          if (await downloadsDir.exists()) {
            directory = downloadsDir;
          } else {
            // Если Downloads недоступен, используем внешнее хранилище приложения
            final externalDir = await getExternalStorageDirectory();
            directory = externalDir ?? await getApplicationDocumentsDirectory();
          }
        } catch (e) {
          // В случае ошибки используем директорию приложения
          directory = await getApplicationDocumentsDirectory();
        }
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      // Убеждаемся, что директория существует
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Создаем имя файла с временной меткой
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final fileName = 'screen_recording_$timestamp.gif';
      final filePath = path.join(directory.path, fileName);

      // Сохраняем файл
      final file = File(filePath);
      await file.writeAsBytes(gif);

      // Получаем размер файла
      final fileSizeInBytes = await file.length();
      final fileSizeFormatted = _formatFileSize(fileSizeInBytes);

      // Обновляем состояние
      if (mounted) {
        setState(() {
          _savedFilePath = filePath;
          _fileSize = fileSizeFormatted;
          _showFileInfo = true;
        });
      }
    } catch (e) {
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // Виджет для записи
              ScreenRecorder(
                height: 300,
                width: 300,
                controller: controller,
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
