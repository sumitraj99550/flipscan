import 'package:sqflite/sqflite.dart';
import '../models/scanned_page.dart';
import 'database_helper.dart';

class PageRepository {
  PageRepository._internal();
  static final PageRepository instance = PageRepository._internal();

  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<ScannedPage> insert(ScannedPage page) async {
    final db = await _db;
    await db.insert('pages', page.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return page;
  }

  Future<List<ScannedPage>> getPagesForDocument(String documentId) async {
    final db = await _db;
    final maps = await db.query(
      'pages',
      where: 'document_id = ?',
      whereArgs: [documentId],
      orderBy: 'page_number ASC',
    );
    return maps.map(ScannedPage.fromMap).toList();
  }

  Future<ScannedPage?> getById(String id) async {
    final db = await _db;
    final maps = await db.query('pages', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return ScannedPage.fromMap(maps.first);
  }

  Future<void> update(ScannedPage page) async {
    final db = await _db;
    await db.update(
      'pages',
      page.toMap(),
      where: 'id = ?',
      whereArgs: [page.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _db;
    await db.delete('pages', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteByDocumentId(String documentId) async {
    final db = await _db;
    await db.delete('pages', where: 'document_id = ?', whereArgs: [documentId]);
  }

  Future<void> reorderPages(String documentId, List<String> pageIds) async {
    final db = await _db;
    final batch = db.batch();
    for (int i = 0; i < pageIds.length; i++) {
      batch.update(
        'pages',
        {'page_number': i + 1},
        where: 'id = ? AND document_id = ?',
        whereArgs: [pageIds[i], documentId],
      );
    }
    await batch.commit(noResult: true);
  }
}
