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

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = reviewControllerProvider(widget.pages);
    final state = ref.watch(provider);
    final notifier = ref.read(provider.notifier);

    if (_nameController.text.isEmpty && state.documentName.isNotEmpty) {
      _nameController.text = state.documentName;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Pages'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _nameController,
              onChanged: notifier.updateDocumentName,
              decoration: const InputDecoration(
                labelText: 'Document name',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: state.pages.isEmpty
                ? const Center(child: Text('No pages to review'))
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: state.pages.length,
                    onReorder: notifier.reorderPages,
                    itemBuilder: (context, index) {
                      final page = state.pages[index];
                      final isProcessing = state.processingPageIds.contains(page.id);

                      return Card(
                        key: ValueKey(page.id),
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(8),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(page.displayPath),
                              width: 54,
                              height: 72,
                              fit: BoxFit.cover,
                            ),
                          ),
                          title: Text('Page ${page.pageNumber}'),
                          subtitle: Text(
                            page.quality.name,
                            style: TextStyle(
                              color: page.isBlurry
                                  ? AppTheme.warningColor
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              PopupMenuButton<EnhancementMode>(
                                icon: const Icon(Icons.tune),
                                onSelected: (mode) => notifier.applyEnhancement(index, mode),
                                itemBuilder: (context) => EnhancementMode.values
                                    .map(
                                      (m) => PopupMenuItem(
                                        value: m,
                                        child: Text(m.name),
                                      ),
                                    )
                                    .toList(),
                              ),
                              IconButton(
                                onPressed: isProcessing ? null : () => notifier.rotatePage(index),
                                icon: const Icon(Icons.rotate_right),
                              ),
                              IconButton(
                                onPressed: isProcessing ? null : () => notifier.deletePage(index),
                                icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: state.isProcessing
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final router = GoRouter.of(context);
                        final path = await notifier.saveDocument();
                        if (!mounted) return;
                        if (path != null) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('Saved PDF: $path')),
                          );
                          router.go('/documents');
                        } else {
                          final latestState = ref.read(provider);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                latestState.errorMessage ?? 'Save failed',
                              ),
                            ),
                          );
                        }
                      },
                icon: state.isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf),
                label: const Text('Save PDF'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
