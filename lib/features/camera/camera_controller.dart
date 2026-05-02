import 'dart:async';
import 'dart:io';
import 'dart:isolate';
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
  Timer? _frameTimer;
  Timer? _flipCooldownTimer;

  int _stableFrameCount = 0;
  int _motionFrameCount = 0;   // consecutive high-motion frames (flip detector)
  bool _isCapturing = false;
  bool _isAnalyzing = false;
  bool _isFlipScanActive = false;
  Uint8List? _lastFrameBytes;
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
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      _ref.read(cameraPluginProvider.notifier).state = _cameraController;
      await _cameraController!.initialize();

      // Camera is ready — show preview, wait for user to press Start
      state = state.copyWith(scanState: ScanState.idle, clearError: true);
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

  // ── Flip Scan Session Control ─────────────────────────────────────────

  /// User pressed "Start Flip Scan" — begin auto-detect-and-capture loop.
  void startFlipScan() {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized) return;
    _isFlipScanActive = true;
    _stableFrameCount = 0;
    _motionFrameCount = 0;
    state = state.copyWith(
      isFlipScanActive: true,
      scanState: ScanState.detecting,
      stabilityProgress: 0.0,
    );
    _startFrameAnalysis();
  }

  /// User pressed "Stop" — ends the flip scan session.
  void stopFlipScan() {
    _isFlipScanActive = false;
    _frameTimer?.cancel();
    _flipCooldownTimer?.cancel();
    _stableFrameCount = 0;
    _motionFrameCount = 0;
    state = state.copyWith(
      isFlipScanActive: false,
      scanState: ScanState.idle,
      stabilityProgress: 0.0,
    );
  }

  // ── Frame Analysis Loop ───────────────────────────────────────────────

  void _startFrameAnalysis() {
    _frameTimer?.cancel();
    _frameTimer = Timer.periodic(
      const Duration(milliseconds: AppConstants.frameAnalysisIntervalMs),
      (_) => _analyzeFrame(),
    );
  }

  Future<void> _analyzeFrame() async {
    // Guard: skip if busy or not in a scanning state
    if (_isAnalyzing ||
        _isCapturing ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized ||
        state.scanState == ScanState.paused ||
        state.scanState == ScanState.capturing ||
        state.scanState == ScanState.idle) {
      return;
    }

    _isAnalyzing = true;
    try {
      final xFile = await _cameraController!.takePicture();
      final bytes = await File(xFile.path).readAsBytes();
      await File(xFile.path).delete().catchError((_) {});

      // Run heavy work in isolate so UI stays smooth
      final result = await _analyzeInIsolate(bytes, _lastFrameBytes);
      if (!mounted) return;

      final motionScore = result['motionScore'] as double;
      final blurScore = result['blurScore'] as double;
      final isSharp = result['isSharp'] as bool;
      final confidence = result['confidence'] as double;

      final edgeResult = EdgeResult(
        confidence: confidence,
        blurScore: blurScore,
        isSharp: isSharp,
        motionScore: motionScore,
      );
      state = state.copyWith(lastEdgeResult: edgeResult);

      final currentState = state.scanState;

      // ── State: monitoring — watch for flip motion ─────────────────
      if (currentState == ScanState.monitoring) {
        if (motionScore > AppConstants.flipMotionThreshold) {
          _motionFrameCount++;
          // Require at least 2 consecutive motion frames to avoid false triggers
          if (_motionFrameCount >= AppConstants.flipMotionFramesRequired) {
            _onFlipDetected();
          }
        } else {
          _motionFrameCount = 0;
        }
        _lastFrameBytes = bytes;
        return;
      }

      // ── State: flipping — wait for cooldown timer (set in _onFlipDetected)
      if (currentState == ScanState.flipping) {
        _lastFrameBytes = bytes;
        return;
      }

      // ── States: detecting / restabilizing — look for stable page ─────
      if (currentState == ScanState.detecting ||
          currentState == ScanState.restabilizing) {
        // High motion: page still moving or camera shake — reset
        if (motionScore > AppConstants.motionThreshold) {
          _stableFrameCount = 0;
          state = state.copyWith(
            stabilityProgress: 0.0,
            // Stay in current detecting/restabilizing state
          );
          _lastFrameBytes = bytes;
          return;
        }

        // Frame is sharp and has good edge confidence
        if (isSharp && confidence > AppConstants.edgeConfidenceThreshold) {
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
            await _triggerAutoCapture(bytes);
          }
        } else {
          // Frame blurry or no document detected
          _stableFrameCount = 0;
          state = state.copyWith(
            scanState: currentState, // stay in detecting/restabilizing
            stabilityProgress: 0.0,
          );
        }

        _lastFrameBytes = bytes;
      }
    } catch (_) {
      // Never crash frame analysis — silently skip bad frames
    } finally {
      _isAnalyzing = false;
    }
  }

  // ── Flip Detection ────────────────────────────────────────────────────

  void _onFlipDetected() {
    _motionFrameCount = 0;
    _stableFrameCount = 0;

    state = state.copyWith(
      scanState: ScanState.flipping,
      stabilityProgress: 0.0,
    );

    // After the flip cooldown, transition to restabilizing so we look
    // for the new page
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

  // ── Isolate Analysis ──────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _analyzeInIsolate(
    Uint8List currentBytes,
    Uint8List? previousBytes,
  ) async {
    return await Isolate.run(() async {
      final current = img.decodeImage(currentBytes);
      if (current == null) {
        return {
          'confidence': 0.0,
          'blurScore': 0.0,
          'isSharp': false,
          'motionScore': 0.0,
        };
      }

      // Downscale for fast analysis
      final small = img.copyResize(current, width: 320);
      final blurScore = BlurDetector.computeVariance(small);
      final isSharp = blurScore >= AppConstants.blurThreshold;

      // Edge confidence: ratio of high-gradient pixels
      final gray = img.grayscale(small);
      double edgePixels = 0;
      final totalPixels = gray.width * gray.height;
      for (int y = 1; y < gray.height - 1; y++) {
        for (int x = 1; x < gray.width - 1; x++) {
          final center = gray.getPixel(x, y).luminance;
          final right = gray.getPixel(x + 1, y).luminance;
          final bottom = gray.getPixel(x, y + 1).luminance;
          final grad = (center - right).abs() + (center - bottom).abs();
          if (grad > 0.05) edgePixels++;
        }
      }
      final confidence = (edgePixels / totalPixels * 10).clamp(0.0, 1.0);

      // Motion score: mean absolute difference with previous frame
      double motionScore = 0.0;
      if (previousBytes != null) {
        final previous = img.decodeImage(previousBytes);
        if (previous != null) {
          final prevSmall = img.copyResize(previous, width: 160, height: 120);
          final currSmall = img.copyResize(current, width: 160, height: 120);
          double diff = 0;
          int count = 0;
          for (int y = 0; y < prevSmall.height; y++) {
            for (int x = 0; x < prevSmall.width; x++) {
              final p1 = prevSmall.getPixel(x, y).luminance;
              final p2 = currSmall.getPixel(x, y).luminance;
              diff += (p1 - p2).abs();
              count++;
            }
          }
          motionScore = count > 0
              ? (diff / count * AppConstants.motionAmplifier).clamp(0.0, 1.0)
              : 0.0;
        }
      }

      return {
        'confidence': confidence,
        'blurScore': blurScore,
        'isSharp': isSharp,
        'motionScore': motionScore,
      };
    });
  }

  // ── Capture Logic ─────────────────────────────────────────────────────

  Future<void> _triggerAutoCapture(Uint8List frameBytes) async {
    if (_isCapturing) return;
    _isCapturing = true;
    _stableFrameCount = 0;

    state = state.copyWith(
      scanState: ScanState.capturing,
      isProcessing: true,
    );

    try {
      await _processCapture(frameBytes);
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Capture failed: $e',
        scanState: _isFlipScanActive ? ScanState.detecting : ScanState.idle,
        isProcessing: false,
      );
    } finally {
      _isCapturing = false;
    }
  }

  /// Manual capture — user pressed camera button (works in any mode)
  Future<void> manualCapture() async {
    if (_isCapturing || _cameraController == null) return;
    _isCapturing = true;

    state = state.copyWith(
      scanState: ScanState.capturing,
      isProcessing: true,
    );

    try {
      final xFile = await _cameraController!.takePicture();
      final bytes = await File(xFile.path).readAsBytes();
      await File(xFile.path).delete().catchError((_) {});
      await _processCapture(bytes);
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Capture failed: $e',
        scanState: _isFlipScanActive ? ScanState.monitoring : ScanState.idle,
        isProcessing: false,
      );
    } finally {
      _isCapturing = false;
    }
  }

  Future<void> _processCapture(Uint8List bytes) async {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) throw Exception('Could not decode captured image');

      // Quality check
      final small400 = img.copyResize(image, width: 400);
      final blurScore = BlurDetector.computeVariance(small400);
      final quality =
          blurScore >= AppConstants.blurThreshold ? PageQuality.good : PageQuality.blurry;

      // Duplicate check — compare with last captured page hash
      if (state.capturedPages.isNotEmpty && state.lastHashValue != null) {
        final small64 = img.copyResize(image, width: 64);
        final newHash = PerceptualHash.compute(small64);
        final distance =
            PerceptualHash.hammingDistance(state.lastHashValue!, newHash);
        if (distance < AppConstants.duplicateHashDistance) {
          // Same page — skip and go back to monitoring
          state = state.copyWith(
            scanState: _isFlipScanActive ? ScanState.monitoring : ScanState.idle,
            isProcessing: false,
          );
          return;
        }
      }

      // Compute hash for this page
      final small64 = img.copyResize(image, width: 64);
      final hash = PerceptualHash.compute(small64);

      final pageNumber = state.capturedPages.length + 1;
      final filename = FileNamer.generateImageFilename();
      await StorageService.instance.init();
      final imagePath = await StorageService.instance.saveImage(
          img.encodeJpg(image, quality: AppConstants.jpegQuality), filename);

      final page = ScannedPage(
        id: _uuid.v4(),
        documentId: '',
        pageNumber: pageNumber,
        imagePath: imagePath,
        blurScore: blurScore,
        quality: quality,
        createdAt: DateTime.now(),
      );

      final updatedPages = [...state.capturedPages, page];

      // Haptic feedback
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) Vibration.vibrate(duration: 60);

      // After capture: if flip scan active → monitoring (watch for next flip)
      //                otherwise         → idle
      final nextState =
          _isFlipScanActive ? ScanState.monitoring : ScanState.idle;

      state = state.copyWith(
        capturedPages: updatedPages,
        scanState: nextState,
        isProcessing: false,
        lastHashValue: hash,
        stabilityProgress: 0.0,
      );
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Processing failed: $e',
        scanState: _isFlipScanActive ? ScanState.monitoring : ScanState.idle,
        isProcessing: false,
      );
    }
  }

  // ── Controls ──────────────────────────────────────────────────────────

  Future<void> toggleTorch() async {
    if (_cameraController == null) return;
    try {
      final newState = !state.isTorchOn;
      await _cameraController!
          .setFlashMode(newState ? FlashMode.torch : FlashMode.off);
      state = state.copyWith(isTorchOn: newState);
    } catch (_) {}
  }

  void togglePause() {
    if (state.scanState == ScanState.paused) {
      if (_isFlipScanActive) {
        _startFrameAnalysis();
        state = state.copyWith(scanState: ScanState.detecting);
      } else {
        state = state.copyWith(scanState: ScanState.idle);
      }
    } else {
      _frameTimer?.cancel();
      state = state.copyWith(scanState: ScanState.paused);
    }
  }

  Future<void> deletePage(int index) async {
    final pages = List<ScannedPage>.from(state.capturedPages);
    final removedPage = pages.removeAt(index);
    for (int i = 0; i < pages.length; i++) {
      pages[i] = pages[i].copyWith(pageNumber: i + 1);
    }
    // Reset last hash so next detection works cleanly
    final newLastHash = pages.isNotEmpty ? null : state.lastHashValue;
    state = state.copyWith(capturedPages: pages, lastHashValue: newLastHash);
    try {
      await StorageService.instance.deleteFile(removedPage.imagePath);
    } catch (_) {}
  }

  void clearError() {
    state = state.copyWith(
        clearError: true,
        scanState: _isFlipScanActive ? ScanState.detecting : ScanState.idle);
  }

  // ── Cleanup ───────────────────────────────────────────────────────────

  @override
  void dispose() {
    _frameTimer?.cancel();
    _flipCooldownTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────

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
