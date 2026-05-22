import 'dart:math';
import 'package:board_master/engines/go/patterns.dart';

/// Perform a fast random playout. Mutates board in-place and restores.
/// Returns 1.0 if black wins, 0.0 if white wins.
/// Uses precomputed [neigh] to avoid per-call list allocations.
double playout(
  List<int> board,
  int size,
  int currentColor,
  int koPoint,
  bool usePatterns,
  List<List<int>> neigh,
) {
  final rng = Random();
  int simColor = currentColor;
  int simKo = koPoint;
  int passes = 0;

  final placedStones = <int>[];
  final capturedStones = <(int, int)>[];

  final maxMoves = size * size;

  for (int move = 0; move < maxMoves; move++) {
    int? chosen = _pickLegalMove(board, size, simColor, simKo, usePatterns, rng, neigh);

    if (chosen == null) {
      passes++;
      if (passes >= 2) break;
      simColor = simColor == 1 ? 2 : 1;
      simKo = -1;
      continue;
    }

    passes = 0;

    final cap = _applyMoveInPlace(board, neigh, chosen, simColor);
    placedStones.add(chosen);
    for (final ci in cap.captured) {
      capturedStones.add((ci, board[ci]));
    }
    simKo = cap.koPoint;
    simColor = simColor == 1 ? 2 : 1;
  }

  // Score: Chinese area scoring
  double blackScore = 0;
  double whiteScore = 0;

  final visited = <int>{};
  final total = size * size;
  for (int i = 0; i < total; i++) {
    if (visited.contains(i)) continue;
    final s = board[i];
    if (s == 1) {
      blackScore += 1;
      visited.add(i);
    } else if (s == 2) {
      whiteScore += 1;
      visited.add(i);
    } else {
      final territory = _floodFill(board, neigh, i);
      visited.addAll(territory);
      bool tB = false, tW = false;
      for (final ti in territory) {
        for (final nb in neigh[ti]) {
          if (board[nb] == 1) tB = true;
          if (board[nb] == 2) tW = true;
        }
      }
      if (tB && !tW) blackScore += territory.length;
      if (tW && !tB) whiteScore += territory.length;
    }
  }

  // Restore board
  for (final idx in placedStones) {
    board[idx] = 0;
  }
  for (final (idx, _) in capturedStones) {
    board[idx] = 0;
  }

  return blackScore > whiteScore ? 1.0 : 0.0;
}

int? _pickLegalMove(List<int> board, int size, int color, int ko,
    bool usePatterns, Random rng, List<List<int>> neigh) {
  final legalMoves = <int>[];

  int? atariTarget;
  int? extTarget;
  if (usePatterns) {
    atariTarget = GoPatterns.findAtariResponse(board, size, color, neigh);
    extTarget = GoPatterns.findExtension(board, size, color, neigh);
  }

  final opp = color == 1 ? 2 : 1;
  final total = size * size;

  for (int i = 0; i < total; i++) {
    if (board[i] != 0 || i == ko) continue;

    final nbs = neigh[i];
    bool nearEmpty = false;
    bool nearOpp = false;
    for (final nb in nbs) {
      if (board[nb] == 0) {
        nearEmpty = true;
      } else if (board[nb] == opp) {
        nearOpp = true;
      }
      if (nearEmpty && nearOpp) break;
    }

    if (nearEmpty) {
      legalMoves.add(i);
    } else if (nearOpp && _isLegalFast(board, neigh, i, color, opp, nbs)) {
      legalMoves.add(i);
    }
  }

  if (legalMoves.isEmpty) return null;

  if (usePatterns) {
    if (atariTarget != null && legalMoves.contains(atariTarget)) {
      return atariTarget;
    }
    if (extTarget != null && legalMoves.contains(extTarget) && rng.nextDouble() < 0.7) {
      return extTarget;
    }
  }

  return legalMoves[rng.nextInt(legalMoves.length)];
}

/// Fast legality check using cached neighbors. Board is NOT copied.
bool _isLegalFast(List<int> board, List<List<int>> neigh, int index, int color,
    int opp, List<int> nbs) {
  // Check capture
  for (final nb in nbs) {
    if (board[nb] == opp) {
      final g = _findGroup(board, neigh, nb, opp);
      if (g != null && _countLiberties(board, neigh, g) == 1) {
        return true;
      }
    }
  }

  // Check own liberties (place temporarily)
  board[index] = color;
  bool hasLib = false;
  for (final nb in nbs) {
    if (board[nb] == 0) {
      hasLib = true;
      break;
    }
    if (board[nb] == color) {
      final g = _findGroup(board, neigh, nb, color);
      if (g != null && _countLiberties(board, neigh, g) > 0) {
        hasLib = true;
        break;
      }
    }
  }
  board[index] = 0;
  return hasLib;
}

class _CaptureResult {
  final int koPoint;
  final List<int> captured;
  _CaptureResult(this.koPoint, this.captured);
}

_CaptureResult _applyMoveInPlace(
    List<int> board, List<List<int>> neigh, int index, int color) {
  board[index] = color;
  final opp = color == 1 ? 2 : 1;
  final captured = <int>[];
  int newKo = -1;

  for (final nb in neigh[index]) {
    if (board[nb] == opp) {
      final g = _findGroup(board, neigh, nb, opp);
      if (g != null && _countLiberties(board, neigh, g) == 0) {
        for (final gi in g) {
          captured.add(gi);
          board[gi] = 0;
        }
        if (g.length == 1) newKo = g.first;
      }
    }
  }

  return _CaptureResult(newKo, captured);
}

Set<int>? _findGroup(
    List<int> board, List<List<int>> neigh, int start, int color) {
  if (board[start] != color) return null;
  final group = <int>{};
  final queue = <int>[start];
  group.add(start);
  while (queue.isNotEmpty) {
    final cur = queue.removeAt(0);
    for (final nb in neigh[cur]) {
      if (board[nb] == color && group.add(nb)) {
        queue.add(nb);
      }
    }
  }
  return group;
}

int _countLiberties(List<int> board, List<List<int>> neigh, Set<int> group) {
  final libs = <int>{};
  for (final idx in group) {
    for (final nb in neigh[idx]) {
      if (board[nb] == 0) libs.add(nb);
    }
  }
  return libs.length;
}

Set<int> _floodFill(List<int> board, List<List<int>> neigh, int start) {
  final territory = <int>{};
  final queue = <int>[start];
  territory.add(start);
  while (queue.isNotEmpty) {
    final cur = queue.removeAt(0);
    for (final nb in neigh[cur]) {
      if (board[nb] == 0 && territory.add(nb)) {
        queue.add(nb);
      }
    }
  }
  return territory;
}