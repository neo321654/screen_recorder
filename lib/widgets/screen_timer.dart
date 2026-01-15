import 'package:flutter/material.dart';

/// Виджет таймера для отслеживания времени на экране
/// Автоматически запускается при создании и показывает время в формате MM:SS.mmm
/// Таймер сбрасывается при каждом показе экрана (если используется с ключом)
class ScreenTimer extends StatefulWidget {
  const ScreenTimer({
    super.key,
    this.screenName,
    this.position = TimerPosition.topRight,
  });

  /// Имя экрана для отображения (опционально)
  final String? screenName;

  /// Позиция таймера на экране
  final TimerPosition position;

  @override
  State<ScreenTimer> createState() => _ScreenTimerState();
}

class _ScreenTimerState extends State<ScreenTimer> {
  DateTime? _startTime;
  Duration _elapsed = Duration.zero;
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _startTime = DateTime.now();
    _isRunning = true;
    _updateTimer();
  }

  void _updateTimer() {
    if (!_isRunning || _startTime == null) return;

    setState(() {
      _elapsed = DateTime.now().difference(_startTime!);
    });

    // Обновляем каждые 16ms (~60 FPS для плавности)
    Future.delayed(const Duration(milliseconds: 16), _updateTimer);
  }

  String _formatDuration(Duration duration) {
    final totalMilliseconds = duration.inMilliseconds;
    final minutes = totalMilliseconds ~/ 60000;
    final seconds = (totalMilliseconds % 60000) ~/ 1000;
    final milliseconds = totalMilliseconds % 1000;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}.'
        '${milliseconds.toString().padLeft(3, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: widget.position == TimerPosition.topLeft || 
           widget.position == TimerPosition.topRight ? 8 : null,
      bottom: widget.position == TimerPosition.bottomLeft || 
              widget.position == TimerPosition.bottomRight ? 8 : null,
      left: widget.position == TimerPosition.topLeft || 
            widget.position == TimerPosition.bottomLeft ? 8 : null,
      right: widget.position == TimerPosition.topRight || 
             widget.position == TimerPosition.bottomRight ? 8 : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.screenName != null) ...[
              Text(
                widget.screenName!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
            ],
            Text(
              _formatDuration(_elapsed),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _isRunning = false;
    super.dispose();
  }
}

/// Позиция таймера на экране
enum TimerPosition {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}
