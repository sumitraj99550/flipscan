import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../app/theme.dart';
import '../../services/storage_service.dart';
import '../../repositories/database_helper.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  String _statusText = 'Initializing…';
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await Future.delayed(const Duration(milliseconds: 300));

      _setStatus('Setting up storage…');
      await StorageService.instance.init();

      _setStatus('Loading database…');
      await DatabaseHelper.instance.database;

      _setStatus('Checking permissions…');
      await _checkPermissions();

      _setStatus('Ready!');
      await Future.delayed(const Duration(milliseconds: 400));

      if (mounted) context.go('/home');
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  void _setStatus(String text) {
    if (mounted) setState(() => _statusText = text);
  }

  Future<void> _checkPermissions() async {
    // Just check — don't request here; request on camera screen
    final cameraStatus = await Permission.camera.status;
    if (cameraStatus.isPermanentlyDenied) {
      // Will handle on camera screen
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFF0A1628),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              _buildLogo()
                  .animate()
                  .fadeIn(duration: 600.ms)
                  .scale(begin: const Offset(0.7, 0.7), duration: 600.ms,
                      curve: Curves.easeOutBack),

              const SizedBox(height: 24),

              // App name
              Text(
                'FlipScan AI',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
              )
                  .animate()
                  .fadeIn(delay: 300.ms, duration: 500.ms)
                  .slideY(begin: 0.3, end: 0),

              const SizedBox(height: 8),

              Text(
                'Intelligent Document Scanner',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white54,
                      letterSpacing: 0.5,
                    ),
              ).animate().fadeIn(delay: 500.ms, duration: 400.ms),

              const SizedBox(height: 64),

              if (!_hasError) ...[
                _buildLoadingIndicator()
                    .animate()
                    .fadeIn(delay: 600.ms, duration: 400.ms),
                const SizedBox(height: 16),
                Text(
                  _statusText,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white38,
                        fontSize: 13,
                      ),
                ).animate(key: ValueKey(_statusText)).fadeIn(duration: 200.ms),
              ] else ...[
                _buildErrorState(),
              ],

              const SizedBox(height: 80),

              // Privacy note
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_outline,
                        color: Colors.white24, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'All processing happens on your device',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white24,
                            fontSize: 11,
                          ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 800.ms, duration: 400.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.accentColor,
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.4),
            blurRadius: 32,
            spreadRadius: 4,
          ),
        ],
      ),
      child: const Icon(
        Icons.document_scanner_rounded,
        color: Colors.white,
        size: 52,
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const SizedBox(
      width: 36,
      height: 36,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
      ),
    );
  }

  Widget _buildErrorState() {
    return Column(
      children: [
        const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 36),
        const SizedBox(height: 12),
        Text(
          'Failed to initialize',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            _errorMessage ?? 'Unknown error',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.white38, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: _initialize,
          child: const Text('Retry', style: TextStyle(color: AppTheme.accentColor)),
        ),
      ],
    );
  }
}
