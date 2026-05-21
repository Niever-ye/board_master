import 'package:board_master/core/types.dart';
import 'package:board_master/models/chess/chess_position.dart';
import 'package:board_master/rules/chess_rules.dart';

/// Efficient move generation for alpha-beta search.
/// Returns list of (fromIdx, toIdx) pairs.

List<(int, int)> generateMoves(List<int> board, ChessColor color) {
  final moves = <(int, int)>[];
  final pos = ChessPosition(board: board);

  for (int i = 0; i < 90; i++) {
    final piece = board[i];
    if (piece == 0) continue;
    final pColor = piece > 10 ? ChessColor.black : ChessColor.red;
    if (pColor != color) continue;

    final row = i ~/ 9;
    final col = i % 9;
    final legal = ChessRules.legalMoves(pos, row, col);
    for (final (tr, tc) in legal) {
      moves.add((i, tr * 9 + tc));
    }
  }

  return moves;
}

List<(int, int)> generateCaptures(List<int> board, ChessColor color) {
  final captures = <(int, int)>[];
  final pos = ChessPosition(board: board);

  for (int i = 0; i < 90; i++) {
    final piece = board[i];
    if (piece == 0) continue;
    final pColor = piece > 10 ? ChessColor.black : ChessColor.red;
    if (pColor != color) continue;

    final row = i ~/ 9;
    final col = i % 9;
    final legal = ChessRules.legalMoves(pos, row, col);
    for (final (tr, tc) in legal) {
      final toIdx = tr * 9 + tc;
      if (board[toIdx] != 0) {
        captures.add((i, toIdx));
      }
    }
  }
  return captures;
}
