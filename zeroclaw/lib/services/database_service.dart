import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/news.dart';

class DatabaseService {
  static DatabaseService? _instance;
  static Database? _database;

  DatabaseService._();

  static DatabaseService get instance {
    _instance ??= DatabaseService._();
    return _instance!;
  }

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'zeroclaw_news.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE news (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        url TEXT NOT NULL,
        summary TEXT,
        site_id TEXT NOT NULL,
        site_name TEXT,
        published_at TEXT,
        category TEXT,
        is_read INTEGER NOT NULL DEFAULT 0,
        collected_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sites (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        base_url TEXT NOT NULL,
        login_url TEXT,
        is_logged_in INTEGER NOT NULL DEFAULT 0,
        is_enabled INTEGER NOT NULL DEFAULT 1,
        phase TEXT NOT NULL DEFAULT 'p0',
        categories TEXT
      )
    ''');
  }

  Future<void> insertNews(NewsItem news) async {
    final db = await database;
    await db.insert(
      'news',
      {
        'id': news.id,
        'title': news.title,
        'url': news.url,
        'summary': news.summary,
        'site_id': news.siteId,
        'site_name': news.siteName,
        'published_at': news.publishedAt?.toIso8601String(),
        'category': news.category,
        'is_read': news.isRead ? 1 : 0,
        'collected_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> insertNewsBatch(List<NewsItem> newsList) async {
    final db = await database;
    final batch = db.batch();
    for (final news in newsList) {
      batch.insert(
        'news',
        {
          'id': news.id,
          'title': news.title,
          'url': news.url,
          'summary': news.summary,
          'site_id': news.siteId,
          'site_name': news.siteName,
          'published_at': news.publishedAt?.toIso8601String(),
          'category': news.category,
          'is_read': news.isRead ? 1 : 0,
          'collected_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<NewsItem>> getNews({
    String? siteId,
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await database;
    final where = siteId != null ? 'WHERE site_id = ?' : '';
    final args = siteId != null ? [siteId] : null;
    final rows = await db.rawQuery(
      'SELECT * FROM news $where ORDER BY collected_at DESC LIMIT ? OFFSET ?',
      [...?args, limit, offset],
    );
    return rows.map(_rowToNews).toList();
  }

  Future<void> markAsRead(String newsId) async {
    final db = await database;
    await db.update(
      'news',
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [newsId],
    );
  }

  Future<void> deleteOldNews({int keepDays = 7}) async {
    final db = await database;
    final cutoff = DateTime.now().subtract(Duration(days: keepDays)).toIso8601String();
    await db.delete(
      'news',
      where: 'collected_at < ?',
      whereArgs: [cutoff],
    );
  }

  NewsItem _rowToNews(Map<String, dynamic> row) {
    return NewsItem(
      id: row['id'] as String,
      title: row['title'] as String,
      url: row['url'] as String,
      summary: row['summary'] as String? ?? '',
      siteId: row['site_id'] as String,
      siteName: row['site_name'] as String? ?? '',
      publishedAt: row['published_at'] != null
          ? DateTime.tryParse(row['published_at'] as String)
          : null,
      category: row['category'] as String?,
      isRead: (row['is_read'] as int) == 1,
    );
  }
}
