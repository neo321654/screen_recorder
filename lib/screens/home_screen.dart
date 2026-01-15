import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screen_recorder_wrapper.dart';
import '../sample_animation.dart';
import '../app_state.dart';
import '../widgets/screen_timer.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Главная'),
            backgroundColor: Colors.blue,
          ),
          body: Stack(
            children: [
              Center(
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

                  // Кнопки управления записью
                  const ScreenRecorderControls(),

                  // Информация о сохраненном файле
                  if (appState.showFileInfo &&
                      appState.savedFilePath != null &&
                      appState.fileSize != null) ...[
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
                            value: appState.fileSize!,
                            icon: Icons.storage,
                          ),
                          if (appState.recordingDuration != null) ...[
                            const SizedBox(height: 8),
                            _InfoRow(
                              label: 'Длительность записи:',
                              value: _formatDuration(appState.recordingDuration!),
                              icon: Icons.timer,
                            ),
                          ],
                          if (appState.estimatedSizePerMinute != null) ...[
                            const SizedBox(height: 8),
                            _InfoRow(
                              label: 'Приблизительный размер за 1 минуту:',
                              value: appState.estimatedSizePerMinute!,
                              icon: Icons.calculate,
                            ),
                          ],
                          const SizedBox(height: 8),
                          _InfoRow(
                            label: 'Расположение:',
                            value: appState.savedFilePath!,
                            icon: Icons.folder,
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Кнопка для показа SnackBar
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Это сообщение из главного экрана!'),
                          backgroundColor: Colors.blue,
                          duration: const Duration(seconds: 2),
                          action: SnackBarAction(
                            label: 'Закрыть',
                            textColor: Colors.white,
                            onPressed: () {},
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.info),
                    label: const Text('Показать SnackBar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Кнопка для показа Dialog
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Диалог'),
                          content: const Text('Это диалоговое окно из главного экрана!'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Закрыть'),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Показать Dialog'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
                ),
              ),
              const ScreenTimer(
                screenName: 'Главная',
                position: TimerPosition.topRight,
              ),
            ],
          ),
        );
      },
    );
  }

  static String _formatDuration(Duration duration) {
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
