import 'package:flutter/material.dart';
import 'screen_recorder_wrapper.dart';
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
      theme: ThemeData(primarySwatch: Colors.blue),
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
  String? _savedFilePath;
  String? _fileSize;
  Duration? _recordingDuration;
  String? _estimatedSizePerMinute;
  bool _showFileInfo = false;

  @override
  Widget build(BuildContext context) {
    // Оборачиваем весь экран в ScreenRecorderWrapper
    // Вся логика записи инкапсулирована внутри этого виджета
    return ScreenRecorderWrapper(
      pixelRatio: 1,
      skipFramesBetweenCaptures: 60,

      onFileSaved: (filePath, fileSize, duration, estimatedSizePerMinute) {
        setState(() {
          _savedFilePath = filePath;
          _fileSize = fileSize;
          _recordingDuration = duration;
          _estimatedSizePerMinute = estimatedSizePerMinute;
          _showFileInfo = true;
        });
      },
      onError: (error) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      },
      child: Scaffold(
        appBar: AppBar(title: Text(widget.title)),
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

                // Кнопки управления записью (используем готовый виджет)
                const ScreenRecorderControls(),

                // Информация о сохраненном файле
                if (_showFileInfo &&
                    _savedFilePath != null &&
                    _fileSize != null) ...[
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
                            Icon(
                              Icons.check_circle,
                              color: Colors.green.shade700,
                            ),
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
                        if (_recordingDuration != null) ...[
                          const SizedBox(height: 8),
                          _InfoRow(
                            label: 'Длительность записи:',
                            value: _formatDuration(_recordingDuration!),
                            icon: Icons.timer,
                          ),
                        ],
                        if (_estimatedSizePerMinute != null) ...[
                          const SizedBox(height: 8),
                          _InfoRow(
                            label: 'Приблизительный размер за 1 минуту:',
                            value: _estimatedSizePerMinute!,
                            icon: Icons.calculate,
                          ),
                        ],
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

  String _formatDuration(Duration duration) {
    final seconds = duration.inSeconds;
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    final milliseconds = duration.inMilliseconds % 1000;
    
    if (minutes > 0) {
      return '$minutesм $remainingSecondsс $millisecondsмс';
    } else if (remainingSeconds > 0) {
      return '$remainingSecondsс $millisecondsмс';
    } else {
      return '$millisecondsмс';
    }
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
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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

