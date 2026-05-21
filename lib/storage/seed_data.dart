import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:board_master/core/types.dart';
import 'package:board_master/models/game_record.dart';
import 'package:board_master/storage/record_dao.dart';

class SeedData {
  static Future<void> seedIfNeeded(RecordDao dao) async {
    final count = await dao.getRecordCount();
    if (count > 0) return;

    try {
      final jsonStr =
          await rootBundle.loadString('assets/records/classic_games.json');
      final List<dynamic> data = json.decode(jsonStr);

      for (final item in data) {
        final record = GameRecord(
          gameType: item['game_type'] == 'go' ? GameType.go : GameType.chess,
          title: item['title'] as String?,
          playerName: item['player_name'] as String,
          opponentName: item['opponent_name'] as String,
          result: item['result'] as String?,
          datePlayed: DateTime.parse(item['date_played'] as String),
          boardSize: item['board_size'] as int? ?? 19,
          komi: (item['komi'] as num?)?.toDouble() ?? 6.5,
          rawData: item['raw_data'] as String?,
          difficulty: item['difficulty'] as String? ?? 'medium',
          isCompleted: true,
        );
        await dao.insert(record);
      }
    } catch (_) {
      // Asset file may not exist yet — that's fine
    }
  }
}
