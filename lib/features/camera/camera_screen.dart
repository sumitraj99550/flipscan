import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app/theme.dart';
import '../../models/edge_result.dart';
import 'camera_controller.dart';
import 'edge_overlay.dart';
import 'thumbnail_strip.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _captureAnimController;
  ScanState? _prevScanState;

  @override
  void initState() {
    super.initState();
    _captureAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _initCamera());
  }

  @override
  void dispose() {
    _captureAnimController.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Camera permission is required to scan documents.')),
      );
      return;
    }
    // initCamera() now auto-starts detection immediately
    await ref.read(cameraControllerProvider.notifier).initCamera();
  }

  @override
  Widget build(BuildContext context) {
    final cameraState = ref.watch(cameraControllerProvider);
    final cameraPlugin = ref.watch(cameraPluginProvider);

    // ── Navigate to review when user presses Done ──────────────────
    ref.listen<CameraState>(cameraControllerProvider, (prev, next) {
      if (next.shouldNavigateToReview && mounted) {
        ref.read(cameraControllerProvider.notifier).consumeNavigation();
        if (next.capturedPages.isEmpty) {
          // No pages captured — just pop back
          context.pop();
        } else {
          context.push('/review', extra: next.capturedPages);
        }
      }
    });

    // Capture flash animation
    if (_prevScanState != cameraState.scanState) {
      if (cameraState.scanState == ScanState.capturing) {
        _captureAnimController.forward(from: 0);
      }
      _prevScanState = cameraState.scanState;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Camera Preview ─────────────────────────────────────────
          Positioned.fill(
            child: (cameraPlugin != null && cameraPlugin.value.isInitialized)
                ? CameraPreview(cameraPlugin)
                : const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text('Starting camera…',
                      style: TextStyle(color: Colors.white54)),
                ],
              ),
            ),
          ),

          // ── Edge / Scan Overlay ─────────────────────────────────────
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: EdgeOverlayPainter(
                  scanState: cameraState.scanState,
                  stabilityProgress: cameraState.stabilityProgress,
                ),
              ),
            ),
          ),

          // ── Capture Flash ───────────────────────────────────────────
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _captureAnimController,
                builder: (_, __) => Opacity(
                  opacity: (1 - _captureAnimController.value) * 0.55,
                  child: _captureAnimController.value > 0
                      ? Container(color: Colors.white)
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ),

          // ── Top Bar ─────────────────────────────────────────────────
          Positioned(
            top: 48,
            left: 16,
            right: 16,
            child: Row(
              children: [
                _CircleButton(
                  icon: Icons.arrow_back,
                  onTap: () {
                    ref.read(cameraControllerProvider.notifier).finishScan();
                  },
                ),
                const Spacer(),
                _StateBadge(scanState: cameraState.scanState),
                const SizedBox(width: 8),
                _CountBadge(count: cameraState.capturedPages.length),
                const SizedBox(width: 8),
                // Video Mode
                _CircleButton(
                  icon: Icons.videocam,
                  onTap: () => context.push('/video-scan'),
                ),
              ],
            ),
          ),

          // ── Status banners ──────────────────────────────────────────
          if (cameraState.scanState == ScanState.detecting ||
              cameraState.scanState == ScanState.restabilizing)
            Positioned(
              top: 112,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.document_scanner,
                          color: Colors.white70, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        cameraState.scanState == ScanState.detecting
                            ? 'Point camera at a document…'
                            : 'New page settling…',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (cameraState.scanState == ScanState.stable)
            Positioned(
              top: 112,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade700.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      const Text('Document detected — capturing…',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 60,
                        height: 6,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: cameraState.stabilityProgress,
                            backgroundColor: Colors.white30,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (cameraState.scanState == ScanState.monitoring)
            Positioned(
              top: 112,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade700.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.flip, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text('Watching for next page flip…',
                          style: TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),

          if (cameraState.scanState == ScanState.flipping)
            Positioned(
              top: 112,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade700.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.swap_horiz, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text('Page flip detected!',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),

          // ── Error Banner ─────────────────────────────────────────────
          if (cameraState.errorMessage != null)
            Positioned(
              top: 112,
              left: 16,
              right: 16,
              child: Material(
                color: Colors.red.shade800.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(cameraState.errorMessage!,
                            style: const TextStyle(color: Colors.white)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: ref
                            .read(cameraControllerProvider.notifier)
                            .clearError,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Bottom Controls ──────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black,
                    Colors.black.withValues(alpha: 0.85),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.65, 1.0],
                ),
              ),
              padding: const EdgeInsets.only(top: 10, bottom: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Thumbnail strip
                  ThumbnailStrip(
                    pages: cameraState.capturedPages,
                    onPageDelete:
                    ref.read(cameraControllerProvider.notifier).deletePage,
                  ),
                  const SizedBox(height: 10),

                  // Controls row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Torch
                      _CircleButton(
                        icon: cameraState.isTorchOn
                            ? Icons.flash_on
                            : Icons.flash_off,
                        onTap: ref
                            .read(cameraControllerProvider.notifier)
                            .toggleTorch,
                      ),

                      // Manual capture (big centre button)
                      _ManualCaptureButton(
                        isProcessing: cameraState.isProcessing,
                        onTap: ref
                            .read(cameraControllerProvider.notifier)
                            .manualCapture,
                      ),

                      // Pause / Resume
                      _CircleButton(
                        icon: cameraState.scanState == ScanState.paused
                            ? Icons.play_arrow
                            : Icons.pause,
                        onTap: ref
                            .read(cameraControllerProvider.notifier)
                            .togglePause,
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Done — navigate to review
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: FilledButton.icon(
                      onPressed: () {
                        ref
                            .read(cameraControllerProvider.notifier)
                            .finishScan();
                      },
                      icon: cameraState.capturedPages.isEmpty
                          ? const Icon(Icons.arrow_back)
                          : const Icon(Icons.check_circle_outline),
                      label: Text(
                        cameraState.capturedPages.isEmpty
                            ? 'Back'
                            : 'Done  •  Review ${cameraState.capturedPages.length} page${cameraState.capturedPages.length == 1 ? '' : 's'}',
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: cameraState.capturedPages.isEmpty
                            ? Colors.grey.shade700
                            : AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Manual Capture Button ──────────────────────────────────────────────────

class _ManualCaptureButton extends StatelessWidget {
  const _ManualCaptureButton(
      {required this.isProcessing, required this.onTap});
  final bool isProcessing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isProcessing ? null : onTap,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isProcessing ? Colors.grey : Colors.white,
          border: Border.all(
              color: isProcessing ? Colors.grey.shade700 : Colors.white60,
              width: 3),
          boxShadow: isProcessing
              ? []
              : [
            BoxShadow(
                color: Colors.white.withValues(alpha: 0.3),
                blurRadius: 12,
                spreadRadius: 2)
          ],
        ),
        child: isProcessing
            ? const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child:
            CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
          ),
        )
            : const Icon(Icons.camera_alt, color: Colors.black, size: 30),
      ),
    );
  }
}

// ─── Helpers ────────────────────────────────────────────────────────────────

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.5),
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon,
            color: onTap == null ? Colors.white38 : Colors.white, size: 22),
      ),
    );
  }
}

class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.scanState});
  final ScanState scanState;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _info(scanState);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  (String, Color) _info(ScanState s) {
    switch (s) {
      case ScanState.idle:
        return ('Idle', Colors.blueGrey);
      case ScanState.detecting:
        return ('Detecting', Colors.blueGrey.shade600);
      case ScanState.stable:
        return ('Stable ✓', Colors.green.shade700);
      case ScanState.capturing:
        return ('Capturing!', Colors.teal.shade700);
      case ScanState.monitoring:
        return ('Watching', Colors.indigo.shade500);
      case ScanState.flipping:
        return ('Flip!', Colors.orange.shade700);
      case ScanState.restabilizing:
        return ('Settling…', Colors.amber.shade700);
      case ScanState.paused:
        return ('Paused', Colors.grey.shade600);
      case ScanState.recording:
        return ('Recording', Colors.red.shade700);
      case ScanState.analyzing:
        return ('Analysing', Colors.purple.shade600);
      case ScanState.error:
        return ('Error', Colors.red.shade800);
    }
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Text('$count page${count == 1 ? '' : 's'}',
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }
}