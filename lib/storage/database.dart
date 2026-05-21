import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static Database? _db;

  static Future<Database> get instance async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = '$dbPath/board_master.db';

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE game_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        game_type TEXT NOT NULL,
        title TEXT,
        player_name TEXT NOT NULL DEFAULT 'Player',
        opponent_name TEXT NOT NULL DEFAULT 'AI',
        result TEXT,
        date_played TEXT NOT NULL,
        total_moves INTEGER NOT NULL DEFAULT 0,
        board_size INTEGER DEFAULT 19,
        komi REAL DEFAULT 6.5,
        raw_data TEXT,
        difficulty TEXT NOT NULL DEFAULT 'medium',
        is_completed INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    await db.execute('''
      CREATE TABLE game_moves (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        game_id INTEGER NOT NULL,
        move_number INTEGER NOT NULL,
        coordinate TEXT,
        piece_type TEXT,
        captured_piece TEXT,
        FOREIGN KEY (game_id) REFERENCES game_records(id) ON DELETE CASCADE,
        UNIQUE(game_id, move_number)
      )
    ''');

    await db.execute(
        'CREATE INDEX idx_records_type ON game_records(game_type)');
    await db.execute(
        'CREATE INDEX idx_records_date ON game_records(date_played DESC)');
    await db.execute(
        'CREATE INDEX idx_moves_game ON game_moves(game_id, move_number)');
  }
}
