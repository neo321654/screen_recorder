import 'dart:async';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
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
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    if (_isRunning) return;
    _isRunning = true;
    _startTime = DateTime.now().subtract(Duration(milliseconds: _milliseconds));
    _timer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
      setState(() {
        final now = DateTime.now();
        _milliseconds = now.difference(_startTime!).inMilliseconds;
      });
    });
  }

  void _stopTimer() {
    _isRunning = false;
    _timer?.cancel();
    _timer = null;
  }

  String _formatTime(int milliseconds) {
    final totalSeconds = milliseconds ~/ 1000;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final ms = milliseconds % 1000;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${ms.toString().padLeft(3, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
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
              child: Row(
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
            ),
          ],
        ),
      ),
    );
  }
}
