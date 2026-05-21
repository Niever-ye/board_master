import 'package:board_master/core/types.dart';

/// Simple SGF (Smart Game Format) parser for Go games.
class SgfParser {
  /// Parse an SGF string into a list of moves.
  /// Each move is (color, row, col) where Stone.black/white and 0-indexed coords.
  static List<(Stone, int, int)> parseMoves(String sgf) {
    final moves = <(Stone, int, int)>[];

    // Extract game tree content
    final content = _extractContent(sgf);
    if (content.isEmpty) return moves;

    // Find all move properties
    final movePattern = RegExp(r';(B|W)\[([a-s]{2})\]');
    for (final match in movePattern.allMatches(content)) {
      final color = match.group(1) == 'B' ? Stone.black : Stone.white;
      final coord = match.group(2)!;
      final col = coord.codeUnitAt(0) - 'a'.codeUnitAt(0);
      final row = coord.codeUnitAt(1) - 'a'.codeUnitAt(0);
      moves.add((color, row, col));
    }

    return moves;
  }

  /// Serialize a list of moves to SGF format.
  static String toSgf(List<(Stone, int, int)> moves, {
    int boardSize = 19,
    double komi = 6.5,
    String playerName = 'Player',
    String opponentName = 'AI',
    String? result,
  }) {
    final buffer = StringBuffer();
    buffer.write('(;GM[1]FF[4]SZ[$boardSize]KM[$komi]');
    buffer.write('PB[$playerName]PW[$opponentName]');
    if (result != null) buffer.write('RE[$result]');

    for (final (stone, row, col) in moves) {
      final color = stone == Stone.black ? 'B' : 'W';
      final colChar = String.fromCharCode('a'.codeUnitAt(0) + col);
      final rowChar = String.fromCharCode('a'.codeUnitAt(0) + row);
      buffer.write(';$color[$colChar$rowChar]');
    }

    buffer.write(')');
    return buffer.toString();
  }

  static String _extractContent(String sgf) {
    // Remove outer parentheses, comments, and variation markers
    var content = sgf.trim();
    if (content.startsWith('(') && content.endsWith(')')) {
      content = content.substring(1, content.length - 1);
    }
    // Remove nested variations for simplicity
    content = content.replaceAll(RegExp(r'\([^)]*\)'), '');
    return content;
  }

  /// Get game info from SGF header.
  static Map<String, String> parseHeader(String sgf) {
    final header = <String, String>{};
    final props = RegExp(r'(\w+)\[([^\]]*)\]');
    // Extract content before first move
    final firstMove = sgf.indexOf(';B[');
    final firstMoveW = sgf.indexOf(';W[');
    final start = firstMove < 0
        ? 0
        : (firstMoveW < 0 ? firstMove : (firstMove < firstMoveW ? firstMove : firstMoveW));
    final headerPart = start > 0 ? sgf.substring(0, start) : sgf;
    for (final match in props.allMatches(headerPart)) {
      header[match.group(1)!] = match.group(2)!;
    }
    return header;
  }
}
