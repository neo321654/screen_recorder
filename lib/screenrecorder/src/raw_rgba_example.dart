import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'raw_rgba_export.dart';

/// Пример использования RawRgbaExporter
class RawRgbaExample extends StatefulWidget {
  const RawRgbaExample({super.key});

  @override
  State<RawRgbaExample> createState() => _RawRgbaExampleState();
}

class _RawRgbaExampleState extends State<RawRgbaExample> {
  final RawRgbaExporter _exporter = RawRgbaExporter(
    pixelRatio: 1.0,
    enableLogging: true,
  );

  RawRgbaImage? _lastCapturedImage;
  bool _isCapturing = false;

  Future<void> _captureWidget() async {
    if (_isCapturing) return;

    setState(() {
      _isCapturing = true;
    });

    try {
      // Захватываем виджет через RepaintBoundary
      final result = await _exporter.captureFromRepaintBoundary(
        _exporter.repaintBoundaryKey,
      );

      if (result != null) {
        setState(() {
          _lastCapturedImage = result;
        });

        // Здесь можно отправить данные на backend
        // Например:
        // await _sendToBackend(result.pixels, result.width, result.height);
      } else {
        debugPrint('[Example] Ошибка при захвате');
      }
    } finally {
      setState(() {
        _isCapturing = false;
      });
    }
  }

  // Пример отправки на backend
  Future<void> _sendToBackend(
    Uint8List pixels,
    int width,
    int height,
  ) async {
    debugPrint('[Example] Отправка на backend:');
    debugPrint('[Example]   Размер: ${width}x$height');
    debugPrint('[Example]   Данные: ${pixels.length} байт');

    // Здесь можно использовать http, dio, или другой HTTP клиент
    // final response = await http.post(
    //   Uri.parse('https://your-backend.com/api/image'),
    //   headers: {'Content-Type': 'application/octet-stream'},
    //   body: pixels,
    // );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raw RGBA Export Example'),
      ),
      body: Column(
        children: [
          // Виджет для захвата (обернут в RepaintBoundary)
          Expanded(
            child: _exporter.buildCaptureWidget(
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
                      onPressed: _isCapturing ? null : _captureWidget,
                      child: _isCapturing
                          ? const CircularProgressIndicator()
                          : const Text('Capture Widget'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Информация о последнем захвате
          if (_lastCapturedImage != null)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey.shade200,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Последний захват:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text('Размер: ${_lastCapturedImage!.width}x${_lastCapturedImage!.height}'),
                  Text('Пикселей: ${_lastCapturedImage!.pixelCount}'),
                  Text('Размер данных: ${_lastCapturedImage!.sizeInBytes} байт '
                      '(${(_lastCapturedImage!.sizeInBytes / 1024).toStringAsFixed(2)} KB)'),
                  Text('Валидность: ${_lastCapturedImage!.isValid ? "✓" : "✗"}'),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
