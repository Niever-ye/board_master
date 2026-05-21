import 'package:board_master/core/types.dart';

/// Piece values in centipawns.
const Map<PieceType, int> pieceValues = {
  PieceType.general: 10000,
  PieceType.chariot: 900,
  PieceType.cannon: 450,
  PieceType.horse: 400,
  PieceType.elephant: 200,
  PieceType.advisor: 200,
  PieceType.soldier: 100,
};

/// Piece-square tables for positional bonus (from Red's perspective).
/// Higher value = better position for the piece.

// Chariot PST: bonus for open files and center
const List<int> chariotPst = [
   0,  0,  0,  0,  0,  0,  0,  0,  0,
   0,  0,  0,  0,  0,  0,  0,  0,  0,
   0,  0,  0,  0,  0,  0,  0,  0,  0,
   0,  0,  0,  0,  0,  0,  0,  0,  0,
   0,  0,  0,  0,  0,  0,  0,  0,  0,
   5, 10, 10, 15, 15, 10, 10,  5,  5,
  10, 10, 15, 20, 20, 15, 10, 10, 10,
  10, 10, 15, 20, 20, 15, 10, 10, 10,
   5,  5, 15, 20, 20, 15,  5,  5,  5,
   5,  5, 15, 20, 20, 15,  5,  5,  5,
];

// Horse PST: center bonus, edge penalty
const List<int> horsePst = [
   0,  0,  5,  5,  5,  5,  5,  0,  0,
   0,  5, 10, 10, 10, 10, 10,  5,  0,
   5, 10, 15, 15, 15, 15, 15, 10,  5,
   5, 10, 15, 20, 20, 20, 15, 10,  5,
   5, 10, 15, 20, 20, 20, 15, 10,  5,
   5, 10, 15, 15, 15, 15, 15, 10,  5,
   0,  5, 10, 10, 10, 10, 10,  5,  0,
   0,  0,  5,  5,  5,  5,  5,  0,  0,
   0,  0,  5,  5,  5,  5,  5,  0,  0,
   0,  0,  0,  0,  0,  0,  0,  0,  0,
];

// Cannon PST
const List<int> cannonPst = [
   0,  0,  0,  5,  5,  5,  0,  0,  0,
   0,  0,  0,  5, 10,  5,  0,  0,  0,
   0,  0,  0,  5,  5,  5,  0,  0,  0,
   0,  0,  0,  0,  0,  0,  0,  0,  0,
   0,  0,  0,  0,  0,  0,  0,  0,  0,
   0,  0,  0,  0,  0,  0,  0,  0,  0,
   0,  0,  0,  0,  0,  0,  0,  0,  0,
  10, 10, 10, 10, 10, 10, 10, 10, 10,
  10, 10, 10, 10, 10, 10, 10, 10, 10,
  10, 10, 10, 10, 10, 10, 10, 10, 10,
];

/// Evaluate the position from Red's perspective (positive = good for Red).
int evaluate(List<int> board) {
  int score = 0;

  for (int i = 0; i < 90; i++) {
    final piece = board[i];
    if (piece == 0) continue;

    final isRed = piece <= 10;
    final typeIdx = isRed ? piece - 1 : piece - 11;
    final type = PieceType.values[typeIdx];
    final materialValue = pieceValues[type]!;

    // Position value
    int posValue = 0;
    if (!isRed) {
      // Flip index for black (mirror vertically)
      final row = 9 - (i ~/ 9);
      final col = i % 9;
      final flippedIdx = row * 9 + col;
      switch (type) {
        case PieceType.chariot: posValue = chariotPst[flippedIdx];
        case PieceType.horse: posValue = horsePst[flippedIdx];
        case PieceType.cannon: posValue = cannonPst[flippedIdx];
        default: posValue = 0;
      }
    } else {
      switch (type) {
        case PieceType.chariot: posValue = chariotPst[i];
        case PieceType.horse: posValue = horsePst[i];
        case PieceType.cannon: posValue = cannonPst[i];
        default: posValue = 0;
      }
    }

    final total = materialValue + posValue;
    score += isRed ? total : -total;
  }

  return score;
}
