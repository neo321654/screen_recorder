import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

class _ScreenshotWrapperState extends State<ScreenshotWrapper> {
  final GlobalKey _globalKey = GlobalKey();
  String? _directoryName;
  String? _fileName;

  Future<String> _captureAndSave() async {
    try {
      final RenderRepaintBoundary boundary =
          _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      final Directory directory = await _getDirectory();
      final String fileName = _fileName ??
          'screenshot_${DateTime.now().millisecondsSinceEpoch}.png';
      final File file = File('${directory.path}/$fileName');

      await file.writeAsBytes(pngBytes);
      return file.path;
    } catch (e) {
      throw Exception('Failed to capture screenshot: $e');
    }
  }

  Future<Directory> _getDirectory() async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    if (_directoryName != null) {
      final Directory customDir =
          Directory('${appDocDir.path}/$_directoryName');
      if (!await customDir.exists()) {
        await customDir.create(recursive: true);
      }
      return customDir;
    }
    return appDocDir;
  }

  @override
  void initState() {
    super.initState();
    _directoryName = widget.directoryName;
    _fileName = widget.fileName;
  }

  @override
  void didUpdateWidget(ScreenshotWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.directoryName != oldWidget.directoryName) {
      _directoryName = widget.directoryName;
    }
    if (widget.fileName != oldWidget.fileName) {
      _fileName = widget.fileName;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ScreenshotWrapperInherited(
      captureAndSave: _captureAndSave,
      child: RepaintBoundary(
        key: _globalKey,
        child: widget.child,
      ),
    );
  }
}

class _ScreenshotWrapperInherited extends InheritedWidget {
  final Future<String> Function() captureAndSave;

  const _ScreenshotWrapperInherited({
    required this.captureAndSave,
    required super.child,
  });

  static _ScreenshotWrapperInherited? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_ScreenshotWrapperInherited>();
  }

  @override
  bool updateShouldNotify(_ScreenshotWrapperInherited oldWidget) {
    return false;
  }
}

class ScreenshotWrapper extends StatefulWidget {
  final Widget child;
  final String? directoryName;
  final String? fileName;

  const ScreenshotWrapper({
    super.key,
    required this.child,
    this.directoryName,
    this.fileName,
  });

  @override
  State<ScreenshotWrapper> createState() => _ScreenshotWrapperState();
}

extension ScreenshotExtension on BuildContext {
  Future<String> captureScreenshot() async {
    final inherited = _ScreenshotWrapperInherited.of(this);
    if (inherited == null) {
      throw Exception('ScreenshotWrapper not found in widget tree');
    }
    return await inherited.captureAndSave();
  }
}
