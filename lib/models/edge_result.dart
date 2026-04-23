import 'package:flutter/material.dart';

// Edge detection result from OpenCV
class EdgeResult {
  final List<Offset>? quad; // 4 corner points normalized 0..1
  final double confidence; // 0.0 to 1.0
  final double blurScore;
  final bool isSharp;
  final double motionScore;

  const EdgeResult({
    this.quad,
    required this.confidence,
    required this.blurScore,
    required this.isSharp,
    this.motionScore = 0.0,
  });

  bool get hasEdge => quad != null && confidence > 0.65;

  static EdgeResult empty() => const EdgeResult(
        confidence: 0,
        blurScore: 0,
        isSharp: false,
        motionScore: 0,
      );
}

// Scanning session state
enum ScanState {
  idle,
  detecting,
  stable,
  capturing,
  flipping,
  paused,
  error,
}

class ScanSession {
  final String sessionId;
  final DateTime startedAt;
  List<String> capturedImagePaths;
  ScanState state;
  int frameCount;
  int captureCount;

  ScanSession({
    required this.sessionId,
    required this.startedAt,
    List<String>? capturedImagePaths,
    this.state = ScanState.idle,
    this.frameCount = 0,
    this.captureCount = 0,
  }) : capturedImagePaths = capturedImagePaths ?? [];
}
