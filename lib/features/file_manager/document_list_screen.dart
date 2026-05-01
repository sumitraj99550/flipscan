import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/document.dart';
import '../../repositories/document_repository.dart';

class DocumentListScreen extends StatefulWidget {
  const DocumentListScreen({super.key});

  @override
  State<DocumentListScreen> createState() => _DocumentListScreenState();
}

class _DocumentListScreenState extends State<DocumentListScreen> {
  late Future<List<Document>> _docsFuture;

  @override
  void initState() {
    super.initState();
    _docsFuture = DocumentRepository.instance.getAll();
  }

  Future<void> _reload() async {
    setState(() {
      _docsFuture = DocumentRepository.instance.getAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents'),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<Document>>(
        future: _docsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data ?? const [];
          if (docs.isEmpty) {
            return const Center(child: Text('No documents yet'));
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              itemCount: docs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final doc = docs[index];
                return ListTile(
                  leading: _thumb(doc.thumbnailPath),
                  title: Text(doc.name),
                  subtitle: Text('${doc.pageCount} page(s)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final wasDeleted = await context.push<bool>(
                      '/document/${doc.id}',
                    );
                    if (wasDeleted == true) {
                      await _reload();
                    }
                  },
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/camera'),
        icon: const Icon(Icons.camera_alt),
        label: const Text('Scan'),
      ),
    );
  }

  Widget _thumb(String? path) {
    if (path == null) {
      return const Icon(Icons.insert_drive_file_outlined);
    }
    final file = File(path);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.file(
        file,
        width: 42,
        height: 54,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined),
      ),
    );
  }
}
