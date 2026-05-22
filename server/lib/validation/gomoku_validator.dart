/// Lightweight Gomoku move validator for server-side cheating prevention.
class GomokuValidator {
  static bool isLegal(List<int> board, int index) {
    return board[index] == 0;
  }

  static String? checkWin(List<int> board, int size, int lastRow, int lastCol, int color) {
    const dirs = [(0, 1), (1, 0), (1, 1), (1, -1)];

    for (final (dr, dc) in dirs) {
      int count = 1;
      int r = lastRow + dr, c = lastCol + dc;
      while (r >= 0 && r < size && c >= 0 && c < size &&
          board[r * size + c] == color) {
        count++;
        r += dr;
        c += dc;
      }
      r = lastRow - dr;
      c = lastCol - dc;
      while (r >= 0 && r < size && c >= 0 && c < size &&
          board[r * size + c] == color) {
        count++;
        r -= dr;
        c -= dc;
      }
      if (count >= 5) return color == 1 ? 'black' : 'white';
    }
    return null;
  }
}
