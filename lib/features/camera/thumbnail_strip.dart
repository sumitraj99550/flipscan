import 'dart:io';
import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../models/scanned_page.dart';

class ThumbnailStrip extends StatefulWidget {
  final List<ScannedPage> pages;
  final int? selectedIndex;
  final ValueChanged<int>? onPageTap;
  final ValueChanged<int>? onPageDelete;

  const ThumbnailStrip({
    super.key,
    required this.pages,
    this.selectedIndex,
    this.onPageTap,
    this.onPageDelete,
  });

  @override
  State<ThumbnailStrip> createState() => _ThumbnailStripState();
}

class _ThumbnailStripState extends State<ThumbnailStrip> {
  final _scrollController = ScrollController();

  @override
  void didUpdateWidget(ThumbnailStrip old) {
    super.didUpdateWidget(old);
    // Auto-scroll to latest
    if (widget.pages.length > old.pages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pages.isEmpty) {
      return Container(
        height: 90,
        alignment: Alignment.center,
        child: Text(
          'Pages will appear here',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white38,
                fontSize: 13,
              ),
        ),
      );
    }

    return SizedBox(
      height: 90,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: widget.pages.length,
        itemBuilder: (context, index) {
          final page = widget.pages[index];
          final isSelected = index == widget.selectedIndex;

          return GestureDetector(
            onTap: () => widget.onPageTap?.call(index),
            onLongPress: () => _showDeleteDialog(context, index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              width: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.accentColor
                      : (page.isBlurry
                          ? AppTheme.warningColor
                          : Colors.white24),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppTheme.accentColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                        )
                      ]
                    : null,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image.file(
                      File(page.imagePath),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey[800],
                        child: const Icon(Icons.broken_image,
                            color: Colors.white38, size: 20),
                      ),
                    ),
                  ),
                  // Page number
                  Positioned(
                    bottom: 3,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      color: Colors.black45,
                      child: Text(
                        '${page.pageNumber}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  // Blur warning
                  if (page.isBlurry)
                    Positioned(
                      top: 3,
                      right: 3,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: AppTheme.warningColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.warning_amber_rounded,
                            size: 10, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Page?'),
        content: Text(
            'Remove page ${widget.pages[index].pageNumber} from this scan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onPageDelete?.call(index);
            },
            child: const Text('Delete',
                style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }
}
