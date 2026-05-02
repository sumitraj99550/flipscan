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
      duration: const Duration(milliseconds: 300),
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
    await ref.read(cameraControllerProvider.notifier).initCamera();
  }

  @override
  Widget build(BuildContext context) {
    final cameraState = ref.watch(cameraControllerProvider);
    final cameraPlugin = ref.watch(cameraPluginProvider);

    // Animate flash on capture
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
                        Text('Initializing camera…',
                            style: TextStyle(color: Colors.white54)),
                      ],
                    ),
                  ),
          ),

          // ── Edge / Scan Overlay ────────────────────────────────────
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

          // ── Capture Flash ──────────────────────────────────────────
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _captureAnimController,
                builder: (_, __) => Opacity(
                  opacity: (1 - _captureAnimController.value) * 0.6,
                  child: _captureAnimController.value > 0
                      ? Container(color: Colors.white)
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ),

          // ── Top Bar ────────────────────────────────────────────────
          Positioned(
            top: 48,
            left: 16,
            right: 16,
            child: Row(
              children: [
                // Back button
                _CircleButton(
                  icon: Icons.arrow_back,
                  onTap: () {
                    ref.read(cameraControllerProvider.notifier).stopFlipScan();
                    context.pop();
                  },
                ),
                const Spacer(),

                // State badge
                _StateBadge(scanState: cameraState.scanState),
                const SizedBox(width: 8),

                // Page count badge
                _CountBadge(count: cameraState.capturedPages.length),
                const SizedBox(width: 8),

                // Video Mode button
                _CircleButton(
                  icon: Icons.videocam,
                  label: 'Video',
                  onTap: () {
                    ref.read(cameraControllerProvider.notifier).stopFlipScan();
                    context.push('/video-scan');
                  },
                ),
              ],
            ),
          ),

          // ── Middle Hint ────────────────────────────────────────────
          if (cameraState.scanState == ScanState.idle &&
              cameraPlugin != null &&
              cameraPlugin.value.isInitialized)
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.flip, color: Colors.white, size: 40),
                    SizedBox(height: 12),
                    Text(
                      'Press "Start Flip Scan" to begin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'The camera will auto-capture each page\nas you slowly flip through your document.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),

          // ── Flip Detected Banner ───────────────────────────────────
          if (cameraState.scanState == ScanState.flipping ||
              cameraState.scanState == ScanState.restabilizing)
            Positioned(
              top: 120,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.flip, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        cameraState.scanState == ScanState.flipping
                            ? 'Page flip detected…'
                            : 'Stabilizing new page…',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Error Banner ───────────────────────────────────────────
          if (cameraState.errorMessage != null)
            Positioned(
              top: 120,
              left: 16,
              right: 16,
              child: Material(
                color: Colors.red.shade800.withOpacity(0.9),
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

          // ── Bottom Controls ────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black, Colors.black87, Colors.transparent],
                  stops: [0.0, 0.7, 1.0],
                ),
              ),
              padding: const EdgeInsets.only(top: 12, bottom: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Thumbnail strip
                  ThumbnailStrip(
                    pages: cameraState.capturedPages,
                    onPageDelete:
                        ref.read(cameraControllerProvider.notifier).deletePage,
                  ),
                  const SizedBox(height: 12),

                  // Main controls row
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

                      // Primary action button
                      _PrimaryButton(cameraState: cameraState, ref: ref),

                      // Pause / Resume
                      _CircleButton(
                        icon: cameraState.scanState == ScanState.paused
                            ? Icons.play_arrow
                            : Icons.pause,
                        onTap: cameraState.scanState == ScanState.idle
                            ? null
                            : ref
                                .read(cameraControllerProvider.notifier)
                                .togglePause,
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Review & Export button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: FilledButton.icon(
                      onPressed: cameraState.capturedPages.isEmpty
                          ? null
                          : () {
                              ref
                                  .read(cameraControllerProvider.notifier)
                                  .stopFlipScan();
                              context.push('/review',
                                  extra: cameraState.capturedPages);
                            },
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(
                        cameraState.capturedPages.isEmpty
                            ? 'Scan pages first'
                            : 'Review & Export (${cameraState.capturedPages.length} pages)',
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
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

// ─── Primary Action Button ──────────────────────────────────────────────────

class _PrimaryButton extends ConsumerWidget {
  const _PrimaryButton({required this.cameraState, required this.ref});
  final CameraState cameraState;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef wRef) {
    final notifier = ref.read(cameraControllerProvider.notifier);
    final isFlipActive = cameraState.isFlipScanActive;
    final isProcessing = cameraState.isProcessing;

    if (!isFlipActive) {
      // ── "Start Flip Scan" button ────────────────────────────────────
      return GestureDetector(
        onTap: isProcessing ? null : notifier.startFlipScan,
        child: Container(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isProcessing ? Colors.grey : AppTheme.primaryColor,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: isProcessing
                ? []
                : [
                    BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.5),
                        blurRadius: 16,
                        spreadRadius: 2)
                  ],
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.flip, color: Colors.white, size: 28),
              SizedBox(height: 2),
              Text('START',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    // ── "Stop" button (flip scan running) ─────────────────────────────
    return GestureDetector(
      onTap: notifier.stopFlipScan,
      child: Container(
        width: 82,
        height: 82,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.red.shade700,
          border: Border.all(color: Colors.white, width: 3),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.stop, color: Colors.white, size: 28),
            SizedBox(height: 2),
            Text('STOP',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// ─── Helper widgets ─────────────────────────────────────────────────────────

class _CircleButton extends StatelessWidget {
  const _CircleButton(
      {required this.icon, this.label, required this.onTap});
  final IconData icon;
  final String? label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: onTap == null
              ? Colors.white12
              : Colors.black.withOpacity(0.55),
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: onTap == null ? Colors.white38 : Colors.white,
            size: 22),
      ),
    );
  }
}

class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.scanState});
  final ScanState scanState;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _labelAndColor(scanState);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
      ),
      child:
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
    );
  }

  (String, Color) _labelAndColor(ScanState s) {
    switch (s) {
      case ScanState.idle:
        return ('Ready', Colors.blueGrey);
      case ScanState.detecting:
        return ('Detecting…', Colors.blueGrey.shade700);
      case ScanState.stable:
        return ('Stable', Colors.green.shade700);
      case ScanState.capturing:
        return ('Capturing!', Colors.teal.shade700);
      case ScanState.monitoring:
        return ('Monitoring', Colors.indigo.shade600);
      case ScanState.flipping:
        return ('Flip!', Colors.orange.shade700);
      case ScanState.restabilizing:
        return ('Settling…', Colors.amber.shade700);
      case ScanState.paused:
        return ('Paused', Colors.grey.shade700);
      case ScanState.recording:
        return ('Recording', Colors.red.shade700);
      case ScanState.analyzing:
        return ('Analyzing', Colors.purple.shade700);
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count page${count == 1 ? '' : 's'}',
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}
