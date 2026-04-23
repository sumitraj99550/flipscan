import 'dart:io';
import 'dart:isolate';
import 'package:image/image.dart' as img;
import '../app/constants.dart';
import '../models/scanned_page.dart';
import '../services/storage_service.dart';

class EnhancementService {
  EnhancementService._internal();
  static final EnhancementService instance = EnhancementService._internal();

  /// Enhance image and save to enhanced path.
  /// Returns the enhanced image path.
  Future<String> enhancePage({
    required String sourceImagePath,
    required String pageId,
    required EnhancementMode mode,
  }) async {
    // Run in isolate to avoid blocking UI
    final resultPath = await Isolate.run(() async {
      return _processImage(sourceImagePath, pageId, mode);
    });

    return resultPath;
  }

  static Future<String> _processImage(
    String sourcePath,
    String pageId,
    EnhancementMode mode,
  ) async {
    final file = File(sourcePath);
    if (!await file.exists()) throw Exception('Source image not found');

    final bytes = await file.readAsBytes();
    img.Image? image = img.decodeImage(bytes);
    if (image == null) throw Exception('Could not decode image');

    // Apply enhancement
    final enhanced = _enhance(image, mode);

    // Save
    final filename = 'enhanced_$pageId.jpg';
    final savePath = await StorageService.instance.saveImage(
      img.encodeJpg(enhanced, quality: AppConstants.jpegQuality),
      filename,
    );

    return savePath;
  }

  static img.Image _enhance(img.Image image, EnhancementMode mode) {
    switch (mode) {
      case EnhancementMode.original:
        return image;

      case EnhancementMode.blackAndWhite:
        final gray = img.grayscale(image);
        return _adaptiveThreshold(gray);

      case EnhancementMode.enhanced:
        final sharpened = _sharpen(image);
        return img.adjustColor(sharpened,
            contrast: 1.15, saturation: 0.85, brightness: 0.05);

      case EnhancementMode.highContrast:
        final gray = img.grayscale(image);
        return img.adjustColor(gray, contrast: 2.0, brightness: 0.1);

      case EnhancementMode.colorPreserve:
        return img.adjustColor(image,
            contrast: 1.1, saturation: 1.15, brightness: 0.03);
    }
  }

  /// Simple adaptive threshold simulation
  static img.Image _adaptiveThreshold(img.Image gray) {
    final result = img.Image(width: gray.width, height: gray.height);
    const blockSize = 11;
    const c = 8;

    for (int y = 0; y < gray.height; y++) {
      for (int x = 0; x < gray.width; x++) {
        // Compute local mean in blockSize x blockSize window
        double sum = 0;
        int count = 0;

        for (int dy = -blockSize ~/ 2; dy <= blockSize ~/ 2; dy++) {
          for (int dx = -blockSize ~/ 2; dx <= blockSize ~/ 2; dx++) {
            final nx = (x + dx).clamp(0, gray.width - 1);
            final ny = (y + dy).clamp(0, gray.height - 1);
            sum += gray.getPixel(nx, ny).luminance * 255;
            count++;
          }
        }

        final localMean = sum / count;
        final pixelVal = gray.getPixel(x, y).luminance * 255;
        final binaryVal = pixelVal < (localMean - c) ? 0 : 255;

        result.setPixelRgb(x, y, binaryVal, binaryVal, binaryVal);
      }
    }
    return result;
  }

  /// Unsharp mask sharpening
  static img.Image _sharpen(img.Image image) {
    return img.convolution(image, filter: [
      0, -1, 0,
      -1, 5, -1,
      0, -1, 0,
    ], div: 1);
  }
}