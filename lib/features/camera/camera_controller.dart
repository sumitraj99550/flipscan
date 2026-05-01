import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
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
import '../../repositories/settings_repository.dart';

// ─── State ────────────────────────────────────────────────────────────────

class CameraState {
  final ScanState scanState;
  final List<ScannedPage> capturedPages;
  final EdgeResult? lastEdgeResult;
  final bool isTorchOn;
  final bool isProcessing;
  final String? errorMessage;
  final double stabilityProgress; // 0.0 to 1.0
  final int? lastHashValue;

  const CameraState({
    this.scanState = ScanState.idle,
    this.capturedPages = const [],
    this.lastEdgeResult,
    this.isTorchOn = false,
    this.isProcessing = false,
    this.errorMessage,
    this.stabilityProgress = 0.0,
    this.lastHashValue,
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
  Timer? _stabilityTimer;
  Timer? _flipCooldownTimer;

  int _stableFrameCount = 0;
  bool _isCapturing = false;
  bool _isFlipping = false;
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

      state = state.copyWith(scanState: ScanState.detecting, clearError: true);

      if (SettingsRepository.instance.autoCaptureEnabled) {
        _startFrameAnalysis();
      }
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

  // ── Frame Analysis Loop ───────────────────────────────────────────────

  void _startFrameAnalysis() {
    _frameTimer?.cancel();
    _frameTimer = Timer.periodic(
      const Duration(milliseconds: AppConstants.frameAnalysisIntervalMs),
      (_) => _analyzeFrame(),
    );
  }

  Future<void> _analyzeFrame() async {
    if (_isCapturing ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized ||
        state.scanState == ScanState.paused ||
        state.scanState == ScanState.capturing) {
      return;
    }

    try {
      final xFile = await _cameraController!.takePicture();
      final bytes = await File(xFile.path).readAsBytes();

      // Run analysis in isolate to avoid jank
      final result = await _analyzeInIsolate(bytes, _lastFrameBytes);

      if (!mounted) return;

      // Motion detection
      if (result['motionScore'] > 0.15) {
        _onMotionDetected();
        _lastFrameBytes = bytes;
        return;
      }

      _lastFrameBytes = bytes;

      final edgeResult = EdgeResult(
        confidence: result['confidence'] ?? 0.0,
        blurScore: result['blurScore'] ?? 0.0,
        isSharp: result['isSharp'] ?? false,
        motionScore: result['motionScore'] ?? 0.0,
      );

      state = state.copyWith(lastEdgeResult: edgeResult);

      // Stability tracking
      if (edgeResult.isSharp && edgeResult.confidence > AppConstants.edgeConfidenceThreshold) {
        _stableFrameCount++;
        final progress = (_stableFrameCount / 4).clamp(0.0, 1.0);
        state = state.copyWith(
          scanState: ScanState.stable,
          stabilityProgress: progress,
        );

        if (_stableFrameCount >= 4 && !_isCapturing &&
            SettingsRepository.instance.autoCaptureEnabled) {
          await _triggerAutoCapture(bytes);
        }
      } else {
        _stableFrameCount = 0;
        state = state.copyWith(
          scanState: ScanState.detecting,
          stabilityProgress: 0.0,
        );
      }

      // Cleanup temp file
      await File(xFile.path).delete();
    } catch (_) {
      // Silently ignore frame analysis errors — never crash on frame
    }
  }

  static Future<Map<String, dynamic>> _analyzeInIsolate(
    Uint8List currentBytes,
    Uint8List? previousBytes,
  ) async {
    return await Isolate.run(() async {
      final current = img.decodeImage(currentBytes);
      if (current == null) {
        return {'confidence': 0.0, 'blurScore': 0.0, 'isSharp': false, 'motionScore': 0.0};
      }

      // Downscale for analysis
      final small = img.copyResize(current, width: 320);
      final blurScore = BlurDetector.computeVariance(small);
      final isSharp = blurScore >= AppConstants.blurThreshold;

      // Simple edge confidence: estimate from blur score + brightness
      final gray = img.grayscale(small);
      double edgePixels = 0;
      final totalPixels = gray.width * gray.height;
      for (int y = 1; y < gray.height - 1; y++) {
        for (int x = 1; x < gray.width - 1; x++) {
          final center = gray.getPixel(x, y).luminance;
          final right = gray.getPixel(x + 1, y).luminance;
          final bottom = gray.getPixel(x, y + 1).luminance;
          final grad = ((center - right).abs() + (center - bottom).abs());
          if (grad > 0.05) edgePixels++;
        }
      }
      final confidence = (edgePixels / totalPixels * 10).clamp(0.0, 1.0);

      // Motion score via frame difference
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
          motionScore = count > 0 ? (diff / count * 5).clamp(0.0, 1.0) : 0.0;
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

  void _onMotionDetected() {
    if (!_isFlipping) {
      _isFlipping = true;
      _stableFrameCount = 0;
      state = state.copyWith(
        scanState: ScanState.flipping,
        stabilityProgress: 0.0,
      );
    }

    _flipCooldownTimer?.cancel();
    _flipCooldownTimer = Timer(
      const Duration(milliseconds: AppConstants.flipCooldownMs),
      () {
        _isFlipping = false;
        if (state.scanState == ScanState.flipping) {
          state = state.copyWith(scanState: ScanState.detecting);
        }
      },
    );
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
        scanState: ScanState.detecting,
        isProcessing: false,
      );
    } finally {
      _isCapturing = false;
    }
  }

  /// Manual capture — user pressed button
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
      await File(xFile.path).delete();
      await _processCapture(bytes);
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Capture failed: $e',
        scanState: ScanState.detecting,
        isProcessing: false,
      );
    } finally {
      _isCapturing = false;
    }
  }

  Future<void> _processCapture(Uint8List bytes) async {
    try {
      // Decode image
      final image = img.decodeImage(bytes);
      if (image == null) throw Exception('Could not decode captured image');

      // Blur check
      final blurScore = BlurDetector.computeVariance(
          img.copyResize(image, width: 400));
      final quality =
          blurScore >= AppConstants.blurThreshold ? PageQuality.good : PageQuality.blurry;

      // Duplicate check
      if (state.capturedPages.isNotEmpty && state.lastHashValue != null) {
        final newHash = PerceptualHash.compute(
            img.copyResize(image, width: 64));
        final distance = PerceptualHash.hammingDistance(
            state.lastHashValue!, newHash);
        if (distance < AppConstants.duplicateHashDistance) {
          // Skip duplicate
          state = state.copyWith(
            scanState: ScanState.detecting,
            isProcessing: false,
          );
          return;
        }
      }

      // Compute hash for next comparison
      final hash = PerceptualHash.compute(img.copyResize(image, width: 64));

      // Save image
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
      if (SettingsRepository.instance.vibrationEnabled) {
        final hasVibrator = await Vibration.hasVibrator();
        if (hasVibrator) Vibration.vibrate(duration: 60);
      }

      state = state.copyWith(
        capturedPages: updatedPages,
        scanState: ScanState.detecting,
        isProcessing: false,
        lastHashValue: hash,
        stabilityProgress: 0.0,
      );
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Processing failed: $e',
        scanState: ScanState.detecting,
        isProcessing: false,
      );
    }
  }

  // ── Controls ──────────────────────────────────────────────────────────

  Future<void> toggleTorch() async {
    if (_cameraController == null) return;
    try {
      final newState = !state.isTorchOn;
      await _cameraController!.setFlashMode(
          newState ? FlashMode.torch : FlashMode.off);
      state = state.copyWith(isTorchOn: newState);
    } catch (_) {}
  }

  void togglePause() {
    if (state.scanState == ScanState.paused) {
      _startFrameAnalysis();
      state = state.copyWith(scanState: ScanState.detecting);
    } else {
      _frameTimer?.cancel();
      state = state.copyWith(scanState: ScanState.paused);
    }
  }

  Future<void> deletePage(int index) async {
    final pages = List<ScannedPage>.from(state.capturedPages);
    final removedPage = pages.removeAt(index);
    // Re-number
    for (int i = 0; i < pages.length; i++) {
      pages[i] = pages[i].copyWith(pageNumber: i + 1);
    }
    state = state.copyWith(capturedPages: pages);
    try {
      await StorageService.instance.deleteFile(removedPage.imagePath);
    } catch (_) {
      // Ignore cleanup errors for temporary capture files.
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true, scanState: ScanState.detecting);
  }

  // ── Cleanup ───────────────────────────────────────────────────────────

  @override
  void dispose() {
    _frameTimer?.cancel();
    _stabilityTimer?.cancel();
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
