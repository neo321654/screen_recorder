import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../utils/storage_helper.dart';

class ScreenshotCapture {
  final GlobalKey _globalKey;
  final String? directoryName;
  final String? fileName;

  ScreenshotCapture({
    required GlobalKey globalKey,
    this.directoryName,
    this.fileName,
  }) : _globalKey = globalKey;

  Future<String> capture() async {
    await _waitForFrame();

    final RenderRepaintBoundary boundary = _getRenderBoundary();
    
    if (boundary.debugNeedsPaint) {
      await _waitForFrame();
    }

    final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    
    if (byteData == null) {
      throw Exception('Failed to convert image to byte data');
    }

    final Uint8List pngBytes = byteData.buffer.asUint8List();
    final Directory directory = await StorageHelper.getScreenshotDirectory(directoryName);
    final String fileName = this.fileName ?? 'screenshot_${DateTime.now().millisecondsSinceEpoch}.png';
    final File file = File('${directory.path}/$fileName');

    await file.writeAsBytes(pngBytes);
    print('Скриншот сохранен: ${file.path}');
    return file.path;
  }

  Future<void> _waitForFrame() async {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) => completer.complete());
    return completer.future;
  }

  RenderRepaintBoundary _getRenderBoundary() {
    if (_globalKey.currentContext == null) {
      throw Exception('GlobalKey currentContext is null');
    }

    final RenderObject? renderObject = _globalKey.currentContext!.findRenderObject();
    if (renderObject == null) {
      throw Exception('RenderObject is null');
    }

    if (renderObject is! RenderRepaintBoundary) {
      throw Exception('RenderObject is not RenderRepaintBoundary');
    }

    return renderObject;
  }
}
