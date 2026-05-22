/// Lightweight Go move validator for server-side cheating prevention.
class GoValidator {
  /// Check if placing [color] at [index] is legal.
  static bool isLegal(List<int> board, int size, int index, int color) {
    if (board[index] != 0) return false;

    // Temporarily place stone
    board[index] = color;

    final opp = color == 1 ? 2 : 1;

    // Check for captures - if we capture, it's always legal
    for (final nb in _neighbors(index, size)) {
      if (board[nb] == opp) {
        final group = _findGroup(board, size, nb, opp);
        if (group.isNotEmpty && _countLiberties(board, size, group) == 0) {
          board[index] = 0;
          return true;
        }
      }
    }

    // Check own group has liberties (no suicide)
    final ownGroup = _findGroup(board, size, index, color);
    final hasLib = _countLiberties(board, size, ownGroup) > 0;

    board[index] = 0;
    return hasLib;
  }

  static List<int> _neighbors(int idx, int size) {
    final r = idx ~/ size, c = idx % size;
    final nbs = <int>[];
    if (r > 0) nbs.add(idx - size);
    if (r < size - 1) nbs.add(idx + size);
    if (c > 0) nbs.add(idx - 1);
    if (c < size - 1) nbs.add(idx + 1);
    return nbs;
  }

  static Set<int> _findGroup(List<int> board, int size, int start, int color) {
    final group = <int>{};
    final queue = <int>[start];
    group.add(start);
    while (queue.isNotEmpty) {
      final cur = queue.removeAt(0);
      for (final nb in _neighbors(cur, size)) {
        if (board[nb] == color && group.add(nb)) {
          queue.add(nb);
        }
      }
    }
    return group;
  }

  static int _countLiberties(List<int> board, int size, Set<int> group) {
    final libs = <int>{};
    for (final idx in group) {
      for (final nb in _neighbors(idx, size)) {
        if (board[nb] == 0) libs.add(nb);
      }
    }
    return libs.length;
  }
}
