/// Lightweight Chinese Chess move validator for server-side cheating prevention.
class ChessValidator {
  /// Check if placing [color] at [index] is legal.
  /// For chess, [index] is the destination. The source is determined
  /// from the `from` row+col provided in the message.
  static bool isLegal(List<int> board, int toIndex, int color) {
    // Basic: destination must be empty or opponent
    if (board[toIndex] != 0) {
      final piece = board[toIndex];
      if ((piece >> 3) == color) return false; // own piece
    }
    return true;
  }
}
