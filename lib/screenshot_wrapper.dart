import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

class _ScreenshotWrapperState extends State<ScreenshotWrapper> {
  final GlobalKey _globalKey = GlobalKey();
  String? _directoryName;
  String? _fileName;

  Future<String> _captureAndSave() async {
    debugPrint('[SCREENSHOT_WRAPPER] _captureAndSave() called');
    try {
      debugPrint('[SCREENSHOT_WRAPPER] Waiting for next frame to ensure rendering is complete...');
      
      await Future(() async {
        final completer = Completer<void>();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          completer.complete();
        });
        return completer.future;
      });
      debugPrint('[SCREENSHOT_WRAPPER] Frame ended, proceeding with capture');
      
      debugPrint('[SCREENSHOT_WRAPPER] Getting render object from GlobalKey');
      if (_globalKey.currentContext == null) {
        debugPrint('[SCREENSHOT_WRAPPER] ERROR: GlobalKey currentContext is null');
        throw Exception('GlobalKey currentContext is null');
      }
      
      final RenderObject? renderObject = _globalKey.currentContext!.findRenderObject();
      if (renderObject == null) {
        debugPrint('[SCREENSHOT_WRAPPER] ERROR: RenderObject is null');
        throw Exception('RenderObject is null');
      }
      
      if (renderObject is! RenderRepaintBoundary) {
        debugPrint('[SCREENSHOT_WRAPPER] ERROR: RenderObject is not RenderRepaintBoundary, type: ${renderObject.runtimeType}');
        throw Exception('RenderObject is not RenderRepaintBoundary');
      }
      
      final RenderRepaintBoundary boundary = renderObject;
      debugPrint('[SCREENSHOT_WRAPPER] RenderRepaintBoundary found');
      debugPrint('[SCREENSHOT_WRAPPER] Checking if boundary needs paint: ${boundary.debugNeedsPaint}');
      
      if (boundary.debugNeedsPaint) {
        debugPrint('[SCREENSHOT_WRAPPER] Boundary needs paint, waiting for another frame...');
        await Future(() async {
          final completer = Completer<void>();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            completer.complete();
          });
          return completer.future;
        });
        debugPrint('[SCREENSHOT_WRAPPER] Frame ended after waiting');
      }
      
      debugPrint('[SCREENSHOT_WRAPPER] Converting to image...');
      final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      debugPrint('[SCREENSHOT_WRAPPER] Image created: ${image.width}x${image.height}');
      
      debugPrint('[SCREENSHOT_WRAPPER] Converting image to PNG bytes...');
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        debugPrint('[SCREENSHOT_WRAPPER] ERROR: byteData is null');
        throw Exception('Failed to convert image to byte data');
      }
      final Uint8List pngBytes = byteData.buffer.asUint8List();
      debugPrint('[SCREENSHOT_WRAPPER] PNG bytes created: ${pngBytes.length} bytes');

      debugPrint('[SCREENSHOT_WRAPPER] Getting directory...');
      final Directory directory = await _getDirectory();
      debugPrint('[SCREENSHOT_WRAPPER] Directory: ${directory.path}');
      
      final String fileName = _fileName ??
          'screenshot_${DateTime.now().millisecondsSinceEpoch}.png';
      debugPrint('[SCREENSHOT_WRAPPER] File name: $fileName');
      
      final File file = File('${directory.path}/$fileName');
      debugPrint('[SCREENSHOT_WRAPPER] Full file path: ${file.path}');

      debugPrint('[SCREENSHOT_WRAPPER] Writing ${pngBytes.length} bytes to file...');
      await file.writeAsBytes(pngBytes);
      debugPrint('[SCREENSHOT_WRAPPER] File written successfully');
      
      final fileExists = await file.exists();
      final fileSize = fileExists ? await file.length() : 0;
      debugPrint('[SCREENSHOT_WRAPPER] File exists: $fileExists, size: $fileSize bytes');
      
      debugPrint('[SCREENSHOT_WRAPPER] Screenshot saved successfully: ${file.path}');
      return file.path;
    } catch (e, stackTrace) {
      debugPrint('[SCREENSHOT_WRAPPER] ERROR in _captureAndSave()');
      debugPrint('[SCREENSHOT_WRAPPER] Error type: ${e.runtimeType}');
      debugPrint('[SCREENSHOT_WRAPPER] Error message: $e');
      debugPrint('[SCREENSHOT_WRAPPER] Stack trace: $stackTrace');
      throw Exception('Failed to capture screenshot: $e');
    }
  }

  Future<Directory> _getDirectory() async {
    debugPrint('[SCREENSHOT_WRAPPER] _getDirectory() called');
    debugPrint('[SCREENSHOT_WRAPPER] Directory name: $_directoryName');
    
    Directory? targetDir;
    
    try {
      debugPrint('[SCREENSHOT_WRAPPER] Trying to get external storage directory...');
      final Directory? extStorage = await getExternalStorageDirectory();
      if (extStorage != null) {
        debugPrint('[SCREENSHOT_WRAPPER] External storage directory: ${extStorage.path}');
        final String extPath = extStorage.path;
        final int androidIndex = extPath.indexOf('/Android/');
        if (androidIndex != -1) {
          final String publicPath = extPath.substring(0, androidIndex);
          debugPrint('[SCREENSHOT_WRAPPER] Public storage path: $publicPath');
          targetDir = Directory('$publicPath/Pictures');
        } else {
          debugPrint('[SCREENSHOT_WRAPPER] Could not find Android directory, using parent');
          targetDir = Directory('${extStorage.parent.path}/Pictures');
        }
        debugPrint('[SCREENSHOT_WRAPPER] Target Pictures directory: ${targetDir.path}');
      }
    } catch (e) {
      debugPrint('[SCREENSHOT_WRAPPER] Error getting external storage: $e');
    }
    
    if (targetDir == null) {
      debugPrint('[SCREENSHOT_WRAPPER] External storage not available, using application documents directory...');
      targetDir = await getApplicationDocumentsDirectory();
      debugPrint('[SCREENSHOT_WRAPPER] App documents directory: ${targetDir.path}');
    }
    
    final String finalDirName = _directoryName ?? 'Screenshots';
    final Directory customDir = Directory('${targetDir.path}/$finalDirName');
    debugPrint('[SCREENSHOT_WRAPPER] Final directory path: ${customDir.path}');
    
    final exists = await customDir.exists();
    debugPrint('[SCREENSHOT_WRAPPER] Directory exists: $exists');
    
    if (!exists) {
      debugPrint('[SCREENSHOT_WRAPPER] Creating directory...');
      await customDir.create(recursive: true);
      debugPrint('[SCREENSHOT_WRAPPER] Directory created');
    }
    
    return customDir;
  }

  @override
  void initState() {
    super.initState();
    debugPrint('[SCREENSHOT_WRAPPER] initState() called');
    _directoryName = widget.directoryName;
    _fileName = widget.fileName;
    debugPrint('[SCREENSHOT_WRAPPER] Directory name: $_directoryName');
    debugPrint('[SCREENSHOT_WRAPPER] File name: $_fileName');
  }

  @override
  void didUpdateWidget(ScreenshotWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    debugPrint('[SCREENSHOT_WRAPPER] didUpdateWidget() called');
    if (widget.directoryName != oldWidget.directoryName) {
      debugPrint('[SCREENSHOT_WRAPPER] Directory name changed: ${oldWidget.directoryName} -> ${widget.directoryName}');
      _directoryName = widget.directoryName;
    }
    if (widget.fileName != oldWidget.fileName) {
      debugPrint('[SCREENSHOT_WRAPPER] File name changed: ${oldWidget.fileName} -> ${widget.fileName}');
      _fileName = widget.fileName;
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[SCREENSHOT_WRAPPER] build() called');
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
    debugPrint('[SCREENSHOT_EXTENSION] captureScreenshot() called from extension');
    debugPrint('[SCREENSHOT_EXTENSION] Looking for ScreenshotWrapper in widget tree...');
    final inherited = _ScreenshotWrapperInherited.of(this);
    if (inherited == null) {
      debugPrint('[SCREENSHOT_EXTENSION] ERROR: ScreenshotWrapper not found in widget tree');
      throw Exception('ScreenshotWrapper not found in widget tree');
    }
    debugPrint('[SCREENSHOT_EXTENSION] ScreenshotWrapper found, calling captureAndSave()');
    return await inherited.captureAndSave();
  }
}
