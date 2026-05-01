import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../app/theme.dart';
import '../../app/constants.dart';
import '../../models/document.dart';
import '../../repositories/document_repository.dart';
import '../../repositories/settings_repository.dart';
import 'recent_docs_widget.dart';

final recentDocumentsProvider =
    FutureProvider<List<Document>>((ref) async {
  final docs = await DocumentRepository.instance.getAll();
  return docs.take(5).toList();
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final recentDocs = ref.watch(recentDocumentsProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App bar
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor:
                isDark ? AppTheme.darkBg : AppTheme.lightSurface,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.only(left: 20, bottom: 16),
              title: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primaryColor, AppTheme.accentColor],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.document_scanner_rounded,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'FlipScan AI',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  isDark
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
                ),
                onPressed: () async {
                  final nextValue = !isDark;
                  ref.read(themeModeProvider.notifier).state = nextValue;
                  await SettingsRepository.instance.setDarkMode(nextValue);
                },
              ),
              IconButton(
                icon: const Icon(Icons.settings_rounded),
                onPressed: () => context.push('/settings'),
              ),
            ],
          ),

          // Body content
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Primary CTA — Start Scan
                _PrimaryActionCard(
                  onTap: () => context.push('/camera'),
                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2),

                const SizedBox(height: 16),

                // Secondary actions row
                Row(
                  children: [
                    Expanded(
                      child: _SecondaryActionCard(
                        icon: Icons.photo_library_rounded,
                        label: 'Import\nImages',
                        color: const Color(0xFF7C3AED),
                        onTap: () => _importImages(context, ref),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SecondaryActionCard(
                        icon: Icons.folder_open_rounded,
                        label: 'My\nDocuments',
                        color: const Color(0xFF059669),
                        onTap: () => context.push('/documents'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SecondaryActionCard(
                        icon: Icons.help_outline_rounded,
                        label: 'Help &\nAbout',
                        color: const Color(0xFFD97706),
                        onTap: () => _showHelp(context),
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideY(begin: 0.2),

                const SizedBox(height: 28),

                // Recent documents
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Scans',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    TextButton(
                      onPressed: () => context.push('/documents'),
                      child: const Text('See all'),
                    ),
                  ],
                ).animate().fadeIn(delay: 200.ms),

                const SizedBox(height: 8),

                recentDocs.when(
                  data: (docs) => docs.isEmpty
                      ? _EmptyRecentDocs(
                          onScan: () => context.push('/camera'),
                        ).animate().fadeIn(delay: 300.ms)
                      : RecentDocsWidget(documents: docs)
                          .animate()
                          .fadeIn(delay: 300.ms),
                  loading: () => _RecentDocsLoading(),
                  error: (e, _) => Text('Error loading documents: $e'),
                ),

                const SizedBox(height: 24),

                // Privacy badge
                _PrivacyBadge()
                    .animate()
                    .fadeIn(delay: 500.ms, duration: 400.ms),

                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _importImages(BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    try {
      final files = await picker.pickMultiImage(imageQuality: 90);
      if (files.isEmpty) return;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${files.length} image(s) selected — feature coming soon'),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not access gallery: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _showHelp(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const _HelpSheet(),
    );
  }
}

// ─── Primary Action Card ──────────────────────────────────────────────────

class _PrimaryActionCard extends StatelessWidget {
  final VoidCallback onTap;
  const _PrimaryActionCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.primaryColor, Color(0xFF0066FF)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background decoration
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Positioned(
              right: 20,
              bottom: -30,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.04),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Start New Scan',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 22,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Point camera at documents',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white60,
                            ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      color: Colors.white54, size: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Secondary Action Card ────────────────────────────────────────────────

class _SecondaryActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SecondaryActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : AppTheme.lightSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : const Color(0xFFE0E4F0),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: 12,
                    height: 1.3,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────

class _EmptyRecentDocs extends StatelessWidget {
  final VoidCallback onScan;
  const _EmptyRecentDocs({required this.onScan});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : const Color(0xFFD6DBFF),
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.document_scanner_outlined,
            size: 48,
            color: AppTheme.primaryColor.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No scans yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap "Start New Scan" to begin\nscanning your first document.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }
}

class _RecentDocsLoading extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 80,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

// ─── Privacy Badge ────────────────────────────────────────────────────────

class _PrivacyBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF00C853).withValues(alpha: 0.08)
            : const Color(0xFFE8FFF3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00C853).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user_rounded,
              color: Color(0xFF00C853), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppConstants.privacyMessage,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    color: const Color(0xFF00C853),
                    height: 1.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Help Sheet ───────────────────────────────────────────────────────────

class _HelpSheet extends StatelessWidget {
  const _HelpSheet();

  @override
  Widget build(BuildContext context) {
    final steps = [
      ('1', 'Open scanner', 'Tap "Start New Scan" from home screen.'),
      ('2', 'Position document', 'Hold phone above document. Edge overlay appears.'),
      ('3', 'Auto-capture', 'App captures when frame is stable. Watch the indicator.'),
      ('4', 'Flip pages', 'Naturally flip pages. App detects motion and re-stabilizes.'),
      ('5', 'Review & export', 'Review all pages, reorder or delete, then generate PDF.'),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('How to Use FlipScan AI',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          ...steps.map((s) => _HelpStep(
                number: s.$1,
                title: s.$2,
                description: s.$3,
              )),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    color: AppTheme.primaryColor, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'FlipScan AI v${AppConstants.appVersion}\n'
                    'All processing is done locally on your device.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 12, height: 1.4,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpStep extends StatelessWidget {
  final String number;
  final String title;
  final String description;

  const _HelpStep({
    required this.number,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(fontSize: 14)),
                const SizedBox(height: 2),
                Text(description,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
