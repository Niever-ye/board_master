import 'package:board_master/core/types.dart';
import 'package:board_master/models/game_record.dart';
import 'package:board_master/storage/database.dart';

class RecordDao {
  Future<int> insert(GameRecord record) async {
    final db = await AppDatabase.instance;
    return await db.insert('game_records', record.toMap());
  }

  Future<void> update(GameRecord record) async {
    if (record.id == null) return;
    final db = await AppDatabase.instance;
    await db.update('game_records', record.toMap(),
        where: 'id = ?', whereArgs: [record.id]);
  }

  Future<void> delete(int id) async {
    final db = await AppDatabase.instance;
    await db.delete('game_records', where: 'id = ?', whereArgs: [id]);
  }

  Future<GameRecord?> getById(int id) async {
    final db = await AppDatabase.instance;
    final maps = await db.query('game_records',
        where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return GameRecord.fromMap(maps.first);
  }

  Future<List<GameRecord>> getRecords({
    GameType? gameType,
    int limit = 50,
    int offset = 0,
    bool completedOnly = false,
  }) async {
    final db = await AppDatabase.instance;
    final where = <String>[];
    final whereArgs = <dynamic>[];

    if (gameType != null) {
      where.add('game_type = ?');
      whereArgs.add(gameType.name);
    }
    if (completedOnly) {
      where.add('is_completed = 1');
    }

    final maps = await db.query(
      'game_records',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'date_played DESC',
      limit: limit,
      offset: offset,
    );

    return maps.map((m) => GameRecord.fromMap(m)).toList();
  }

  Future<List<GameRecord>> searchRecords(String query) async {
    final db = await AppDatabase.instance;
    final maps = await db.query(
      'game_records',
      where: 'title LIKE ? OR player_name LIKE ? OR opponent_name LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'date_played DESC',
      limit: 50,
    );
    return maps.map((m) => GameRecord.fromMap(m)).toList();
  }

  Future<int> getRecordCount({GameType? gameType}) async {
    final db = await AppDatabase.instance;
    final where = gameType != null ? 'game_type = ?' : null;
    final args = gameType != null ? [gameType.name] : null;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM game_records ${where != null ? "WHERE $where" : ""}',
      args,
    );
    return result.first['cnt'] as int;
  }

  Future<void> insertMove(int gameId, int moveNum, String coord,
      {String? pieceType}) async {
    final db = await AppDatabase.instance;
    await db.insert('game_moves', {
      'game_id': gameId,
      'move_number': moveNum,
      'coordinate': coord,
      'piece_type': pieceType,
    });
  }
}
