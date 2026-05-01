import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../app/theme.dart';
import '../../models/document.dart';

class RecentDocsWidget extends StatelessWidget {
  final List<Document> documents;
  const RecentDocsWidget({super.key, required this.documents});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: documents
          .map((doc) => _DocTile(doc: doc))
          .toList(),
    );
  }
}

class _DocTile extends StatelessWidget {
  final Document doc;
  const _DocTile({required this.doc});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateStr = DateFormat('MMM dd, yyyy').format(doc.updatedAt);

    return GestureDetector(
      onTap: () => context.push('/document/${doc.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : AppTheme.lightSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : const Color(0xFFE0E4F0),
          ),
        ),
        child: Row(
          children: [
            // Thumbnail
            _Thumbnail(thumbnailPath: doc.thumbnailPath),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontSize: 14,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.description_outlined,
                          size: 13,
                          color: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.color),
                      const SizedBox(width: 4),
                      Text(
                        '${doc.pageCount} page${doc.pageCount != 1 ? 's' : ''}',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontSize: 12),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.calendar_today_outlined,
                          size: 12,
                          color: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.color),
                      const SizedBox(width: 4),
                      Text(
                        dateStr,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // PDF badge
            if (doc.pdfPath != null)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'PDF',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final String? thumbnailPath;
  const _Thumbnail({this.thumbnailPath});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (thumbnailPath != null) {
      final file = File(thumbnailPath!);
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          file,
          width: 48,
          height: 60,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(isDark, context),
        ),
      );
    }

    return _placeholder(isDark, context);
  }

  Widget _placeholder(bool isDark, BuildContext context) {
    return Container(
      width: 48,
      height: 60,
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.darkBorder
            : const Color(0xFFEEF1FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.insert_drive_file_rounded,
        color: AppTheme.primaryColor,
        size: 24,
      ),
    );
  }
}
