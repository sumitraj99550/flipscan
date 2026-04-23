import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../app/constants.dart';

class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.dbName);

    return await openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE documents (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        page_count INTEGER DEFAULT 0,
        pdf_path TEXT,
        thumbnail_path TEXT,
        folder TEXT DEFAULT 'Default'
      )
    ''');

    await db.execute('''
      CREATE TABLE pages (
        id TEXT PRIMARY KEY,
        document_id TEXT NOT NULL,
        page_number INTEGER NOT NULL,
        image_path TEXT NOT NULL,
        enhanced_path TEXT,
        ocr_text TEXT,
        blur_score REAL,
        quality INTEGER DEFAULT 3,
        enhancement_mode INTEGER DEFAULT 0,
        rotation_degrees INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
        'CREATE INDEX idx_pages_document ON pages(document_id)');
    await db.execute(
        'CREATE INDEX idx_docs_updated ON documents(updated_at DESC)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future migration logic here
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
