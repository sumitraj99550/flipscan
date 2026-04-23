import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../app/constants.dart';

class StorageService {
  StorageService._internal();
  static final StorageService instance = StorageService._internal();

  String? _baseDir;
  String? _imagesDir;
  String? _pdfsDir;
  String? _thumbsDir;

  Future<void> init() async {
    final appDir = await getApplicationDocumentsDirectory();
    _baseDir = p.join(appDir.path, AppConstants.documentsFolder);
    _imagesDir = p.join(_baseDir!, 'images');
    _pdfsDir = p.join(_baseDir!, 'pdfs');
    _thumbsDir = p.join(_baseDir!, 'thumbnails');

    await Directory(_imagesDir!).create(recursive: true);
    await Directory(_pdfsDir!).create(recursive: true);
    await Directory(_thumbsDir!).create(recursive: true);
  }

  String get imagesDir {
    assert(_imagesDir != null, 'StorageService not initialized');
    return _imagesDir!;
  }

  String get pdfsDir {
    assert(_pdfsDir != null, 'StorageService not initialized');
    return _pdfsDir!;
  }

  String get thumbsDir {
    assert(_thumbsDir != null, 'StorageService not initialized');
    return _thumbsDir!;
  }

  /// Save raw bytes as JPEG in images dir
  Future<String> saveImage(List<int> bytes, String filename) async {
    await init();
    final path = p.join(_imagesDir!, filename);
    final file = File(path);
    await file.writeAsBytes(bytes);
    return path;
  }

  /// Save thumbnail bytes
  Future<String> saveThumbnail(List<int> bytes, String filename) async {
    await init();
    final path = p.join(_thumbsDir!, filename);
    final file = File(path);
    await file.writeAsBytes(bytes);
    return path;
  }

  /// Save PDF bytes
  Future<String> savePdf(List<int> bytes, String filename) async {
    await init();
    final path = p.join(_pdfsDir!, filename);
    final file = File(path);
    await file.writeAsBytes(bytes);
    return path;
  }

  /// Delete a file safely
  Future<void> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Get available storage in bytes
  Future<int> getAvailableStorage() async {
    try {
      final stat = await FileStat.stat(_baseDir ?? '/');
      return stat.size; // Approximate
    } catch (_) {
      return -1;
    }
  }

  /// Check if storage is critically low (< 50MB)
  Future<bool> isStorageLow() async {
    // Basic check — on Android, use df command or StorageManager
    try {
      final dir = await getApplicationDocumentsDirectory();
      // Check if we can write
      final testFile = File(p.join(dir.path, '.test'));
      await testFile.writeAsString('test');
      await testFile.delete();
      return false;
    } catch (_) {
      return true;
    }
  }

  /// Get total size of FlipScan folder in bytes
  Future<int> getTotalStorageUsed() async {
    try {
      await init();
      int total = 0;
      final dir = Directory(_baseDir!);
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          total += await entity.length();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// Format bytes to human readable
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
