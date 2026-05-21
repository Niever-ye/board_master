import 'package:board_master/core/types.dart';

class ChessMove {
  final int fromRow;
  final int fromCol;
  final int toRow;
  final int toCol;
  final int piece;     // encoded piece value
  final int captured;  // captured piece value, 0 if none
  final int moveNumber;

  const ChessMove({
    required this.fromRow,
    required this.fromCol,
    required this.toRow,
    required this.toCol,
    required this.piece,
    this.captured = 0,
    required this.moveNumber,
  });

  ChessColor get color => pieceColor(piece);
  PieceType get type => pieceTypeFromValue(piece);

  static ChessColor pieceColor(int value) =>
      value > 10 ? ChessColor.black : ChessColor.red;

  static PieceType pieceTypeFromValue(int value) {
    final idx = value > 10 ? value - 11 : value - 1;
    return PieceType.values[idx];
  }

  static int encodePiece(ChessColor color, PieceType type) {
    final base = color == ChessColor.black ? 11 : 1;
    return base + type.index;
  }
}
