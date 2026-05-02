import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset; // BUG FIX #3: Use dart:ui Offset, not a local class.
import 'package:image/image.dart' as img;
import '../app/constants.dart';
import '../models/scanned_page.dart';

class ImageUtils {
  /// Decode image file to img.Image
  static Future<img.Image?> loadImage(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    return img.decodeImage(bytes);
  }

  /// Save img.Image as JPEG to path
  static Future<void> saveJpeg(img.Image image, String path,
      {int quality = 85}) async {
    final bytes = img.encodeJpg(image, quality: quality);
    await File(path).writeAsBytes(bytes);
  }

  /// Generate thumbnail (200x200 max)
  static Future<Uint8List> generateThumbnail(img.Image image,
      {int size = AppConstants.thumbnailSize}) async {
    final thumb = img.copyResize(image,
        width: image.width > image.height ? size : -1,
        height: image.height >= image.width ? size : -1);
    return Uint8List.fromList(img.encodeJpg(thumb, quality: 75));
  }

  /// Rotate image by degrees (90, 180, 270)
  static img.Image rotate(img.Image image, int degrees) {
    switch (degrees % 360) {
      case 90:
        return img.copyRotate(image, angle: 90);
      case 180:
        return img.copyRotate(image, angle: 180);
      case 270:
        return img.copyRotate(image, angle: 270);
      default:
        return image;
    }
  }

  /// Apply enhancement mode to image
  static img.Image applyEnhancement(img.Image image, EnhancementMode mode) {
    switch (mode) {
      case EnhancementMode.original:
        return image;
      case EnhancementMode.blackAndWhite:
        return _applyBlackAndWhite(image);
      case EnhancementMode.enhanced:
        return _applyEnhanced(image);
      case EnhancementMode.highContrast:
        return _applyHighContrast(image);
      case EnhancementMode.colorPreserve:
        return _applyColorPreserve(image);
    }
  }

  static img.Image _applyBlackAndWhite(img.Image image) {
    final gray = img.grayscale(image);
    return img.adjustColor(gray, contrast: 1.3, brightness: 0.1);
  }

  static img.Image _applyEnhanced(img.Image image) {
    final sharpened = img.convolution(image, filter: [
      0, -1, 0,
      -1, 5, -1,
      0, -1, 0,
    ], div: 1);
    return img.adjustColor(sharpened, contrast: 1.2, saturation: 0.8);
  }

  static img.Image _applyHighContrast(img.Image image) {
    return img.adjustColor(image, contrast: 1.8, brightness: 0.05);
  }

  static img.Image _applyColorPreserve(img.Image image) {
    return img.adjustColor(image,
        contrast: 1.1, saturation: 1.1, brightness: 0.05);
  }

  /// Crop image to a quadrilateral bounding box.
  /// [corners] are normalized 0..1 coordinates using dart:ui Offset.
  static img.Image cropToRect(img.Image image, List<Offset> corners) {
    final xs = corners.map((c) => c.dx * image.width).toList();
    final ys = corners.map((c) => c.dy * image.height).toList();

    final left = xs.reduce(math.min).toInt().clamp(0, image.width - 1);
    final top = ys.reduce(math.min).toInt().clamp(0, image.height - 1);
    final right = xs.reduce(math.max).toInt().clamp(0, image.width - 1);
    final bottom = ys.reduce(math.max).toInt().clamp(0, image.height - 1);

    return img.copyCrop(image,
        x: left, y: top, width: right - left, height: bottom - top);
  }

  /// Generate unique filename for a page image
  static String generateImageFilename(String sessionId, int pageNumber) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'page_${sessionId}_${pageNumber}_$timestamp.jpg';
  }

  /// Format file size
  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// BUG FIX #3: REMOVED the local `class Offset` that was previously defined here.
// It shadowed dart:ui's Offset, causing type-mismatch compile errors in any
// file that imported both image_utils.dart and package:flutter/material.dart.
