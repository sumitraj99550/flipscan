import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:image/image.dart' as img;
import '../app/constants.dart';
import '../models/scanned_page.dart';
import '../services/storage_service.dart';
import '../utils/file_namer.dart';

class PdfService {
  PdfService._internal();
  static final PdfService instance = PdfService._internal();

  /// Generate PDF from list of scanned pages
  Future<String> generatePdf({
    required List<ScannedPage> pages,
    required String documentId,
    required String documentName,
    int quality = 85,
  }) async {
    if (pages.isEmpty) throw Exception('No pages to generate PDF');

    final pdf = pw.Document(
      title: documentName,
      author: 'FlipScan AI',
      creator: 'FlipScan AI v${AppConstants.appVersion}',
    );

    // Sort pages by page number
    final sortedPages = List<ScannedPage>.from(pages)
      ..sort((a, b) => a.pageNumber.compareTo(b.pageNumber));

    for (final page in sortedPages) {
      try {
        final imagePath = page.enhancedPath ?? page.imagePath;
        final file = File(imagePath);

        if (!await file.exists()) {
          // Add blank page with error message if image missing
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              build: (pw.Context ctx) => pw.Center(
                child: pw.Text(
                  'Page ${page.pageNumber}: Image not found',
                  style: const pw.TextStyle(fontSize: 16),
                ),
              ),
            ),
          );
          continue;
        }

        final imageBytes = await file.readAsBytes();
        final pdfImage = pw.MemoryImage(imageBytes);

        // Get original image dimensions for correct aspect ratio
        img.Image? decodedImage;
        try {
          decodedImage = img.decodeImage(imageBytes);
        } catch (_) {}

        double pageWidth = AppConstants.pdfPageWidth;
        double pageHeight = AppConstants.pdfPageHeight;

        if (decodedImage != null) {
          final ratio = decodedImage.width / decodedImage.height;
          if (ratio > 1) {
            // Landscape
            pageWidth = AppConstants.pdfPageHeight;
            pageHeight = AppConstants.pdfPageWidth;
          }
        }

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(pageWidth, pageHeight),
            margin: pw.EdgeInsets.zero,
            build: (pw.Context ctx) => pw.Center(
              child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
            ),
          ),
        );
      } catch (e) {
        // Never crash PDF generation for one bad page
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context ctx) => pw.Center(
              child: pw.Text('Page ${page.pageNumber}: Error loading image'),
            ),
          ),
        );
      }
    }

    // Save PDF
    final pdfBytes = await pdf.save();
    final filename = FileNamer.generatePdfFilename(documentId);
    final savePath =
        await StorageService.instance.savePdf(pdfBytes, filename);

    return savePath;
  }

  /// Get PDF byte size without saving
  Future<int> estimatePdfSize(List<ScannedPage> pages) async {
    int totalImageSize = 0;
    for (final page in pages) {
      final path = page.enhancedPath ?? page.imagePath;
      final file = File(path);
      if (await file.exists()) {
        totalImageSize += await file.length();
      }
    }
    // PDF overhead ~10%
    return (totalImageSize * 1.1).toInt();
  }
}
