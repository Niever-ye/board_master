import 'package:board_master/core/types.dart';

/// Score a move for move ordering. Higher score = search first.
int scoreMove({
  required List<int> board,
  required int fromIdx,
  required int toIdx,
  required int ttMoveFrom,
  required int ttMoveTo,
  required List<List<int>> killerMoves,
  required List<List<int>> historyTable,
  required int depth,
}) {
  // TT move gets highest priority
  if (fromIdx == ttMoveFrom && toIdx == ttMoveTo) return 1000000;

  final piece = board[fromIdx];
  final target = board[toIdx];

  int score = 0;

  // MVV-LVA for captures
  if (target != 0) {
    final victimValue = _pieceValue(target);
    final attackerValue = _pieceValue(piece);
    score = victimValue * 10 - attackerValue;
  }

  // Killer moves
  for (int i = 0; i < killerMoves[depth].length; i += 2) {
    if (i + 1 < killerMoves[depth].length &&
        killerMoves[depth][i] == fromIdx &&
        killerMoves[depth][i + 1] == toIdx) {
      score += 500;
      break;
    }
  }

  // History heuristic
  score += historyTable[piece][toIdx];

  return score;
}

void storeKillerMove(List<List<int>> killerMoves, int depth, int fromIdx, int toIdx) {
  final km = killerMoves[depth];
  // Don't store duplicates
  for (int i = 0; i < km.length; i += 2) {
    if (i + 1 < km.length && km[i] == fromIdx && km[i + 1] == toIdx) return;
  }
  km.insert(0, toIdx);
  km.insert(0, fromIdx);
  if (km.length > 4) {
    km.removeLast();
    km.removeLast();
  }
}

int _pieceValue(int piece) {
  if (piece == 0) return 0;
  final typeIdx = piece > 10 ? piece - 11 : piece - 1;
  switch (PieceType.values[typeIdx]) {
    case PieceType.general: return 10000;
    case PieceType.chariot: return 900;
    case PieceType.cannon: return 450;
    case PieceType.horse: return 400;
    case PieceType.elephant: return 200;
    case PieceType.advisor: return 200;
    case PieceType.soldier: return 100;
  }
}
