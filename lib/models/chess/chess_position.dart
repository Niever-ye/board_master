import 'package:board_master/core/types.dart';

/// Board: 10 rows x 9 cols = 90 positions
/// Encoding: 0=empty, 1-7=Red, 11-17=Black
class ChessPosition {
  final List<int> board; // length 90

  const ChessPosition({required this.board});

  factory ChessPosition.initial() {
    final board = List<int>.filled(90, 0);

    // Black pieces (top, rows 0-4)
    board[0 * 9 + 0] = 15;  // Chariot
    board[0 * 9 + 1] = 14;  // Horse
    board[0 * 9 + 2] = 13;  // Elephant
    board[0 * 9 + 3] = 12;  // Advisor
    board[0 * 9 + 4] = 11;  // General
    board[0 * 9 + 5] = 12;  // Advisor
    board[0 * 9 + 6] = 13;  // Elephant
    board[0 * 9 + 7] = 14;  // Horse
    board[0 * 9 + 8] = 15;  // Chariot
    board[2 * 9 + 1] = 16;  // Cannon
    board[2 * 9 + 7] = 16;  // Cannon
    board[3 * 9 + 0] = 17;  // Soldier
    board[3 * 9 + 2] = 17;  // Soldier
    board[3 * 9 + 4] = 17;  // Soldier
    board[3 * 9 + 6] = 17;  // Soldier
    board[3 * 9 + 8] = 17;  // Soldier

    // Red pieces (bottom, rows 5-9)
    board[9 * 9 + 0] = 5;   // Chariot
    board[9 * 9 + 1] = 4;   // Horse
    board[9 * 9 + 2] = 3;   // Elephant
    board[9 * 9 + 3] = 2;   // Advisor
    board[9 * 9 + 4] = 1;   // General
    board[9 * 9 + 5] = 2;   // Advisor
    board[9 * 9 + 6] = 3;   // Elephant
    board[9 * 9 + 7] = 4;   // Horse
    board[9 * 9 + 8] = 5;   // Chariot
    board[7 * 9 + 1] = 6;   // Cannon
    board[7 * 9 + 7] = 6;   // Cannon
    board[6 * 9 + 0] = 7;   // Soldier
    board[6 * 9 + 2] = 7;   // Soldier
    board[6 * 9 + 4] = 7;   // Soldier
    board[6 * 9 + 6] = 7;   // Soldier
    board[6 * 9 + 8] = 7;   // Soldier

    return ChessPosition(board: board);
  }

  int index(int row, int col) => row * 9 + col;
  (int, int) coord(int index) => (index ~/ 9, index % 9);

  int pieceAt(int row, int col) => board[row * 9 + col];

  bool isWithinBounds(int row, int col) =>
      row >= 0 && row < 10 && col >= 0 && col < 9;

  ChessColor? colorAt(int row, int col) {
    final p = board[row * 9 + col];
    if (p == 0) return null;
    return p > 10 ? ChessColor.black : ChessColor.red;
  }

  /// Find the general's position for a given color.
  int findGeneral(ChessColor color) {
    final target = color == ChessColor.red ? 1 : 11;
    for (int i = 0; i < board.length; i++) {
      if (board[i] == target) return i;
    }
    return -1;
  }

  ChessPosition copyWithMove(int fromIdx, int toIdx) {
    final newBoard = List<int>.from(board);
    newBoard[toIdx] = newBoard[fromIdx];
    newBoard[fromIdx] = 0;
    return ChessPosition(board: newBoard);
  }
}
