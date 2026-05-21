import 'package:board_master/core/types.dart';

class GameRecord {
  final int? id;
  final GameType gameType;
  final String? title;
  final String playerName;
  final String opponentName;
  final String? result;
  final DateTime datePlayed;
  final int totalMoves;
  final int boardSize;
  final double komi;
  final String? rawData;
  final String difficulty;
  final bool isCompleted;

  const GameRecord({
    this.id,
    required this.gameType,
    this.title,
    required this.playerName,
    required this.opponentName,
    this.result,
    required this.datePlayed,
    this.totalMoves = 0,
    this.boardSize = 19,
    this.komi = 6.5,
    this.rawData,
    this.difficulty = 'medium',
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'game_type': gameType.name,
      'title': title,
      'player_name': playerName,
      'opponent_name': opponentName,
      'result': result,
      'date_played': datePlayed.toIso8601String(),
      'total_moves': totalMoves,
      'board_size': boardSize,
      'komi': komi,
      'raw_data': rawData,
      'difficulty': difficulty,
      'is_completed': isCompleted ? 1 : 0,
    };
  }

  factory GameRecord.fromMap(Map<String, dynamic> map) {
    return GameRecord(
      id: map['id'] as int?,
      gameType: GameType.values.byName(map['game_type'] as String),
      title: map['title'] as String?,
      playerName: map['player_name'] as String,
      opponentName: map['opponent_name'] as String,
      result: map['result'] as String?,
      datePlayed: DateTime.parse(map['date_played'] as String),
      totalMoves: map['total_moves'] as int? ?? 0,
      boardSize: map['board_size'] as int? ?? 19,
      komi: (map['komi'] as num?)?.toDouble() ?? 6.5,
      rawData: map['raw_data'] as String?,
      difficulty: map['difficulty'] as String? ?? 'medium',
      isCompleted: (map['is_completed'] as int?) == 1,
    );
  }
}
