import 'package:sqflite/sqflite.dart';
import '../models/document.dart';
import 'database_helper.dart';

class DocumentRepository {
  DocumentRepository._internal();
  static final DocumentRepository instance = DocumentRepository._internal();

  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<Document> insert(Document doc) async {
    final db = await _db;
    await db.insert('documents', doc.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return doc;
  }

  Future<Document?> getById(String id) async {
    final db = await _db;
    final maps = await db.query(
      'documents',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Document.fromMap(maps.first);
  }

  Future<List<Document>> getAll({String? folder}) async {
    final db = await _db;
    List<Map<String, dynamic>> maps;
    if (folder != null) {
      maps = await db.query(
        'documents',
        where: 'folder = ?',
        whereArgs: [folder],
        orderBy: 'updated_at DESC',
      );
    } else {
      maps = await db.query('documents', orderBy: 'updated_at DESC');
    }
    return maps.map(Document.fromMap).toList();
  }

  Future<List<Document>> search(String query) async {
    final db = await _db;
    final maps = await db.query(
      'documents',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'updated_at DESC',
    );
    return maps.map(Document.fromMap).toList();
  }

  Future<void> update(Document doc) async {
    final db = await _db;
    await db.update(
      'documents',
      doc.toMap(),
      where: 'id = ?',
      whereArgs: [doc.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _db;
    await db.delete('documents', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getCount() async {
    final db = await _db;
    final result = await db.rawQuery('SELECT COUNT(*) FROM documents');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}