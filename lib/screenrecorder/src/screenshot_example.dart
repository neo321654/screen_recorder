import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'screenshot_capture.dart';

/// Пример использования ScreenshotCapture
class ScreenshotExample extends StatefulWidget {
  const ScreenshotExample({super.key});

  @override
  State<ScreenshotExample> createState() => _ScreenshotExampleState();
}

class _ScreenshotExampleState extends State<ScreenshotExample> {
  final GlobalKey _repaintKey = GlobalKey();
  String? _lastSavedPath;

  Future<void> _captureAndSave() async {
    // Получаем директорию для сохранения
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final filePath = '${directory.path}/screenshot_$timestamp.png';

    // Захватываем и сохраняем
    final success = await ScreenshotCapture.captureAndSave(
      _repaintKey,
      filePath,
      pixelRatio: 1.0, // Оригинальный размер
    );

    if (success) {
      setState(() {
        _lastSavedPath = filePath;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Скриншот сохранен: $filePath')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка при сохранении скриншота')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Создаем виджет с RepaintBoundary
    final captureWidget = ScreenshotCapture.buildCaptureWidget(
      Container(
        width: 400,
        height: 600,
        color: Colors.blue.shade100,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt, size: 64),
            const SizedBox(height: 16),
            Text(
              'Widget to Capture',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _captureAndSave,
              child: const Text('Capture & Save PNG'),
            ),
            if (_lastSavedPath != null) ...[
              const SizedBox(height: 16),
              Text(
                'Последний файл:\n$_lastSavedPath',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      key: _repaintKey,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Screenshot Capture Example')),
      body: Center(child: captureWidget.widget),
    );
  }
}
