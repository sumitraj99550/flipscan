class AppConstants {
  // ── Capture thresholds ────────────────────────────────────────────────
  // Note: blurThreshold is calibrated for stream Y-plane Laplacian variance
  static const double blurThreshold = 60.0;
  static const double edgeConfidenceThreshold = 0.50;
  // Motion thresholds (normalized 0–1, stream Y-plane MAD / 128)
  static const double motionThreshold = 0.06;      // below = camera is still
  static const double flipMotionThreshold = 0.14;  // above = flip happening
  static const double duplicateHashDistance = 8.0;
  static const double motionAmplifier = 4.5;       // kept for legacy use

  // ── Flip detection ────────────────────────────────────────────────────
  /// Consecutive frames above flipMotionThreshold before declaring a flip
  static const int flipMotionFramesRequired = 2;

  // ── Stability ─────────────────────────────────────────────────────────
  /// Consecutive still+sharp frames needed before auto-capture fires
  static const int stableFramesRequired = 3;

  // ── Stream analysis ───────────────────────────────────────────────────
  /// Minimum ms between stream frame analyses (~10 fps)
  static const int streamThrottleMs = 100;
  /// Flip cooldown after a flip is declared (ms)
  static const int flipCooldownMs = 600;

  // ── Image / capture settings ──────────────────────────────────────────
  static const int jpegQuality = 88;
  static const int thumbnailSize = 200;

  // ── Video scan ────────────────────────────────────────────────────────
  /// Extract one frame every N ms from recorded video (~3 fps)
  static const int videoFrameIntervalMs = 300;
  /// Max hash-bit difference for "same page" (0–64)
  /// 12 = tolerates slight tilt / lighting variation within same page
  static const int videoPageGroupThreshold = 12;
  /// Min frames in a group to be counted as a real page
  static const int videoMinGroupSize = 1;

  // ── Storage ───────────────────────────────────────────────────────────
  static const String documentsFolder = 'FlipScan';
  static const String dbName = 'flipscan.db';
  static const int dbVersion = 1;

  // ── PDF ───────────────────────────────────────────────────────────────
  static const double pdfPageWidth = 595.0;
  static const double pdfPageHeight = 842.0;

  // ── App info ──────────────────────────────────────────────────────────
  static const String appName = 'FlipScan AI';
  static const String appVersion = '1.0.0';
  static const String privacyMessage =
      'Your documents are processed entirely on your device and never leave it.';
}