import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'screenshot_wrapper.dart';

void main() {
  debugPrint('[APP] Application starting...');
  runApp(const MyApp());
  debugPrint('[APP] MyApp widget created');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Timer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const TimerPage(),
    );
  }
}

class TimerPage extends StatefulWidget {
  const TimerPage({super.key});

  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  Timer? _timer;
  int _milliseconds = 0;
  bool _isRunning = false;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    debugPrint('[TIMER] TimerPage initialized');
  }

  @override
  void dispose() {
    debugPrint('[TIMER] TimerPage disposing, canceling timer');
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    if (_isRunning) {
      debugPrint('[TIMER] Start timer called but timer is already running');
      return;
    }
    debugPrint('[TIMER] Starting timer from ${_milliseconds}ms');
    _isRunning = true;
    _startTime = DateTime.now().subtract(Duration(milliseconds: _milliseconds));
    debugPrint('[TIMER] Start time calculated: $_startTime');
    _timer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
      setState(() {
        final now = DateTime.now();
        _milliseconds = now.difference(_startTime!).inMilliseconds;
      });
    });
    debugPrint('[TIMER] Timer started successfully');
  }

  void _stopTimer() {
    debugPrint('[TIMER] Stopping timer at ${_milliseconds}ms');
    _isRunning = false;
    _timer?.cancel();
    _timer = null;
    debugPrint('[TIMER] Timer stopped successfully');
  }

  String _formatTime(int milliseconds) {
    final totalSeconds = milliseconds ~/ 1000;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final ms = milliseconds % 1000;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${ms.toString().padLeft(3, '0')}';
  }

  Future<void> _captureScreenshot(BuildContext screenshotContext) async {
    debugPrint('[SCREENSHOT] Capture screenshot button pressed');
    debugPrint('[SCREENSHOT] Using context from Builder (inside ScreenshotWrapper)');
    try {
      debugPrint('[SCREENSHOT] Starting screenshot capture...');
      final filePath = await screenshotContext.captureScreenshot();
      debugPrint('[SCREENSHOT] Screenshot captured successfully: $filePath');
      if (mounted) {
        debugPrint('[SCREENSHOT] Showing success SnackBar');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Скриншот сохранен: $filePath'),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        debugPrint('[SCREENSHOT] Widget not mounted, cannot show SnackBar');
      }
    } catch (e, stackTrace) {
      debugPrint('[SCREENSHOT] ERROR: Failed to capture screenshot');
      debugPrint('[SCREENSHOT] Error: $e');
      debugPrint('[SCREENSHOT] Stack trace: $stackTrace');
      if (mounted) {
        debugPrint('[SCREENSHOT] Showing error SnackBar');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        debugPrint('[SCREENSHOT] Widget not mounted, cannot show error SnackBar');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[UI] Building TimerPage UI');
    return Scaffold(
      body: SafeArea(
        child: ScreenshotWrapper(
          directoryName: 'screenshots',
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Text(
                    _formatTime(_milliseconds),
                    style: const TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: _isRunning ? null : _startTimer,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 20,
                            ),
                          ),
                          child: const Text('Старт'),
                        ),
                        ElevatedButton(
                          onPressed: _isRunning ? _stopTimer : null,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 20,
                            ),
                          ),
                          child: const Text('Стоп'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Builder(
                      builder: (screenshotContext) {
                        return ElevatedButton.icon(
                          onPressed: () => _captureScreenshot(screenshotContext),
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Сделать скриншот'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 20,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
