// Simple parser for Chinese Chess game records.
// Format: each move on a line with from-to coordinates e.g. "e1e2" or "h9g7"

class ChineseChessRecord {
  final String playerName;
  final String opponentName;
  final String? result;
  final List<(int, int, int, int)> moves; // (fromRow, fromCol, toRow, toCol)

  const ChineseChessRecord({
    required this.playerName,
    required this.opponentName,
    this.result,
    required this.moves,
  });

  String toPgn() {
    final buffer = StringBuffer();
    buffer.writeln('[Red "$playerName"]');
    buffer.writeln('[Black "$opponentName"]');
    if (result != null) buffer.writeln('[Result "$result"]');
    buffer.writeln('');

    for (int i = 0; i < moves.length; i++) {
      final (fr, fc, tr, tc) = moves[i];
      final from = _coordStr(fr, fc);
      final to = _coordStr(tr, tc);
      buffer.writeln('${i + 1}. $from$to');
    }

    if (result != null) buffer.writeln(result);
    return buffer.toString();
  }

  factory ChineseChessRecord.fromPgn(String content) {
    final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    String playerName = 'Red';
    String opponentName = 'Black';
    String? result;
    final moves = <(int, int, int, int)>[];

    for (final line in lines) {
      if (line.startsWith('[')) {
        final match = RegExp(r'\[(\w+)\s+"([^"]*)"\]').firstMatch(line);
        if (match != null) {
          final key = match.group(1)!;
          final val = match.group(2)!;
          if (key == 'Red') playerName = val;
          if (key == 'Black') opponentName = val;
          if (key == 'Result') result = val;
        }
      } else if (RegExp(r'\d+\.').hasMatch(line)) {
        // Move line: "1. e1e2"
        final movePattern = RegExp(r'([a-i])(\d)([a-i])(\d)');
        for (final match in movePattern.allMatches(line)) {
          final fc = match.group(1)!.codeUnitAt(0) - 'a'.codeUnitAt(0);
          final fr = 9 - (int.parse(match.group(2)!) - 1);
          final tc = match.group(3)!.codeUnitAt(0) - 'a'.codeUnitAt(0);
          final tr = 9 - (int.parse(match.group(4)!) - 1);
          moves.add((fr, fc, tr, tc));
        }
      }
    }

    return ChineseChessRecord(
      playerName: playerName,
      opponentName: opponentName,
      result: result,
      moves: moves,
    );
  }

  String _coordStr(int row, int col) {
    final colChar = String.fromCharCode('a'.codeUnitAt(0) + col);
    final rowChar = '${9 - row + 1}';
    return '$colChar$rowChar';
  }
}
