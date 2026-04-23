class AppConstants {
  // Capture thresholds
  static const double blurThreshold = 80.0;
  static const double edgeConfidenceThreshold = 0.65;
  static const double motionThreshold = 0.05;
  static const double duplicateHashDistance = 10.0;
  static const double minPageAreaRatio = 0.25;

  // Timing
  static const int stableWindowMs = 400;
  static const int flipCooldownMs = 600;
  static const int frameAnalysisIntervalMs = 125; // 8fps

  // Image settings
  static const int analysisResolutionWidth = 480;
  static const int jpegQuality = 85;
  static const int thumbnailSize = 200;

  // Storage
  static const String documentsFolder = 'FlipScan';
  static const String dbName = 'flipscan.db';
  static const int dbVersion = 1;
  static const int maxInMemoryPages = 20;

  // PDF
  static const double pdfPageWidth = 595.0; // A4 points
  static const double pdfPageHeight = 842.0;

  // App info
  static const String appName = 'FlipScan AI';
  static const String appVersion = '1.0.0';
  static const String privacyMessage =
      'Your documents are processed entirely on your device and never leave it. '
      'No internet connection required.';
}
