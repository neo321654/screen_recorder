import 'dart:ui' as ui show ImageByteFormat;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;
import 'frame.dart';

/// Сжатый кадр с JPEG данными тест kk
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

class Exporter {
  Exporter({
    this.resizeRatio = 0.5,
    this.jpegQuality = 75,
  });

  final List<CompressedFrame> _compressedFrames = [];
  int _maxWidthFrame = 0;
  int _maxHeightFrame = 0;

  // Для обратной совместимости - возвращаем пустой список
  // так как теперь используем CompressedFrame
  List<Frame> get frames => [];

  /// Количество сжатых кадров
  int get frameCount => _compressedFrames.length;

  /// Временная метка первого кадра (для расчета длительности)
  Duration? get firstFrameTimeStamp => 
      _compressedFrames.isNotEmpty ? _compressedFrames.first.timeStamp : null;

  /// Временная метка последнего кадра (для расчета длительности)
  Duration? get lastFrameTimeStamp => 
      _compressedFrames.isNotEmpty ? _compressedFrames.last.timeStamp : null;

  /// Коэффициент ресайза (по умолчанию 50% от оригинала для меньшего размера)
  /// Значение от 0.3 до 1.0. Меньше значение = меньше размер файла, но ниже качество
  final double resizeRatio;

  /// Качество JPEG (по умолчанию 75% для меньшего размера)
  /// Значение от 1 до 100. Меньше значение = меньше размер файла, но ниже качество
  final int jpegQuality;

  /// Обрабатывает новый кадр: сжимает его сразу после захвата
  /// Реализует комбинированный подход: ресайз + JPEG сжатие
  Future<void> onNewFrame(Frame frame) async {
    try {
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

      // Сохраняем оригинальные размеры
      final originalWidth = decodedImage.width;
      final originalHeight = decodedImage.height;

      // Обновляем максимальные размеры для экспорта
      if (originalWidth >= _maxWidthFrame) {
        _maxWidthFrame = originalWidth;
      }
      if (originalHeight >= _maxHeightFrame) {
        _maxHeightFrame = originalHeight;
      }

      // 1. РЕСАЙЗ до указанного процента от оригинала
      final resizedImage = image.copyResize(
        decodedImage,
        width: (originalWidth * resizeRatio).round(),
        height: (originalHeight * resizeRatio).round(),
        interpolation: image.Interpolation.cubic, // Лучшее качество при ресайзе
      );

      // 2. СЖАТИЕ JPEG с указанным качеством
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

      // Освобождаем память от оригинального ui.Image
      frame.image.dispose();

      debugPrint(
        '[Exporter] Frame compressed: ${originalWidth}x$originalHeight -> '
        '${resizedImage.width}x${resizedImage.height}, '
        'JPEG size: ${(jpegBytes.length / 1024).toStringAsFixed(2)} KB',
      );
    } catch (e, stackTrace) {
      debugPrint('[Exporter] Error compressing frame: $e');
      debugPrint('[Exporter] Stack trace: $stackTrace');
      // Освобождаем память даже при ошибке
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
    
    for (final compressedFrame in _compressedFrames) {
      try {
        // Декодируем JPEG обратно в изображение
        final decodedImage = image.decodeJpg(compressedFrame.jpegBytes);
        
        if (decodedImage == null) {
          debugPrint('[Exporter] Failed to decode JPEG frame');
          continue;
        }

        // Конвертируем обратно в PNG для GIF (GIF нужен RGBA формат)
        // Расширяем до оригинального размера, если нужно
        image.Image finalImage;
        if (decodedImage.width != compressedFrame.originalWidth ||
            decodedImage.height != compressedFrame.originalHeight) {
          // Расширяем до оригинального размера для консистентности
          finalImage = image.copyExpandCanvas(
            decodedImage,
            newWidth: compressedFrame.originalWidth,
            newHeight: compressedFrame.originalHeight,
            toImage: image.Image(
              width: compressedFrame.originalWidth,
              height: compressedFrame.originalHeight,
              format: decodedImage.format,
              numChannels: 4,
            ),
          );
        } else {
          finalImage = decodedImage;
        }

        // Кодируем в PNG для RawFrame
        final pngBytes = image.encodePng(finalImage);
        final byteData = ByteData.view(pngBytes.buffer);
        
        bytesImages.add(RawFrame(16, byteData));
      } catch (e) {
        debugPrint('[Exporter] Error processing compressed frame: $e');
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
      
      mainImage.frames.add(_encodeGifWIthTransparency(finalImage));
    }

    return image.encodeGif(mainImage);
  }

  static image.PaletteUint8 _convertPalette(image.Palette palette) {
    final newPalette = image.PaletteUint8(palette.numColors, 4);
    for (var i = 0; i < palette.numColors; i++) {
      newPalette.setRgba(
          i, palette.getRed(i), palette.getGreen(i), palette.getBlue(i), 255);
    }
    return newPalette;
  }

  static image.Image _encodeGifWIthTransparency(image.Image srcImage,
      {int transparencyThreshold = 1}) {
    final newImage = image.quantize(srcImage);

    // GifEncoder will use palette colors with a 0 alpha as transparent. Look at the pixels
    // of the original image and set the alpha of the palette color to 0 if the pixel is below
    // a transparency threshold.
    final numFrames = srcImage.frames.length;
    for (var frameIndex = 0; frameIndex < numFrames; frameIndex++) {
      final srcFrame = srcImage.frames[frameIndex];
      final newFrame = newImage.frames[frameIndex];

      final palette = _convertPalette(newImage.palette!);

      for (final srcPixel in srcFrame) {
        if (srcPixel.a < transparencyThreshold) {
          final newPixel = newFrame.getPixel(srcPixel.x, srcPixel.y);
          palette.setAlpha(
              newPixel.index.toInt(), 0); // Set the palette color alpha to 0
        }
      }

      newFrame.data!.palette = palette;
    }

    return newImage;
  }
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
