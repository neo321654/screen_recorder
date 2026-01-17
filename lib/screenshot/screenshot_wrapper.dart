import 'dart:async';
import 'package:flutter/material.dart';
import 'screenshot_controller.dart';
import 'screenshot_capture.dart';

class ScreenshotWrapper extends StatefulWidget {
  final Widget child;
  final ScreenshotController? controller;
  final String? directoryName;
  final String? fileName;
  final bool autoCapture;
  final int autoCaptureCount;
  final Duration autoCaptureInterval;

  const ScreenshotWrapper({
    super.key,
    required this.child,
    this.controller,
    this.directoryName,
    this.fileName,
    this.autoCapture = false,
    this.autoCaptureCount = 3,
    this.autoCaptureInterval = const Duration(seconds: 1),
  });

  @override
  State<ScreenshotWrapper> createState() => _ScreenshotWrapperState();
}

class _ScreenshotWrapperState extends State<ScreenshotWrapper> {
  final GlobalKey _globalKey = GlobalKey();
  late ScreenshotCapture _capture;
  Timer? _autoCaptureTimer;

  @override
  void initState() {
    super.initState();
    print('ScreenshotWrapper initState, autoCapture: ${widget.autoCapture}');
    _capture = ScreenshotCapture(
      globalKey: _globalKey,
      directoryName: widget.directoryName,
      fileName: widget.fileName,
    );
    
    if (widget.controller != null) {
      widget.controller!.setCaptureFunction(_capture.capture);
    }
    
    if (widget.autoCapture) {
      print('Автоматический режим включен, ожидание первого кадра...');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        print('Первый кадр получен, ожидание 2 секунды...');
        Future.delayed(const Duration(seconds: 2), () {
          _startAutoCapture();
        });
      });
    }
  }

  Future<void> _startAutoCapture() async {
    print('Начало автоматического захвата, количество: ${widget.autoCaptureCount}');
    for (int i = 0; i < widget.autoCaptureCount; i++) {
      if (i > 0) {
        await Future.delayed(widget.autoCaptureInterval);
      }
      print('Делаю скриншот ${i + 1}/${widget.autoCaptureCount}');
      try {
        await _capture.capture();
      } catch (e) {
        print('Ошибка при скриншоте ${i + 1}/${widget.autoCaptureCount}: $e');
      }
    }
    print('Автоматический захват завершен');
  }

  @override
  void dispose() {
    _autoCaptureTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(ScreenshotWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.directoryName != oldWidget.directoryName ||
        widget.fileName != oldWidget.fileName) {
      _capture = ScreenshotCapture(
        globalKey: _globalKey,
        directoryName: widget.directoryName,
        fileName: widget.fileName,
      );
      if (widget.controller != null) {
        widget.controller!.setCaptureFunction(_capture.capture);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _globalKey,
      child: widget.child,
    );
  }
}
