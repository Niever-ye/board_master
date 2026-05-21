// Simple Go patterns to improve playout quality.
// Each pattern returns a preferred move index or -1 if no match.

class GoPatterns {
  /// Check if any opponent group is in atari (exactly 1 liberty).
  /// If so, either capture it or save own group.
  static int? findAtariResponse(
      List<int> board, int size, int color) {
    final opp = color == 1 ? 2 : 1;

    // Find opponent groups in atari and capture them
    for (int i = 0; i < board.length; i++) {
      if (board[i] != opp) continue;
      final group = _findGroup(board, size, i, opp);
      if (group == null) continue;
      final libs = _groupLiberties(board, size, group);
      if (libs.length == 1) {
        // Capture!
        return libs.first;
      }
    }

    return null;
  }

  /// Find an empty point adjacent to own stone that extends.
  static int? findExtension(
      List<int> board, int size, int color) {
    // Prefer moves near the edge of own territory
    final candidates = <int>[];
    for (int i = 0; i < board.length; i++) {
      if (board[i] != 0) continue;

      int ownAdj = 0;
      int oppAdj = 0;
      for (final nb in _neighbors(i, size)) {
        if (board[nb] == color) ownAdj++;
        if (board[nb] == (color == 1 ? 2 : 1)) oppAdj++;
      }

      // Prefer moves adjacent to own stones, not fully surrounded by opponent
      if (ownAdj >= 1 && oppAdj <= 1) {
        candidates.add(i);
      }
    }
    if (candidates.isNotEmpty) {
      candidates.shuffle();
      return candidates.first;
    }
    return null;
  }

  static Set<int>? _findGroup(
      List<int> board, int size, int start, int color) {
    if (board[start] != color) return null;
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

  static Set<int> _groupLiberties(
      List<int> board, int size, Set<int> group) {
    final libs = <int>{};
    for (final idx in group) {
      for (final nb in _neighbors(idx, size)) {
        if (board[nb] == 0) libs.add(nb);
      }
    }
    return libs;
  }

  static List<int> _neighbors(int idx, int size) {
    final r = idx ~/ size;
    final c = idx % size;
    final result = <int>[];
    if (r > 0) result.add(idx - size);
    if (r < size - 1) result.add(idx + size);
    if (c > 0) result.add(idx - 1);
    if (c < size - 1) result.add(idx + 1);
    return result;
  }
}
