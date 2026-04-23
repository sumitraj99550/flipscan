import 'package:intl/intl.dart';

class FileNamer {
  static String generateDocumentName() {
    final now = DateTime.now();
    final formatter = DateFormat('MMM dd, yyyy HH:mm');
    return 'Scan — ${formatter.format(now)}';
  }

  static String generatePdfFilename(String documentId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'flipscan_${documentId.substring(0, 8)}_$timestamp.pdf';
  }

  static String generateImageFilename() {
    return 'img_${DateTime.now().millisecondsSinceEpoch}.jpg';
  }

  static String generateThumbnailFilename(String pageId) {
    return 'thumb_$pageId.jpg';
  }

  static String sanitize(String name) {
    // Remove invalid filename characters
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .trim()
        .substring(0, name.length.clamp(0, 100));
  }
}
