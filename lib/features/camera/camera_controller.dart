import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:vibration/vibration.dart';
import 'package:image/image.dart' as img;

import '../../app/constants.dart';
import '../../models/edge_result.dart';
import '../../models/scanned_page.dart';
import '../../services/storage_service.dart';
import '../../utils/blur_detector.dart';
import '../../utils/perceptual_hash.dart';
import '../../utils/file_namer.dart';

// ─── State ────────────────────────────────────────────────────────────────

class CameraState {
  final ScanState scanState;
  final List<ScannedPage> capturedPages;
  final EdgeResult? lastEdgeResult;
  final bool isTorchOn;
  final bool isProcessing;
  final String? errorMessage;
  final double stabilityProgress;
  final int? lastHashValue;
  final bool isFlipScanActive;
  final bool shouldNavigateToReview;

  const CameraState({
    this.scanState = ScanState.idle,
    this.capturedPages = const [],
    this.lastEdgeResult,
    this.isTorchOn = false,
    this.isProcessing = false,
    this.errorMessage,
    this.stabilityProgress = 0.0,
    this.lastHashValue,
    this.isFlipScanActive = false,
    this.shouldNavigateToReview = false,
  });

  CameraState copyWith({
    ScanState? scanState,
    List<ScannedPage>? capturedPages,
    EdgeResult? lastEdgeResult,
    bool? isTorchOn,
    bool? isProcessing,
    String? errorMessage,
    double? stabilityProgress,
    int? lastHashValue,
    bool? isFlipScanActive,
    bool? shouldNavigateToReview,
    bool clearError = false,
  }) =>
      CameraState(
        scanState: scanState ?? this.scanState,
        capturedPages: capturedPages ?? this.capturedPages,
        lastEdgeResult: lastEdgeResult ?? this.lastEdgeResult,
        isTorchOn: isTorchOn ?? this.isTorchOn,
        isProcessing: isProcessing ?? this.isProcessing,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        stabilityProgress: stabilityProgress ?? this.stabilityProgress,
        lastHashValue: lastHashValue ?? this.lastHashValue,
        isFlipScanActive: isFlipScanActive ?? this.isFlipScanActive,
        shouldNavigateToReview:
        shouldNavigateToReview ?? this.shouldNavigateToReview,
      );
}

// ─── Providers ────────────────────────────────────────────────────────────

final cameraControllerProvider =
StateNotifierProvider.autoDispose<CameraNotifier, CameraState>(
      (ref) => CameraNotifier(ref),
);

final cameraPluginProvider = StateProvider<CameraController?>((ref) => null);

// ─── Notifier ─────────────────────────────────────────────────────────────

class CameraNotifier extends StateNotifier<CameraState> {
  CameraNotifier(this._ref) : super(const CameraState());

  final Ref _ref;
  CameraController? _cameraController;
  Timer? _flipCooldownTimer;

  // Stream-based analysis fields
  Uint8List? _prevYBytes;       // Previous frame Y-plane for motion diff
  DateTime? _lastFrameTime;     // Throttle timestamp
  bool _streamActive = false;   // Whether image stream is running

  // Per-session counters
  int _stableFrameCount = 0;
  int _motionFrameCount = 0;
  bool _isCapturing = false;
  bool _isFlipScanActive = false;
  final _uuid = const Uuid();

  // ── Initialize Camera ─────────────────────────────────────────────────

  Future<void> initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        state = state.copyWith(
          errorMessage: 'No camera found on this device.',
          scanState: ScanState.error,
        );
        return;
      }

      final backCamera = cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      _ref.read(cameraPluginProvider.notifier).state = _cameraController;
      await _cameraController!.initialize();

      // ── Disable flash immediately and lock it off ──────────────────
      await _cameraController!.setFlashMode(FlashMode.off);

      // ── Auto-start scanning as soon as camera is ready ─────────────
      _isFlipScanActive = true;
      state = state.copyWith(
        scanState: ScanState.detecting,
        isFlipScanActive: true,
        isTorchOn: false,
        clearError: true,
      );
      _startStream();
    } on CameraException catch (e) {
      state = state.copyWith(
        errorMessage: _cameraErrorMessage(e.code),
        scanState: ScanState.error,
      );
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Camera initialization failed: $e',
        scanState: ScanState.error,
      );
    }
  }

  // ── Image Stream ──────────────────────────────────────────────────────

  void _startStream() {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _streamActive ||
        !_isFlipScanActive) return; // don't start if scan already stopped
    _streamActive = true;
    _cameraController!.startImageStream(_onStreamFrame);
  }

  Future<void> _stopStream() async {
    if (!_streamActive) return;
    _streamActive = false;
    try {
      await _cameraController!.stopImageStream();
    } catch (_) {}
  }

  // ── Per-frame Analysis (called by camera plugin on main isolate) ──────

  void _onStreamFrame(CameraImage image) {
    // Skip if capturing or scan not active
    if (_isCapturing || !_isFlipScanActive) return;

    // Throttle: process at most every streamThrottleMs (~10 fps)
    final now = DateTime.now();
    if (_lastFrameTime != null &&
        now.difference(_lastFrameTime!).inMilliseconds <
            AppConstants.streamThrottleMs) return;
    _lastFrameTime = now;

    final currentScan = state.scanState;
    if (currentScan == ScanState.paused ||
        currentScan == ScanState.idle ||
        currentScan == ScanState.capturing) return;

    // Extract Y plane (works for both YUV420 and BGRA/JPEG formats)
    final plane0 = image.planes[0];
    final yBytes = plane0.bytes;
    final rowStride = plane0.bytesPerRow;
    final w = image.width;
    final h = image.height;

    // ── Motion score ──────────────────────────────────────────────────
    final motionScore = _computeMotion(yBytes, rowStride, w, h);

    // ── Blur / sharpness score ────────────────────────────────────────
    final blurScore = _computeBlur(yBytes, rowStride, w, h);
    final isSharp = blurScore >= AppConstants.blurThreshold;

    // Save current frame for next motion diff
    _prevYBytes = Uint8List.fromList(yBytes);

    // Update edge result for overlay (throttled to avoid unnecessary rebuilds)
    state = state.copyWith(
      lastEdgeResult: EdgeResult(
        confidence: isSharp ? 0.75 : 0.25,
        blurScore: blurScore,
        isSharp: isSharp,
        motionScore: motionScore,
      ),
    );

    // ── State machine ─────────────────────────────────────────────────
    _processMetrics(motionScore, blurScore, isSharp, currentScan);
  }

  void _processMetrics(
      double motionScore, double blurScore, bool isSharp, ScanState s) {
    if (!mounted) return;

    switch (s) {
    // ── Monitoring: watching for the NEXT flip ──────────────────────
      case ScanState.monitoring:
        if (motionScore > AppConstants.flipMotionThreshold) {
          _motionFrameCount++;
          if (_motionFrameCount >= AppConstants.flipMotionFramesRequired) {
            _onFlipDetected();
          }
        } else {
          _motionFrameCount = 0;
        }
        break;

    // ── Flipping: cooldown timer is running — just wait ─────────────
      case ScanState.flipping:
        break;

    // ── Detecting / restabilizing: look for stable document ─────────
      case ScanState.detecting:
      case ScanState.restabilizing:
        if (motionScore > AppConstants.motionThreshold) {
          // Camera or subject is moving — reset stability counter
          if (_stableFrameCount > 0 || state.stabilityProgress > 0) {
            _stableFrameCount = 0;
            state = state.copyWith(
              scanState: s,
              stabilityProgress: 0.0,
            );
          }
        } else if (isSharp) {
          // Frame is still and sharp — increment stability counter
          _stableFrameCount++;
          final progress =
          (_stableFrameCount / AppConstants.stableFramesRequired)
              .clamp(0.0, 1.0);
          state = state.copyWith(
            scanState: ScanState.stable,
            stabilityProgress: progress,
          );

          if (_stableFrameCount >= AppConstants.stableFramesRequired &&
              !_isCapturing) {
            // Enough stable frames — capture this page
            _captureFromStream();
          }
        } else {
          // Blurry / no document detected
          if (_stableFrameCount > 0) {
            _stableFrameCount = 0;
            state = state.copyWith(scanState: s, stabilityProgress: 0.0);
          }
        }
        break;

      default:
        break;
    }
  }

  // ── Fast Y-plane Motion Computation ──────────────────────────────────
  // Mean absolute difference between current and previous frame,
  // sampled at every 8th pixel in each direction.

  double _computeMotion(
      Uint8List bytes, int rowStride, int w, int h) {
    if (_prevYBytes == null) return 0.0;
    final prev = _prevYBytes!;

    int diff = 0;
    int count = 0;
    const step = 8;

    for (int y = 0; y < h; y += step) {
      final rowOffset = y * rowStride;
      for (int x = 0; x < w; x += step) {
        final idx = rowOffset + x;
        if (idx >= bytes.length || idx >= prev.length) continue;
        diff += (bytes[idx] - prev[idx]).abs();
        count++;
      }
    }

    if (count == 0) return 0.0;
    // Normalize: diff/count is 0-255, divide by 128 to get 0-2, clamp to 0-1
    return (diff / count / 128.0).clamp(0.0, 1.0);
  }

  // ── Fast Y-plane Blur (Laplacian variance) ────────────────────────────
  // Samples every 4th pixel in each direction for speed.

  double _computeBlur(Uint8List bytes, int rowStride, int w, int h) {
    double sum = 0;
    double sumSq = 0;
    int count = 0;
    const step = 4;

    for (int y = step; y < h - step; y += step) {
      for (int x = step; x < w - step; x += step) {
        final c = bytes[y * rowStride + x].toDouble();
        final top = bytes[(y - 1) * rowStride + x].toDouble();
        final bot = bytes[(y + 1) * rowStride + x].toDouble();
        final lft = bytes[y * rowStride + x - 1].toDouble();
        final rgt = bytes[y * rowStride + x + 1].toDouble();

        final lap = (top + bot + lft + rgt - 4.0 * c).abs();
        sum += lap;
        sumSq += lap * lap;
        count++;
      }
    }

    if (count == 0) return 0.0;
    final mean = sum / count;
    return (sumSq / count) - (mean * mean);
  }

  // ── Flip Detected ─────────────────────────────────────────────────────

  void _onFlipDetected() {
    _motionFrameCount = 0;
    _stableFrameCount = 0;

    state = state.copyWith(
      scanState: ScanState.flipping,
      stabilityProgress: 0.0,
    );

    _flipCooldownTimer?.cancel();
    _flipCooldownTimer = Timer(
      const Duration(milliseconds: AppConstants.flipCooldownMs),
          () {
        if (!mounted) return;
        if (state.scanState == ScanState.flipping) {
          state = state.copyWith(
            scanState: ScanState.restabilizing,
            stabilityProgress: 0.0,
          );
        }
      },
    );
  }

  // ── Capture: stop stream → takePicture → restart stream ───────────────

  Future<void> _captureFromStream() async {
    if (_isCapturing) return;
    _isCapturing = true;
    _stableFrameCount = 0;

    state = state.copyWith(
      scanState: ScanState.capturing,
      isProcessing: true,
    );

    try {
      // Must stop stream before calling takePicture
      await _stopStream();

      // Lock flash off right before taking picture
      await _cameraController!.setFlashMode(FlashMode.off);

      final xFile = await _cameraController!.takePicture();
      final bytes = await File(xFile.path).readAsBytes();
      await File(xFile.path).delete().catchError((_) {});

      await _processCapture(bytes);
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Capture failed: $e',
        scanState: ScanState.detecting,
        isProcessing: false,
      );
    } finally {
      _isCapturing = false;
      // Restart stream analysis
      if (mounted && _isFlipScanActive &&
          _cameraController != null &&
          _cameraController!.value.isInitialized) {
        _prevYBytes = null; // Reset motion baseline after capture
        _startStream();
      }
    }
  }

  /// Manual capture — user presses the white shutter button
  Future<void> manualCapture() async {
    if (_isCapturing || _cameraController == null) return;
    _isCapturing = true;
    state = state.copyWith(scanState: ScanState.capturing, isProcessing: true);

    try {
      await _stopStream();
      await _cameraController!.setFlashMode(FlashMode.off);
      final xFile = await _cameraController!.takePicture();
      final bytes = await File(xFile.path).readAsBytes();
      await File(xFile.path).delete().catchError((_) {});
      await _processCapture(bytes);
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Capture failed: $e',
        scanState: ScanState.monitoring,
        isProcessing: false,
      );
    } finally {
      _isCapturing = false;
      if (mounted && _isFlipScanActive &&
          _cameraController != null &&
          _cameraController!.value.isInitialized) {
        _prevYBytes = null;
        _startStream();
      }
    }
  }

  // ── Process Captured Image ────────────────────────────────────────────

  Future<void> _processCapture(Uint8List bytes) async {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) throw Exception('Could not decode captured image');

      // Blur quality check
      final small400 = img.copyResize(image, width: 400);
      final blurScore = BlurDetector.computeVariance(small400);
      final quality = blurScore >= AppConstants.blurThreshold
          ? PageQuality.good
          : PageQuality.blurry;

      // Duplicate check against last captured page
      if (state.capturedPages.isNotEmpty && state.lastHashValue != null) {
        final small64 = img.copyResize(image, width: 64);
        final newHash = PerceptualHash.compute(small64);
        final distance =
        PerceptualHash.hammingDistance(state.lastHashValue!, newHash);
        if (distance < AppConstants.duplicateHashDistance) {
          // Same page — skip and go to monitoring
          state = state.copyWith(
            scanState: ScanState.monitoring,
            isProcessing: false,
          );
          return;
        }
      }

      // Compute hash for this page
      final small64 = img.copyResize(image, width: 64);
      final hash = PerceptualHash.compute(small64);

      // Save image to disk
      final filename = FileNamer.generateImageFilename();
      await StorageService.instance.init();
      final imagePath = await StorageService.instance.saveImage(
          img.encodeJpg(image, quality: AppConstants.jpegQuality), filename);

      final page = ScannedPage(
        id: _uuid.v4(),
        documentId: '',
        pageNumber: state.capturedPages.length + 1,
        imagePath: imagePath,
        blurScore: blurScore,
        quality: quality,
        createdAt: DateTime.now(),
      );

      // Haptic feedback
      final hasVibrator = await Vibration.hasVibrator();
      if (!mounted) return; // guard: notifier may have been disposed during await
      if (hasVibrator == true) Vibration.vibrate(duration: 60);

      state = state.copyWith(
        capturedPages: [...state.capturedPages, page],
        scanState: ScanState.monitoring, // Wait for next flip
        isProcessing: false,
        lastHashValue: hash,
        stabilityProgress: 0.0,
      );
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Processing failed: $e',
        scanState: ScanState.monitoring,
        isProcessing: false,
      );
    }
  }

  // ── User Controls ─────────────────────────────────────────────────────

  /// User pressed "Done" — stop scan and navigate to review
  void finishScan() {
    _isFlipScanActive = false;
    _stopStream();
    _flipCooldownTimer?.cancel();
    _stableFrameCount = 0;
    _motionFrameCount = 0;
    _prevYBytes = null;

    state = state.copyWith(
      isFlipScanActive: false,
      scanState: ScanState.idle,
      stabilityProgress: 0.0,
      shouldNavigateToReview: true,
    );
  }

  /// Reset navigation flag after screen responds
  void consumeNavigation() {
    state = state.copyWith(shouldNavigateToReview: false);
  }

  void togglePause() {
    if (state.scanState == ScanState.paused) {
      _prevYBytes = null;
      _stableFrameCount = 0;
      _startStream();
      state = state.copyWith(scanState: ScanState.detecting);
    } else {
      _stopStream();
      state = state.copyWith(scanState: ScanState.paused);
    }
  }

  Future<void> toggleTorch() async {
    if (_cameraController == null) return;
    try {
      final newOn = !state.isTorchOn;
      await _cameraController!
          .setFlashMode(newOn ? FlashMode.torch : FlashMode.off);
      state = state.copyWith(isTorchOn: newOn);
    } catch (_) {}
  }

  Future<void> deletePage(int index) async {
    final pages = List<ScannedPage>.from(state.capturedPages);
    final removed = pages.removeAt(index);
    for (int i = 0; i < pages.length; i++) {
      pages[i] = pages[i].copyWith(pageNumber: i + 1);
    }
    state = state.copyWith(
      capturedPages: pages,
      lastHashValue: pages.isEmpty ? null : state.lastHashValue,
    );
    try {
      await StorageService.instance.deleteFile(removed.imagePath);
    } catch (_) {}
  }

  void clearError() {
    state = state.copyWith(clearError: true, scanState: ScanState.detecting);
  }

  // ── Cleanup ───────────────────────────────────────────────────────────

  @override
  void dispose() {
    _isFlipScanActive = false;
    _flipCooldownTimer?.cancel();
    // Clear provider so CameraPreview never tries to use the disposed controller
    try {
      _ref.read(cameraPluginProvider.notifier).state = null;
    } catch (_) {}
    _cameraController?.dispose();
    super.dispose();
  }

  String _cameraErrorMessage(String code) {
    switch (code) {
      case 'cameraPermission':
        return 'Camera permission denied. Please allow access in Settings.';
      case 'CameraAccessDenied':
        return 'Camera access denied. Please check app permissions.';
      default:
        return 'Camera error: $code';
    }
  }
}