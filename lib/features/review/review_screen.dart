import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../models/scanned_page.dart';
import 'review_controller.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  final List<ScannedPage> pages;

  const ReviewScreen({super.key, required this.pages});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _nameController;
  late TabController _tabController;
  bool _nameInitialized = false; // ensures build() only sets the name ONCE

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = reviewControllerProvider(widget.pages);
    final state = ref.watch(provider);
    final notifier = ref.read(provider.notifier);

    if (!_nameInitialized && state.documentName.isNotEmpty) {
      _nameController.text = state.documentName;
      _nameInitialized = true;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Review & Export'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.view_list), text: 'Reorder'),
            Tab(icon: Icon(Icons.grid_view), text: 'Preview'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Document name field ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: TextField(
              controller: _nameController,
              onChanged: notifier.updateDocumentName,
              decoration: InputDecoration(
                labelText: 'Document name',
                hintText: 'Enter a name for the PDF',
                prefixIcon: const Icon(Icons.description_outlined),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
              ),
            ),
          ),

          // ── Page count + reorder hint ───────────────────────────────
          if (state.pages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${state.pages.length} page${state.pages.length == 1 ? '' : 's'}',
                      style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.drag_handle,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  const Text('Drag to reorder pages',
                      style:
                      TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),

          // ── Tab views ───────────────────────────────────────────────
          Expanded(
            child: state.pages.isEmpty
                ? _EmptyState(onBack: () => context.pop())
                : TabBarView(
              controller: _tabController,
              children: [
                // Tab 1 — Reorder list
                _ReorderTab(
                  state: state,
                  notifier: notifier,
                ),
                // Tab 2 — Grid preview
                _GridPreviewTab(
                  pages: state.pages,
                  notifier: notifier,
                ),
              ],
            ),
          ),

          // ── Save button ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(
                    color: Theme.of(context).dividerColor, width: 0.5),
              ),
            ),
            child: FilledButton.icon(
              onPressed: (state.isProcessing || state.pages.isEmpty)
                  ? null
                  : () async {
                final messenger = ScaffoldMessenger.of(context);
                final router = GoRouter.of(context);
                final path = await notifier.saveDocument();
                if (!mounted) return;
                if (path != null) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: Colors.white),
                          const SizedBox(width: 10),
                          Expanded(
                              child:
                              Text('PDF saved: ${path.split('/').last}')),
                        ],
                      ),
                      backgroundColor: Colors.green.shade700,
                    ),
                  );
                  router.go('/documents');
                } else {
                  final latestState = ref.read(provider);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                          latestState.errorMessage ?? 'Save failed'),
                      backgroundColor: Colors.red.shade700,
                    ),
                  );
                }
              },
              icon: state.isProcessing
                  ? const SizedBox(
                width: 18,
                height: 18,
                child:
                CircularProgressIndicator(strokeWidth: 2.5),
              )
                  : const Icon(Icons.picture_as_pdf),
              label: Text(
                state.isProcessing
                    ? 'Saving…'
                    : 'Export as PDF  (${state.pages.length} pages)',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                textStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reorder Tab ─────────────────────────────────────────────────────────────

class _ReorderTab extends StatelessWidget {
  const _ReorderTab({required this.state, required this.notifier});
  final ReviewState state;
  final ReviewNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      onReorder: notifier.reorderPages,
      itemCount: state.pages.length,
      proxyDecorator: (child, index, animation) {
        return Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(14),
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final page = state.pages[index];
        final isProcessing = state.processingPageIds.contains(page.id);

        return Card(
          key: ValueKey(page.id),
          margin: const EdgeInsets.only(bottom: 10),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                // Page number pill
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${page.pageNumber}',
                      style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(page.displayPath),
                    width: 56,
                    height: 74,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 56,
                      height: 74,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image,
                          color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Page ${page.pageNumber}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            page.isBlurry
                                ? Icons.warning_amber_rounded
                                : Icons.check_circle_outline,
                            size: 14,
                            color: page.isBlurry
                                ? AppTheme.warningColor
                                : Colors.green,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            page.isBlurry ? 'May be blurry' : 'Good quality',
                            style: TextStyle(
                                fontSize: 12,
                                color: page.isBlurry
                                    ? AppTheme.warningColor
                                    : Colors.green.shade700),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Actions
                if (isProcessing)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Enhance
                      PopupMenuButton<EnhancementMode>(
                        icon: const Icon(Icons.tune, size: 20),
                        tooltip: 'Enhance',
                        onSelected: (mode) =>
                            notifier.applyEnhancement(index, mode),
                        itemBuilder: (context) => EnhancementMode.values
                            .map((m) => PopupMenuItem(
                            value: m, child: Text(m.name)))
                            .toList(),
                      ),
                      // Rotate
                      IconButton(
                        icon: const Icon(Icons.rotate_right, size: 20),
                        tooltip: 'Rotate',
                        onPressed: () => notifier.rotatePage(index),
                      ),
                      // Delete
                      IconButton(
                        icon: Icon(Icons.delete_outline,
                            size: 20, color: AppTheme.errorColor),
                        tooltip: 'Delete',
                        onPressed: () => _confirmDelete(context, index, page.pageNumber, notifier),
                      ),
                    ],
                  ),

                // Drag handle
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.drag_handle, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, int index, int pageNumber,
      ReviewNotifier notifier) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete page?'),
        content: Text('Remove page $pageNumber from the document?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              notifier.deletePage(index);
            },
            style:
            FilledButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ─── Grid Preview Tab ─────────────────────────────────────────────────────────

class _GridPreviewTab extends StatelessWidget {
  const _GridPreviewTab({required this.pages, required this.notifier});
  final List<ScannedPage> pages;
  final ReviewNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(14),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.72,
      ),
      itemCount: pages.length,
      itemBuilder: (context, index) {
        final page = pages[index];
        return Stack(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                File(page.displayPath),
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade200,
                  child:
                  const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
            // Page number badge
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${page.pageNumber}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
            // Quality warning
            if (page.isBlurry)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.warning_amber_rounded,
                      color: Colors.white, size: 12),
                ),
              ),
            // Delete overlay on tap
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onLongPress: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text('Delete page ${page.pageNumber}?'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel')),
                          FilledButton(
                            onPressed: () {
                              Navigator.pop(context);
                              notifier.deletePage(index);
                            },
                            style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.errorColor),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Empty State ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.document_scanner_outlined,
              size: 72, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('No pages captured',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey)),
          const SizedBox(height: 8),
          const Text('Go back and scan some document pages first.',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to Camera'),
          ),
        ],
      ),
    );
  }
}