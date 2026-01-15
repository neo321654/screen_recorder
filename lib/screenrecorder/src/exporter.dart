import 'dart:ui' as ui show ImageByteFormat;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;
import 'frame.dart';

/// Оптимизированный экспортер с агрессивным сжатием для уменьшения размера файла
class Exporter {
  Exporter({
    this.resizeRatio = 0.35,
    this.jpegQuality = 60,
    this.maxGifWidth = 360,
    this.maxGifHeight = 640,
  });

  /// Сжатые кадры хранятся как JPEG для экономии памяти
  final List<CompressedFrame> _compressedFrames = [];
  int _maxWidthFrame = 0;
  int _maxHeightFrame = 0;

  /// Коэффициент ресайза при захвате (по умолчанию 40% для минимального размера)
  final double resizeRatio;

  /// Качество JPEG сжатия (по умолчанию 65 для минимального размера)
  final int jpegQuality;

  /// Максимальная ширина GIF (дополнительное ограничение размера)
  final int? maxGifWidth;

  /// Максимальная высота GIF (дополнительное ограничение размера)
  final int? maxGifHeight;

  List<Frame> get frames => [];

  /// Количество сжатых кадров
  int get frameCount => _compressedFrames.length;

  /// Временная метка первого кадра
  Duration? get firstFrameTimeStamp => 
      _compressedFrames.isNotEmpty ? _compressedFrames.first.timeStamp : null;

  /// Временная метка последнего кадра
  Duration? get lastFrameTimeStamp => 
      _compressedFrames.isNotEmpty ? _compressedFrames.last.timeStamp : null;

  /// Обрабатывает новый кадр: сжимает его сразу после захвата
  /// Оптимизированная версия с агрессивным сжатием
  Future<void> onNewFrame(Frame frame) async {
    try {
      // Сохраняем оригинальные размеры до обработки
      final originalWidth = frame.image.width;
      final originalHeight = frame.image.height;

      // Конвертируем ui.Image в PNG байты
      final pngBytes = await frame.image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (pngBytes == null) {
        debugPrint('[Exporter] Failed to convert image to PNG bytes');
        frame.image.dispose();
        return;
      }

      // Декодируем PNG
      final pngData = pngBytes.buffer.asUint8List();
      final decodedImage = image.decodePng(pngData);

      if (decodedImage == null) {
        debugPrint('[Exporter] Failed to decode PNG');
        frame.image.dispose();
        return;
      }

      // Вычисляем целевой размер с учетом ограничений GIF
      int targetWidth = (originalWidth * resizeRatio).round();
      int targetHeight = (originalHeight * resizeRatio).round();

      // Применяем дополнительные ограничения размера для GIF
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

      // Ресайз до целевого размера
      final resizedImage = image.copyResize(
        decodedImage,
        width: targetWidth,
        height: targetHeight,
        interpolation: image.Interpolation.linear, // Быстрее чем cubic, но все еще хорошо
      );

      // Сжимаем в JPEG
      final jpegBytes = image.encodeJpg(resizedImage, quality: jpegQuality);

      // Сохраняем сжатый кадр
      _compressedFrames.add(CompressedFrame(
        frame.timeStamp,
        jpegBytes,
        originalWidth,
        originalHeight,
        resizedImage.width,
        resizedImage.height,
      ));

      // Освобождаем память немедленно
      frame.image.dispose();

      debugPrint(
        '[Exporter] Frame: ${originalWidth}x$originalHeight -> '
        '${resizedImage.width}x${resizedImage.height}, '
        'Size: ${(jpegBytes.length / 1024).toStringAsFixed(1)} KB',
      );
    } catch (e) {
      debugPrint('[Exporter] Error: $e');
      frame.image.dispose();
    }
  }

  void clear() {
    _compressedFrames.clear();
    _maxWidthFrame = 0;
    _maxHeightFrame = 0;
  }

  bool get hasFrames => _compressedFrames.isNotEmpty;

  Future<List<RawFrame>?> exportFrames() async {
    if (_compressedFrames.isEmpty) {
      return null;
    }
    
    final bytesImages = <RawFrame>[];
    
    // Находим максимальные размеры среди сжатых кадров
    int maxWidth = 0;
    int maxHeight = 0;
    for (final compressedFrame in _compressedFrames) {
      if (compressedFrame.compressedWidth > maxWidth) {
        maxWidth = compressedFrame.compressedWidth;
      }
      if (compressedFrame.compressedHeight > maxHeight) {
        maxHeight = compressedFrame.compressedHeight;
      }
    }
    
    _maxWidthFrame = maxWidth;
    _maxHeightFrame = maxHeight;
    
    // Конвертируем сжатые кадры обратно в PNG для GIF
    for (final compressedFrame in _compressedFrames) {
      try {
        // Декодируем JPEG
        final decodedImage = image.decodeJpg(compressedFrame.jpegBytes);
        
        if (decodedImage == null) {
          debugPrint('[Exporter] Failed to decode JPEG frame');
          continue;
        }

        // Используем сжатый размер, не расширяем обратно!
        // Это ключевая оптимизация - используем уже уменьшенные размеры
        image.Image finalImage = decodedImage;

        // Кодируем в PNG для RawFrame
        final pngBytes = image.encodePng(finalImage);
        final byteData = ByteData.view(pngBytes.buffer);
        
        bytesImages.add(RawFrame(16, byteData));
      } catch (e) {
        debugPrint('[Exporter] Error processing frame: $e');
        continue;
      }
    }
    
    return bytesImages;
  }

  Future<List<int>?> exportGif() async {
    final frames = await exportFrames();
    if (frames == null) {
      return null;
    }
    return compute(
        _exportGif, DataHolder(frames, _maxWidthFrame, _maxHeightFrame));
  }

  static Future<List<int>?> _exportGif(DataHolder data) async {
    List<RawFrame> frames = data.frames;
    int width = data.width;
    int height = data.height;

    image.Image mainImage = image.Image.empty();

    for (final frame in frames) {
      final iAsBytes = frame.image.buffer.asUint8List();
      final decodedImage = image.decodePng(iAsBytes);

      if (decodedImage == null) {
        debugPrint('[Exporter] Skipped frame while encoding GIF');
        continue;
      }
      
      decodedImage.frameDuration = frame.durationInMillis;
      
      // Если размеры не совпадают, расширяем до максимального размера
      image.Image finalImage;
      if (decodedImage.width != width || decodedImage.height != height) {
        finalImage = image.copyExpandCanvas(
          decodedImage,
          newWidth: width,
          newHeight: height,
          toImage: image.Image(
            width: width,
            height: height,
            format: decodedImage.format,
            numChannels: 4,
          ),
        );
      } else {
        finalImage = decodedImage;
      }
      
      // Применяем оптимизацию для GIF
      mainImage.frames.add(_encodeGifWithOptimization(finalImage));
    }

    return image.encodeGif(mainImage);
  }

  /// Оптимизированное кодирование GIF с агрессивной квантовкой
  static image.Image _encodeGifWithOptimization(image.Image srcImage,
      {int transparencyThreshold = 1, int maxColors = 128}) {
    // Используем более агрессивную квантовку для меньшего размера
    final newImage = image.quantize(srcImage, numberOfColors: maxColors);

    // Обрабатываем прозрачность
    final numFrames = srcImage.frames.length;
    for (var frameIndex = 0; frameIndex < numFrames; frameIndex++) {
      final srcFrame = srcImage.frames[frameIndex];
      final newFrame = newImage.frames[frameIndex];

      final palette = _convertPalette(newImage.palette!);

      for (final srcPixel in srcFrame) {
        if (srcPixel.a < transparencyThreshold) {
          final newPixel = newFrame.getPixel(srcPixel.x, srcPixel.y);
          palette.setAlpha(newPixel.index.toInt(), 0);
        }
      }

      newFrame.data!.palette = palette;
    }

    return newImage;
  }

  static image.PaletteUint8 _convertPalette(image.Palette palette) {
    final newPalette = image.PaletteUint8(palette.numColors, 4);
    for (var i = 0; i < palette.numColors; i++) {
      newPalette.setRgba(
          i, palette.getRed(i), palette.getGreen(i), palette.getBlue(i), 255);
    }
    return newPalette;
  }
}

/// Сжатый кадр с JPEG данными
class CompressedFrame {
  CompressedFrame(
    this.timeStamp,
    this.jpegBytes,
    this.originalWidth,
    this.originalHeight,
    this.compressedWidth,
    this.compressedHeight,
  );

  final Duration timeStamp;
  final Uint8List jpegBytes;
  final int originalWidth;
  final int originalHeight;
  final int compressedWidth;
  final int compressedHeight;
}

class RawFrame {
  RawFrame(this.durationInMillis, this.image);

  final int durationInMillis;
  final ByteData image;
}

class DataHolder {
  DataHolder(this.frames, this.width, this.height);

  List<RawFrame> frames;
  int width;
  int height;
}
