/// Simple Go patterns to improve playout quality.
/// Uses precomputed neighbor cache to avoid per-call allocations.
class GoPatterns {
  /// Check if any opponent group is in atari (exactly 1 liberty).
  /// If so, return the liberty to capture it.
  static int? findAtariResponse(
      List<int> board, int size, int color, List<List<int>> neigh) {
    final opp = color == 1 ? 2 : 1;
    final visited = <int>{};

    for (int i = 0; i < board.length; i++) {
      if (board[i] != opp || visited.contains(i)) continue;
      final group = _findGroup(board, neigh, i, opp, visited);
      final libs = _groupLiberties(board, neigh, group);
      if (libs.length == 1) {
        return libs.first;
      }
    }

    return null;
  }

  /// Find an empty point adjacent to own stone that extends.
  static int? findExtension(
      List<int> board, int size, int color, List<List<int>> neigh) {
    final candidates = <int>[];
    final opp = color == 1 ? 2 : 1;
    for (int i = 0; i < board.length; i++) {
      if (board[i] != 0) continue;

      int ownAdj = 0;
      int oppAdj = 0;
      for (final nb in neigh[i]) {
        if (board[nb] == color) ownAdj++;
        if (board[nb] == opp) oppAdj++;
      }

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

  static Set<int> _findGroup(
      List<int> board, List<List<int>> neigh, int start, int color, Set<int> visited) {
    final group = <int>{};
    final queue = <int>[start];
    group.add(start);
    visited.add(start);

    while (queue.isNotEmpty) {
      final cur = queue.removeAt(0);
      for (final nb in neigh[cur]) {
        if (board[nb] == color && group.add(nb)) {
          visited.add(nb);
          queue.add(nb);
        }
      }
    }
    return group;
  }

  static Set<int> _groupLiberties(
      List<int> board, List<List<int>> neigh, Set<int> group) {
    final libs = <int>{};
    for (final idx in group) {
      for (final nb in neigh[idx]) {
        if (board[nb] == 0) libs.add(nb);
      }
    }
    return libs;
  }
}