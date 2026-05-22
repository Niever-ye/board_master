import 'dart:math';
import 'package:board_master/engines/go/patterns.dart';

/// Perform a fast random playout. Mutates board in-place and restores.
/// Returns 1.0 if black wins, 0.0 if white wins.
double playout(
  List<int> board,
  int size,
  int currentColor,
  int koPoint,
  bool usePatterns,
) {
  final rng = Random();
  int simColor = currentColor;
  int simKo = koPoint;
  int passes = 0;

  // Track placed stones so we can restore the board after playout
  final placedStones = <int>[];
  final capturedStones = <(int, int)>[]; // (index, originalColor)

  // Max moves — one full board fill should be more than enough
  final maxMoves = size * size;

  for (int move = 0; move < maxMoves; move++) {
    // Find a legal move (single pass, no board copy)
    int? chosen = _pickLegalMove(board, size, simColor, simKo, usePatterns, rng);

    if (chosen == null) {
      passes++;
      if (passes >= 2) break;
      simColor = simColor == 1 ? 2 : 1;
      simKo = -1;
      continue;
    }

    passes = 0;

    // Apply move in-place
    final captureResult = _applyMoveInPlace(board, size, chosen, simColor);
    placedStones.add(chosen);
    for (final cap in captureResult.captured) {
      capturedStones.add((cap, board[cap])); // saved for restore
    }
    simKo = captureResult.koPoint;
    simColor = simColor == 1 ? 2 : 1;
  }

  // Score: Chinese area scoring (simplified)
  double blackScore = 0;
  double whiteScore = 0;

  final visited = <int>{};
  for (int r = 0; r < size; r++) {
    for (int c = 0; c < size; c++) {
      final idx = r * size + c;
      if (visited.contains(idx)) continue;
      final s = board[idx];
      if (s == 1) {
        blackScore += 1;
        visited.add(idx);
      } else if (s == 2) {
        whiteScore += 1;
        visited.add(idx);
      } else {
        final territory = _floodFill(board, size, idx);
        visited.addAll(territory);
        bool tB = false, tW = false;
        for (final ti in territory) {
          for (final nb in _neighbors(ti, size)) {
            if (board[nb] == 1) tB = true;
            if (board[nb] == 2) tW = true;
          }
        }
        if (tB && !tW) blackScore += territory.length;
        if (tW && !tB) whiteScore += territory.length;
      }
    }
  }

  // Restore board (remove placed stones, restore captures)
  for (final idx in placedStones) {
    board[idx] = 0;
  }
  for (final (idx, color) in capturedStones) {
    board[idx] = color;
  }

  return blackScore > whiteScore ? 1.0 : 0.0;
}

/// Pick a single legal move without copying the board.
int? _pickLegalMove(List<int> board, int size, int color, int ko,
    bool usePatterns, Random rng) {
  // Collect legal moves on the fly
  final legalMoves = <int>[];

  // Try pattern moves first (check only those indices)
  int? atariTarget;
  int? extTarget;
  if (usePatterns) {
    atariTarget = GoPatterns.findAtariResponse(board, size, color);
    extTarget = GoPatterns.findExtension(board, size, color);
  }

  for (int i = 0; i < board.length; i++) {
    if (board[i] != 0) continue;
    if (i == ko) continue;

    // Fast check: any empty neighbor means it's legal (not suicide)
    final neighbors = _neighbors(i, size);
    bool nearEmpty = false;
    bool nearOpp = false;
    for (final nb in neighbors) {
      if (board[nb] == 0) {
        nearEmpty = true;
      } else if (board[nb] == _oppColor(color)) {
        nearOpp = true;
      }
      if (nearEmpty && nearOpp) break;
    }

    if (nearEmpty) {
      legalMoves.add(i);
      continue;
    }

    // Only check full legality for moves that might be suicide or capture-only
    if (nearOpp && _isLegalFast(board, size, i, color, neighbors)) {
      legalMoves.add(i);
    }
  }

  if (legalMoves.isEmpty) return null;

  // Pattern-guided selection
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

/// Fast legality check — NOT copying the board. Uses known neighbors.
bool _isLegalFast(List<int> board, int size, int index, int color,
    List<int> neighbors) {
  final oppColor = _oppColor(color);

  // Check if we capture any opponent group (count liberties before placing)
  for (final nb in neighbors) {
    if (board[nb] == oppColor) {
      final g = _findGroup(board, size, nb, oppColor);
      if (g != null && _countLiberties(board, size, g) == 1) {
        return true; // capture makes it legal
      }
    }
  }

  // Check for own liberties (temporarily place stone)
  board[index] = color;
  int ownLibs = 0;
  for (final nb in neighbors) {
    if (board[nb] == 0) {
      ownLibs++;
      if (ownLibs > 0) break;
    } else if (board[nb] == color) {
      final g = _findGroup(board, size, nb, color);
      if (g != null) {
        ownLibs += _countLiberties(board, size, g);
        if (ownLibs > 0) break;
      }
    }
  }
  board[index] = 0;
  return ownLibs > 0;
}

class _CaptureResult {
  final int koPoint;
  final List<int> captured;
  _CaptureResult(this.koPoint, this.captured);
}

/// Apply a move in-place on the board. Returns capture info for undo.
_CaptureResult _applyMoveInPlace(List<int> board, int size, int index, int color) {
  board[index] = color;
  final oppColor = _oppColor(color);
  final captured = <int>[];
  int newKo = -1;

  for (final nb in _neighbors(index, size)) {
    if (board[nb] == oppColor) {
      final g = _findGroup(board, size, nb, oppColor);
      if (g != null && _countLiberties(board, size, g) == 0) {
        for (final gi in g) {
          captured.add(gi);
          board[gi] = 0;
        }
        if (g.length == 1) {
          newKo = g.first;
        }
      }
    }
  }

  return _CaptureResult(newKo, captured);
}

int _oppColor(int color) => color == 1 ? 2 : 1;

Set<int>? _findGroup(List<int> board, int size, int start, int color) {
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

int _countLiberties(List<int> board, int size, Set<int> group) {
  final libs = <int>{};
  for (final idx in group) {
    for (final nb in _neighbors(idx, size)) {
      if (board[nb] == 0) libs.add(nb);
    }
  }
  return libs.length;
}

Set<int> _floodFill(List<int> board, int size, int start) {
  final territory = <int>{};
  final queue = <int>[start];
  territory.add(start);
  while (queue.isNotEmpty) {
    final cur = queue.removeAt(0);
    for (final nb in _neighbors(cur, size)) {
      if (board[nb] == 0 && territory.add(nb)) {
        queue.add(nb);
      }
    }
  }
  return territory;
}

List<int> _neighbors(int idx, int size) {
  final r = idx ~/ size;
  final c = idx % size;
  final result = <int>[];
  if (r > 0) result.add(idx - size);
  if (r < size - 1) result.add(idx + size);
  if (c > 0) result.add(idx - 1);
  if (c < size - 1) result.add(idx + 1);
  return result;
}
