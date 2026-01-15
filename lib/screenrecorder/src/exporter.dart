import 'dart:ui' as ui show ImageByteFormat;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;
import 'frame.dart';

/// Агрессивно оптимизированный экспортер GIF
class Exporter {
  Exporter({
    this.resizeRatio = 0.3,
    this.maxGifWidth = 360,
    this.maxGifHeight = 640,
    this.grayscale = false,
    this.targetFps = 10,
  });

  final double resizeRatio;
  final int? maxGifWidth;
  final int? maxGifHeight;
  final bool grayscale;
  final int targetFps;

  final List<CompressedFrame> _frames = [];

  int _maxWidth = 0;
  int _maxHeight = 0;

  /// === ЗАХВАТ КАДРА ===
  Future<void> onNewFrame(Frame frame) async {
    try {
      final originalWidth = frame.image.width;
      final originalHeight = frame.image.height;

      final byteData = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );

      if (byteData == null) {
        frame.image.dispose();
        return;
      }

      final srcImg = image.Image.fromBytes(
        width: originalWidth,
        height: originalHeight,
        bytes: byteData.buffer,
        numChannels: 4,
      );

      int targetWidth = (originalWidth * resizeRatio).round();
      int targetHeight = (originalHeight * resizeRatio).round();

      if (maxGifWidth != null && targetWidth > maxGifWidth!) {
        final scale = maxGifWidth! / targetWidth;
        targetWidth = maxGifWidth!;
        targetHeight = (targetHeight * scale).round();
      }

      if (maxGifHeight != null && targetHeight > maxGifHeight!) {
        final scale = maxGifHeight! / targetHeight;
        targetHeight = maxGifHeight!;
        targetWidth = (targetWidth * scale).round();
      }

      image.Image processed = image.copyResize(
        srcImg,
        width: targetWidth,
        height: targetHeight,
        interpolation: image.Interpolation.average,
      );

      if (grayscale) {
        processed = image.grayscale(processed);
      }

      processed = image.quantize(
        processed,
        numberOfColors: grayscale ? 32 : 128,
      );

      _frames.add(
        CompressedFrame(
          frame.timeStamp,
          processed,
        ),
      );

      _maxWidth = _maxWidth < processed.width ? processed.width : _maxWidth;
      _maxHeight =
      _maxHeight < processed.height ? processed.height : _maxHeight;

      frame.image.dispose();

      debugPrint(
        '[Exporter] ${originalWidth}x$originalHeight → '
            '${processed.width}x${processed.height}'
            '${grayscale ? ' (grayscale)' : ''}',
      );
    } catch (e) {
      debugPrint('[Exporter] Error: $e');
      frame.image.dispose();
    }
  }

  void clear() {
    _frames.clear();
    _maxWidth = 0;
    _maxHeight = 0;
  }

  bool get hasFrames => _frames.isNotEmpty;

  /// Количество захваченных кадров
  int get frameCount => _frames.length;

  /// Временная метка первого кадра
  Duration? get firstFrameTimeStamp => 
      _frames.isNotEmpty ? _frames.first.timeStamp : null;

  /// Временная метка последнего кадра
  Duration? get lastFrameTimeStamp => 
      _frames.isNotEmpty ? _frames.last.timeStamp : null;

  /// === ЭКСПОРТ GIF ===
  Future<List<int>?> exportGif() async {
    if (_frames.isEmpty) return null;

    return compute(
      _encodeGif,
      GifData(
        frames: _frames,
        width: _maxWidth,
        height: _maxHeight,
        frameDurationMs: (1000 / targetFps).round(),
      ),
    );
  }

  static List<int> _encodeGif(GifData data) {
    final gif = image.Image.empty();
    gif.loopCount = 0;

    for (final frame in data.frames) {
      image.Image img = frame.img;

      if (img.width != data.width || img.height != data.height) {
        img = image.copyExpandCanvas(
          img,
          newWidth: data.width,
          newHeight: data.height,
          toImage: image.Image(
            width: data.width,
            height: data.height,
            numChannels: 4,
          ),
        );
      }

      img.frameDuration = data.frameDurationMs;
      gif.frames.add(img);
    }

    return image.encodeGif(gif);
  }
}

/// === ДАННЫЕ ===

class CompressedFrame {
  CompressedFrame(this.timeStamp, this.img);

  final Duration timeStamp;
  final image.Image img;
}

class GifData {
  GifData({
    required this.frames,
    required this.width,
    required this.height,
    required this.frameDurationMs,
  });

  final List<CompressedFrame> frames;
  final int width;
  final int height;
  final int frameDurationMs;
}
