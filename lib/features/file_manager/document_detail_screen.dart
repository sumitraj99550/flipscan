import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/document.dart';
import '../../models/scanned_page.dart';
import '../../repositories/document_repository.dart';
import '../../repositories/page_repository.dart';
import '../../services/storage_service.dart';

class DocumentDetailScreen extends StatefulWidget {
  final String documentId;

  const DocumentDetailScreen({super.key, required this.documentId});

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  Document? _document;
  List<ScannedPage> _pages = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final doc = await DocumentRepository.instance.getById(widget.documentId);
    final pages = await PageRepository.instance.getPagesForDocument(widget.documentId);
    if (!mounted) return;
    setState(() {
      _document = doc;
      _pages = pages;
      _loading = false;
    });
  }

  Future<void> _sharePdf() async {
    final path = _document?.pdfPath;
    if (path == null) return;
    await Share.shareXFiles([XFile(path)], text: _document?.name ?? 'FlipScan document');
  }

  Future<void> _deleteDocument() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete document?'),
            content: const Text('This will remove the document from local history.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;
    await PageRepository.instance.deleteByDocumentId(widget.documentId);
    await DocumentRepository.instance.delete(widget.documentId);
    await _deleteDocumentFiles();
    if (!mounted) return;
    context.pop(true);
  }

  Future<void> _deleteDocumentFiles() async {
    final paths = <String>{};

    final pdfPath = _document?.pdfPath;
    if (pdfPath != null) {
      paths.add(pdfPath);
    }

    final thumbnailPath = _document?.thumbnailPath;
    if (thumbnailPath != null) {
      paths.add(thumbnailPath);
    }

    for (final page in _pages) {
      paths.add(page.imagePath);
      final enhancedPath = page.enhancedPath;
      if (enhancedPath != null) {
        paths.add(enhancedPath);
      }
    }

    for (final path in paths) {
      try {
        await StorageService.instance.deleteFile(path);
      } catch (_) {
        // Best-effort cleanup so deletion is not blocked by one bad file.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_document?.name ?? 'Document'),
        actions: [
          IconButton(
            onPressed: _document?.pdfPath == null ? null : _sharePdf,
            icon: const Icon(Icons.share),
          ),
          IconButton(
            onPressed: _deleteDocument,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _document == null
              ? const Center(child: Text('Document not found'))
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Card(
                      child: ListTile(
                        title: Text(_document!.name),
                        subtitle: Text('${_document!.pageCount} page(s)'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Pages', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ..._pages.map(
                      (p) => Card(
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.file(
                              File(p.displayPath),
                              width: 42,
                              height: 54,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                            ),
                          ),
                          title: Text('Page ${p.pageNumber}'),
                          subtitle: Text(p.quality.name),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
