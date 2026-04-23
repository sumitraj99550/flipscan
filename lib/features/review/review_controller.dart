import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/document.dart';
import '../../models/scanned_page.dart';
import '../../repositories/document_repository.dart';
import '../../repositories/page_repository.dart';
import '../../services/pdf_service.dart';
import '../../services/image_enhancement_service.dart';
import '../../utils/file_namer.dart';
import '../../utils/image_utils.dart';
import 'package:image/image.dart' as img;
import '../../services/storage_service.dart';

// ─── State ────────────────────────────────────────────────────────────────

enum ReviewStatus { idle, savingPdf, saved, error }

class ReviewState {
  final List<ScannedPage> pages;
  final ReviewStatus status;
  final String? savedPdfPath;
  final String? errorMessage;
  final bool isProcessing;
  final String documentName;
  final Set<String> processingPageIds;

  const ReviewState({
    required this.pages,
    this.status = ReviewStatus.idle,
    this.savedPdfPath,
    this.errorMessage,
    this.isProcessing = false,
    this.documentName = '',
    this.processingPageIds = const {},
  });

  ReviewState copyWith({
    List<ScannedPage>? pages,
    ReviewStatus? status,
    String? savedPdfPath,
    String? errorMessage,
    bool? isProcessing,
    String? documentName,
    Set<String>? processingPageIds,
    bool clearError = false,
  }) =>
      ReviewState(
        pages: pages ?? this.pages,
        status: status ?? this.status,
        savedPdfPath: savedPdfPath ?? this.savedPdfPath,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        isProcessing: isProcessing ?? this.isProcessing,
        documentName: documentName ?? this.documentName,
        processingPageIds: processingPageIds ?? this.processingPageIds,
      );
}

// ─── Provider ─────────────────────────────────────────────────────────────

final reviewControllerProvider = StateNotifierProvider.autoDispose
    .family<ReviewNotifier, ReviewState, List<ScannedPage>>(
  (ref, pages) => ReviewNotifier(pages),
);

// ─── Notifier ─────────────────────────────────────────────────────────────

class ReviewNotifier extends StateNotifier<ReviewState> {
  ReviewNotifier(List<ScannedPage> initialPages)
      : super(ReviewState(
          pages: initialPages,
          documentName: FileNamer.generateDocumentName(),
        ));

  final _uuid = const Uuid();

  // ── Page operations ───────────────────────────────────────────────────

  void reorderPages(int oldIndex, int newIndex) {
    final pages = List<ScannedPage>.from(state.pages);
    if (newIndex > oldIndex) newIndex--;
    final item = pages.removeAt(oldIndex);
    pages.insert(newIndex, item);

    // Re-number
    final renumbered = pages.asMap().entries.map((e) {
      return e.value.copyWith(pageNumber: e.key + 1);
    }).toList();

    state = state.copyWith(pages: renumbered);
  }

  void deletePage(int index) {
    final pages = List<ScannedPage>.from(state.pages);
    pages.removeAt(index);
    final renumbered = pages.asMap().entries.map((e) {
      return e.value.copyWith(pageNumber: e.key + 1);
    }).toList();
    state = state.copyWith(pages: renumbered);
  }

  Future<void> rotatePage(int index) async {
    final pages = List<ScannedPage>.from(state.pages);
    final page = pages[index];
    final processingIds = Set<String>.from(state.processingPageIds)..add(page.id);
    state = state.copyWith(processingPageIds: processingIds);

    try {
      final newDegrees = (page.rotationDegrees + 90) % 360;
      final imageFile = File(page.imagePath);
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image != null) {
        final rotated = ImageUtils.rotate(image, newDegrees);
        final rotFilename = 'rot_${page.id}_$newDegrees.jpg';
        final rotPath = await StorageService.instance.saveImage(
          img.encodeJpg(rotated, quality: 85),
          rotFilename,
        );
        pages[index] = page.copyWith(
          imagePath: rotPath,
          rotationDegrees: newDegrees,
        );
      }
    } finally {
      final ids = Set<String>.from(state.processingPageIds)..remove(page.id);
      state = state.copyWith(pages: pages, processingPageIds: ids);
    }
  }

  Future<void> applyEnhancement(int index, EnhancementMode mode) async {
    final pages = List<ScannedPage>.from(state.pages);
    final page = pages[index];
    final processingIds = Set<String>.from(state.processingPageIds)..add(page.id);
    state = state.copyWith(processingPageIds: processingIds);

    try {
      final enhancedPath = await EnhancementService.instance.enhancePage(
        sourceImagePath: page.imagePath,
        pageId: page.id,
        mode: mode,
      );
      pages[index] = page.copyWith(
        enhancedPath: enhancedPath,
        enhancementMode: mode,
      );
    } catch (e) {
      // Enhancement failed — keep original
    } finally {
      final ids = Set<String>.from(state.processingPageIds)..remove(page.id);
      state = state.copyWith(pages: pages, processingPageIds: ids);
    }
  }

  void updateDocumentName(String name) {
    state = state.copyWith(documentName: name);
  }

  // ── Save & Export ─────────────────────────────────────────────────────

  Future<String?> saveDocument() async {
    if (state.pages.isEmpty) {
      state = state.copyWith(errorMessage: 'No pages to save.');
      return null;
    }

    state = state.copyWith(status: ReviewStatus.savingPdf, isProcessing: true);

    try {
      final docId = _uuid.v4();
      final now = DateTime.now();
      final name = state.documentName.trim().isEmpty
          ? FileNamer.generateDocumentName()
          : state.documentName;

      // Update documentId for all pages
      final pages = state.pages
          .map((p) => p.copyWith(documentId: docId))
          .toList();

      // Generate PDF
      final pdfPath = await PdfService.instance.generatePdf(
        pages: pages,
        documentId: docId,
        documentName: name,
      );

      // Save pages to DB
      for (final page in pages) {
        await PageRepository.instance.insert(page);
      }

      // Get first page as thumbnail
      final thumbPath = pages.isNotEmpty ? pages.first.imagePath : null;

      // Save document to DB
      final doc = Document(
        id: docId,
        name: name,
        createdAt: now,
        updatedAt: now,
        pageCount: pages.length,
        pdfPath: pdfPath,
        thumbnailPath: thumbPath,
      );
      await DocumentRepository.instance.insert(doc);

      state = state.copyWith(
        pages: pages,
        status: ReviewStatus.saved,
        savedPdfPath: pdfPath,
        isProcessing: false,
      );

      return pdfPath;
    } catch (e) {
      state = state.copyWith(
        status: ReviewStatus.error,
        errorMessage: 'Failed to save: $e',
        isProcessing: false,
      );
      return null;
    }
  }
}
