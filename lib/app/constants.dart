class AppConstants {
  // ── Capture thresholds ────────────────────────────────────────────────
  static const double blurThreshold = 80.0;
  static const double edgeConfidenceThreshold = 0.60; // slightly relaxed
  static const double motionThreshold = 0.08;         // below = considered still
  static const double duplicateHashDistance = 10.0;
  static const double minPageAreaRatio = 0.25;

  // ── Flip detection ────────────────────────────────────────────────────
  /// Motion score above this value = "significant motion" (flip candidate)
  static const double flipMotionThreshold = 0.18;
  /// Consecutive high-motion frames before declaring a flip
  static const int flipMotionFramesRequired = 2;
  /// Amplifier applied to raw frame-diff score (tuning)
  static const double motionAmplifier = 5.0;

  // ── Stability ─────────────────────────────────────────────────────────
  /// Frames that must be stable before auto-capture fires
  static const int stableFramesRequired = 4;

  // ── Timing ────────────────────────────────────────────────────────────
  static const int flipCooldownMs = 700;
  static const int frameAnalysisIntervalMs = 150; // ~6.5 fps effective

  // ── Image settings ────────────────────────────────────────────────────
  static const int analysisResolutionWidth = 480;
  static const int jpegQuality = 88;
  static const int thumbnailSize = 200;

  // ── Video scan ────────────────────────────────────────────────────────
  /// Extract one frame every N milliseconds from recorded video
  static const int videoFrameIntervalMs = 500; // 2 fps
  /// Hash distance threshold for "same page" grouping (0-64)
  static const int videoPageGroupThreshold = 15;
  /// Minimum frames in a group to count as a real page (filters blur/motion)
  static const int videoMinGroupSize = 2;

  // ── Storage ───────────────────────────────────────────────────────────
  static const String documentsFolder = 'FlipScan';
  static const String dbName = 'flipscan.db';
  static const int dbVersion = 1;
  static const int maxInMemoryPages = 20;

  // ── PDF ───────────────────────────────────────────────────────────────
  static const double pdfPageWidth = 595.0; // A4 points
  static const double pdfPageHeight = 842.0;

  // ── App info ──────────────────────────────────────────────────────────
  static const String appName = 'FlipScan AI';
  static const String appVersion = '1.0.0';
  static const String privacyMessage =
      'Your documents are processed entirely on your device and never leave it. '
      'No internet connection required.';
}
