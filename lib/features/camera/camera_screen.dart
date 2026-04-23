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

class _CameraScreenState extends ConsumerState<CameraScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initCamera();
    });
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission is required to scan.')),
      );
      return;
    }
    await ref.read(cameraControllerProvider.notifier).initCamera();
  }

  @override
  Widget build(BuildContext context) {
    final cameraState = ref.watch(cameraControllerProvider);
    final cameraPlugin = ref.watch(cameraPluginProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: (cameraPlugin != null && cameraPlugin.value.isInitialized)
                ? CameraPreview(cameraPlugin)
                : const Center(child: CircularProgressIndicator()),
          ),
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
          Positioned(
            top: 48,
            left: 16,
            right: 16,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _scanStateLabel(cameraState.scanState),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${cameraState.capturedPages.length} page(s)',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black87,
              padding: const EdgeInsets.only(top: 8, bottom: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ThumbnailStrip(
                    pages: cameraState.capturedPages,
                    onPageDelete: ref.read(cameraControllerProvider.notifier).deletePage,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        onPressed: ref.read(cameraControllerProvider.notifier).toggleTorch,
                        icon: Icon(
                          cameraState.isTorchOn ? Icons.flash_on : Icons.flash_off,
                          color: Colors.white,
                        ),
                      ),
                      InkWell(
                        onTap: cameraState.isProcessing
                            ? null
                            : ref.read(cameraControllerProvider.notifier).manualCapture,
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: cameraState.isProcessing
                                ? Colors.grey
                                : AppTheme.primaryColor,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 34),
                        ),
                      ),
                      IconButton(
                        onPressed: ref.read(cameraControllerProvider.notifier).togglePause,
                        icon: Icon(
                          cameraState.scanState == ScanState.paused
                              ? Icons.play_arrow
                              : Icons.pause,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: cameraState.capturedPages.isEmpty
                        ? null
                        : () => context.push('/review', extra: cameraState.capturedPages),
                    icon: const Icon(Icons.check),
                    label: const Text('Review & Export'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _scanStateLabel(ScanState state) {
    switch (state) {
      case ScanState.idle:
        return 'Idle';
      case ScanState.detecting:
        return 'Detecting';
      case ScanState.stable:
        return 'Stable';
      case ScanState.capturing:
        return 'Capturing';
      case ScanState.flipping:
        return 'Flipping';
      case ScanState.paused:
        return 'Paused';
      case ScanState.error:
        return 'Error';
    }
  }
}
