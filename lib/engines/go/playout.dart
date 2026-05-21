import 'dart:math';
import 'package:board_master/engines/go/patterns.dart';

/// Perform a light random playout from the given position.
/// Returns 1.0 if black wins, 0.0 if white wins.
double playout(
  List<int> board,
  int size,
  int currentColor,
  int koPoint,
  bool usePatterns,
) {
  final simBoard = List<int>.from(board);
  int simKo = koPoint;
  int simColor = currentColor;
  int passes = 0;

  final rng = Random();

  // Max moves to prevent infinite loops
  for (int move = 0; move < size * size * 2; move++) {
    // Generate legal moves
    final legalMoves = _generateLegalMoves(simBoard, size, simColor, simKo);
    if (legalMoves.isEmpty) {
      passes++;
      if (passes >= 2) break;
      simColor = simColor == 1 ? 2 : 1;
      simKo = -1;
      continue;
    }

    passes = 0;

    int chosen;
    if (usePatterns) {
      final atari = GoPatterns.findAtariResponse(simBoard, size, simColor);
      if (atari != null && legalMoves.contains(atari)) {
        chosen = atari;
      } else {
        final ext = GoPatterns.findExtension(simBoard, size, simColor);
        if (ext != null && legalMoves.contains(ext) && rng.nextDouble() < 0.7) {
          chosen = ext;
        } else {
          chosen = legalMoves[rng.nextInt(legalMoves.length)];
        }
      }
    } else {
      chosen = legalMoves[rng.nextInt(legalMoves.length)];
    }

    // Apply move
    final result = _applyMove(simBoard, size, chosen, simColor);
    simBoard.setAll(0, result.board);
    simKo = result.koPoint;
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
      final s = simBoard[idx];
      if (s == 1) {
        blackScore += 1;
        visited.add(idx);
      } else if (s == 2) {
        whiteScore += 1;
        visited.add(idx);
      } else {
        final territory = _floodFill(simBoard, size, idx);
        visited.addAll(territory);
        bool tB = false, tW = false;
        for (final ti in territory) {
          for (final nb in _neighbors(ti, size)) {
            if (simBoard[nb] == 1) tB = true;
            if (simBoard[nb] == 2) tW = true;
          }
        }
        if (tB && !tW) blackScore += territory.length;
        if (tW && !tB) whiteScore += territory.length;
      }
    }
  }

  return blackScore > whiteScore ? 1.0 : 0.0;
}

List<int> _generateLegalMoves(
    List<int> board, int size, int color, int koPoint) {
  final legal = <int>[];
  for (int i = 0; i < board.length; i++) {
    if (board[i] != 0) continue;
    if (i == koPoint) continue;
    if (_isLegal(board, size, i, color)) {
      legal.add(i);
    }
  }
  return legal;
}

bool _isLegal(List<int> board, int size, int index, int color) {
  // Simplified: check suicide and basic capture
  final simBoard = List<int>.from(board);
  simBoard[index] = color;

  final oppColor = color == 1 ? 2 : 1;

  for (final nb in _neighbors(index, size)) {
    if (simBoard[nb] == oppColor) {
      final g = _findGroup(simBoard, size, nb, oppColor);
      if (g != null && _countLiberties(simBoard, size, g) == 0) {
        for (final gi in g) {
          simBoard[gi] = 0;
        }
      }
    }
  }

  // Check own group has liberties (not suicide)
  final ownGroup = _findGroup(simBoard, size, index, color);
  if (ownGroup != null && _countLiberties(simBoard, size, ownGroup) == 0) {
    return false;
  }

  return true;
}

_ApplyResult _applyMove(List<int> board, int size, int index, int color) {
  final newBoard = List<int>.from(board);
  newBoard[index] = color;
  final oppColor = color == 1 ? 2 : 1;

  int captured = 0;
  int newKo = -1;

  for (final nb in _neighbors(index, size)) {
    if (newBoard[nb] == oppColor) {
      final g = _findGroup(newBoard, size, nb, oppColor);
      if (g != null && _countLiberties(newBoard, size, g) == 0) {
        captured += g.length;
        for (final gi in g) {
          newBoard[gi] = 0;
        }
        if (captured == 1 && g.length == 1) {
          final ownG = _findGroup(newBoard, size, index, color);
          if (ownG != null && _countLiberties(newBoard, size, ownG) == 1) {
            newKo = g.first;
          }
        }
      }
    }
  }

  return _ApplyResult(newBoard, newKo);
}

class _ApplyResult {
  final List<int> board;
  final int koPoint;
  _ApplyResult(this.board, this.koPoint);
}

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
