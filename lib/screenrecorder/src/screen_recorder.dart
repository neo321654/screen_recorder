import 'dart:ui' as ui show Image;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'exporter.dart';
import 'frame.dart';

class ScreenRecorderController {
  ScreenRecorderController({
    Exporter? exporter,
    this.pixelRatio = 0.25,
    this.skipFramesBetweenCaptures = 2,
    SchedulerBinding? binding,
    double? resizeRatio,
    int? jpegQuality,
    int? maxGifWidth,
    int? maxGifHeight,
  })  : _containerKey = GlobalKey(),
        _binding = binding ?? SchedulerBinding.instance,
        _exporter = exporter ?? Exporter(
          resizeRatio: resizeRatio ?? 0.35,
          jpegQuality: jpegQuality ?? 60,
          maxGifWidth: maxGifWidth,
          maxGifHeight: maxGifHeight,
        );

  final GlobalKey _containerKey;
  final SchedulerBinding _binding;
  final Exporter _exporter;

  Exporter get exporter => _exporter;

  /// The pixelRatio describes the scale between the logical pixels and the size
  /// of the output image. Specifying 1.0 will give you a 1:1 mapping between
  /// logical pixels and the output pixels in the image. 
  /// 
  /// По умолчанию 0.3 для оптимизации размера файла (меньше значение = меньше размер).
  /// Рекомендуемые значения: 0.3-0.5 для минимального размера, 0.5-0.7 для баланса.
  ///
  /// See [RenderRepaintBoundary](https://api.flutter.dev/flutter/rendering/RenderRepaintBoundary/toImage.html)
  /// for the underlying implementation.
  final double pixelRatio;

  /// Describes how many frames are skipped between caputerd frames.
  /// For example if it's `skipFramesBetweenCaptures = 2` screen_recorder
  /// captures a frame, skips the next two frames and then captures the next
  /// frame again.
  final int skipFramesBetweenCaptures;

  int skipped = 0;

  bool _record = false;

  void start() {
    // only start a video, if no recording is in progress
    if (_record == true) {
      return;
    }
    _record = true;
    _binding.addPostFrameCallback(postFrameCallback);
  }

  void stop() {
    _record = false;
  }

  void postFrameCallback(Duration timestamp) async {
    if (_record == false) {
      return;
    }
    if (skipped > 0) {
      // count down frames which should be skipped
      skipped = skipped - 1;
      // add a new PostFrameCallback to know about the next frame
      _binding.addPostFrameCallback(postFrameCallback);
      // but we do nothing, because we skip this frame
      return;
    }
    if (skipped == 0) {
      // reset skipped frame counter
      skipped = skipped + skipFramesBetweenCaptures;
    }
    try {
      final image = capture();
      if (image == null) {
        debugPrint('capture returned null');
        return;
      }
      _exporter.onNewFrame(Frame(timestamp, image));
    } catch (e) {
      debugPrint(e.toString());
    }
    _binding.addPostFrameCallback(postFrameCallback);
  }

  ui.Image? capture() {
    final renderObject = _containerKey.currentContext!.findRenderObject()
        as RenderRepaintBoundary;

    return renderObject.toImageSync(pixelRatio: pixelRatio);
  }
}

class ScreenRecorder extends StatelessWidget {
  const ScreenRecorder({
    super.key,
    required this.child,
    required this.controller,
    required this.width,
    required this.height,
    this.background = Colors.transparent,
  });

  /// The child which should be recorded.
  final Widget child;

  /// This controller starts and stops the recording.
  final ScreenRecorderController controller;

  /// Width of the recording.
  /// This should not change during recording as it could lead to
  /// undefined behavior.
  final double width;

  /// Height of the recording
  /// This should not change during recording as it could lead to
  /// undefined behavior.
  final double height;

  /// The background color of the recording.
  /// Transparency is currently not supported.
  final Color background;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: controller._containerKey,
      child: Container(
        width: width,
        height: height,
        color: background,
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}
