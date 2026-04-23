import 'package:image/image.dart' as img;

/// Perceptual hashing (pHash) for duplicate image detection.
/// Returns a 64-bit hash. Hamming distance < 10 = likely duplicate.
class PerceptualHash {
  /// Compute 64-bit perceptual hash
  static int compute(img.Image image) {
    // Step 1: Resize to 8x8
    final small = img.copyResize(image, width: 8, height: 8);
    final gray = img.grayscale(small);

    // Step 2: Get pixel values and compute mean
    final pixels = <double>[];
    for (int y = 0; y < 8; y++) {
      for (int x = 0; x < 8; x++) {
        pixels.add(gray.getPixel(x, y).luminance * 255);
      }
    }

    final mean = pixels.reduce((a, b) => a + b) / pixels.length;

    // Step 3: Build hash: 1 if pixel > mean, 0 otherwise
    int hash = 0;
    for (int i = 0; i < 64; i++) {
      if (pixels[i] > mean) {
        hash |= (1 << (63 - i));
      }
    }

    return hash;
  }

  /// Compute Hamming distance between two hashes
  static int hammingDistance(int hash1, int hash2) {
    int xor = hash1 ^ hash2;
    int count = 0;
    while (xor != 0) {
      count += xor & 1;
      xor >>= 1;
    }
    return count;
  }

  /// Returns true if two images are likely duplicates
  static bool isDuplicate(img.Image img1, img.Image img2,
      {double threshold = 10}) {
    final h1 = compute(img1);
    final h2 = compute(img2);
    return hammingDistance(h1, h2) < threshold;
  }

  /// Similarity score 0.0 to 1.0 (1.0 = identical)
  static double similarity(int hash1, int hash2) {
    return 1.0 - (hammingDistance(hash1, hash2) / 64.0);
  }
}
