import 'dart:math' as math;
import 'package:image/image.dart' as img;

/// Detects blur using Laplacian variance method.
/// Higher score = sharper image.
/// Threshold ~80 for document scanning quality.
class BlurDetector {
  /// Compute Laplacian variance on a grayscale image.
  /// Returns variance score: higher = sharper.
  static double computeVariance(img.Image image) {
    final gray = img.grayscale(image);
    final width = gray.width;
    final height = gray.height;

    // Laplacian kernel: [0,1,0],[1,-4,1],[0,1,0]
    double sum = 0;
    double sumSq = 0;
    int count = 0;

    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        final center = _getLuminance(gray, x, y);
        final top = _getLuminance(gray, x, y - 1);
        final bottom = _getLuminance(gray, x, y + 1);
        final left = _getLuminance(gray, x - 1, y);
        final right = _getLuminance(gray, x + 1, y);

        final laplacian = (top + bottom + left + right - 4 * center).abs();
        sum += laplacian;
        sumSq += laplacian * laplacian;
        count++;
      }
    }

    if (count == 0) return 0;
    final mean = sum / count;
    final variance = (sumSq / count) - (mean * mean);
    return math.max(0, variance);
  }

  static double _getLuminance(img.Image image, int x, int y) {
    final pixel = image.getPixel(x, y);
    return pixel.luminance * 255;
  }

  /// Returns true if image is considered sharp enough for document scanning
  static bool isSharp(img.Image image, {double threshold = 80.0}) {
    return computeVariance(image) >= threshold;
  }

  /// Quick blur check on downscaled image for performance
  static bool isSharpFast(img.Image image, {double threshold = 80.0}) {
    // Downscale to max 200x200 for speed
    final scaled = img.copyResize(image,
        width: math.min(image.width, 200),
        height: math.min(image.height, 200));
    return isSharp(scaled, threshold: threshold);
  }

  /// Get blur label for UI display
  static String getBlurLabel(double score) {
    if (score >= 200) return 'Excellent';
    if (score >= 120) return 'Good';
    if (score >= 80) return 'Acceptable';
    if (score >= 40) return 'Blurry';
    return 'Very Blurry';
  }
}
