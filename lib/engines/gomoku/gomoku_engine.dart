import 'dart:math';
import 'package:board_master/core/types.dart';
import 'package:board_master/engines/engine_interface.dart';

/// Gomoku AI using pattern-based evaluation with alpha-beta search.
class GomokuEngine implements EngineInterface {
  final _rng = Random();

  @override
  Future<EngineResult> findBestMove(
    List<int> board,
    int size,
    int currentColor,
    int koPoint,
    Difficulty difficulty,
  ) async {
    int depth;
    switch (difficulty) {
      case Difficulty.easy:
        depth = 2;
        break;
      case Difficulty.medium:
        depth = 4;
        break;
      case Difficulty.hard:
        depth = 6;
        break;
    }

    final candidates = _rankedCandidates(board, size, currentColor);
    if (candidates.isEmpty) return const EngineResult(isPass: true);

    int bestIdx = candidates.first;
    int bestScore = -99999999;

    for (final idx in candidates) {
      board[idx] = currentColor;
      final w = _checkWinFast(board, size);
      if (w == currentColor) {
        board[idx] = 0;
        final row = idx ~/ size;
        final col = idx % size;
        return EngineResult(row: row, col: col);
      }

      final score = -_negamax(board, size, _oppColor(currentColor),
          depth - 1, -99999999, 99999999);
      board[idx] = 0;

      if (score > bestScore) {
        bestScore = score;
        bestIdx = idx;
      }
    }

    final row = bestIdx ~/ size;
    final col = bestIdx % size;
    return EngineResult(row: row, col: col);
  }

  List<int> _rankedCandidates(List<int> board, int size, int color) {
    final scores = <int, int>{};
    final center = size ~/ 2;

    for (int i = 0; i < board.length; i++) {
      if (board[i] != 0) continue;
      final r = i ~/ size;
      final c = i % size;

      int h = 0;
      h -= ((r - center).abs() + (c - center).abs()) * 2;

      // Quick pattern score if we place here
      board[i] = color;
      h += _patternsAt(board, size, i, color);
      board[i] = 0;

      scores[i] = h;
    }

    final candidates = scores.keys.toList();
    candidates.sort((a, b) => scores[b]!.compareTo(scores[a]!));
    return candidates.length > 20 ? candidates.sublist(0, 20) : candidates;
  }

  int _negamax(List<int> board, int size, int color, int depth,
      int alpha, int beta) {
    final opp = _oppColor(color);

    // Check if previous move won
    final w = _checkWinFast(board, size);
    if (w == opp) return 100000 + depth; // opponent (who just moved) wins
    if (w == color) return -100000 - depth; // shouldn't happen

    if (depth == 0) {
      return _evaluate(board, size, color);
    }

    final moves = _nearbyMoves(board, size, color);
    if (moves.isEmpty) return 0;

    final limited = moves.length > 12 ? moves.sublist(0, 12) : moves;

    int best = -99999999;
    for (final idx in limited) {
      board[idx] = color;
      final score = -_negamax(board, size, opp, depth - 1, -beta, -alpha);
      board[idx] = 0;

      if (score > best) best = score;
      if (score > alpha) alpha = score;
      if (alpha >= beta) break;
    }
    return best;
  }

  /// Generate candidate moves near existing stones.
  List<int> _nearbyMoves(List<int> board, int size, int color) {
    final near = <int>{};
    final opp = _oppColor(color);

    for (int i = 0; i < board.length; i++) {
      if (board[i] != 0) {
        for (final ni in _neighbors(i, size)) {
          if (board[ni] == 0) near.add(ni);
        }
      }
    }

    if (near.isEmpty) {
      return [size * (size ~/ 2) + (size ~/ 2)]; // center
    }

    // Sort by pattern score for better pruning
    final list = near.toList();
    list.sort((a, b) {
      board[a] = color;
      final sa = _patternsAt(board, size, a, color);
      board[a] = 0;
      board[b] = color;
      final sb = _patternsAt(board, size, b, color);
      board[b] = 0;
      return sb.compareTo(sa);
    });

    return list;
  }

  /// Board evaluation from `color`'s perspective.
  int _evaluate(List<int> board, int size, int color) {
    int score = 0;
    final opp = _oppColor(color);
    final seen = <int>{};

    for (int i = 0; i < board.length; i++) {
      if (board[i] == 0 || seen.contains(i)) continue;
      if (board[i] == color) {
        score += _patternsAt(board, size, i, color);
      } else if (board[i] == opp) {
        score -= _patternsAt(board, size, i, opp);
      }
      seen.add(i);
    }
    return score;
  }

  /// Pattern score for the stone at `idx`.
  int _patternsAt(List<int> board, int size, int idx, int color) {
    final r = idx ~/ size;
    final c = idx % size;
    const dirs = [(0, 1), (1, 0), (1, 1), (1, -1)];
    int total = 0;

    for (final (dr, dc) in dirs) {
      int count = 1;
      int openEnds = 0;

      // Positive direction
      int pr = r + dr, pc = c + dc;
      while (pr >= 0 && pr < size && pc >= 0 && pc < size &&
          board[pr * size + pc] == color) {
        count++;
        pr += dr;
        pc += dc;
      }
      if (pr >= 0 && pr < size && pc >= 0 && pc < size &&
          board[pr * size + pc] == 0) {
        openEnds++;
      }

      // Negative direction
      pr = r - dr;
      pc = c - dc;
      while (pr >= 0 && pr < size && pc >= 0 && pc < size &&
          board[pr * size + pc] == color) {
        count++;
        pr -= dr;
        pc -= dc;
      }
      if (pr >= 0 && pr < size && pc >= 0 && pc < size &&
          board[pr * size + pc] == 0) {
        openEnds++;
      }

      if (count >= 5) {
        total += 100000;
      } else if (count == 4) {
        total += openEnds == 2 ? 10000 : (openEnds == 1 ? 1000 : 0);
      } else if (count == 3) {
        total += openEnds == 2 ? 1000 : (openEnds == 1 ? 100 : 0);
      } else if (count == 2) {
        total += openEnds == 2 ? 100 : (openEnds == 1 ? 10 : 0);
      } else if (count == 1) {
        total += openEnds == 2 ? 10 : (openEnds == 1 ? 1 : 0);
      }
    }
    return total;
  }

  /// Check if anyone has 5 in a row.
  int _checkWinFast(List<int> board, int size) {
    const dirs = [(0, 1), (1, 0), (1, 1), (1, -1)];
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        final idx = r * size + c;
        final color = board[idx];
        if (color == 0) continue;
        for (final (dr, dc) in dirs) {
          // Only check forward direction (avoid double counting)
          int count = 1;
          int pr = r + dr, pc = c + dc;
          while (pr >= 0 && pr < size && pc >= 0 && pc < size &&
              board[pr * size + pc] == color) {
            count++;
            pr += dr;
            pc += dc;
          }
          if (count >= 5) return color;
        }
      }
    }
    return 0;
  }

  int _oppColor(int c) => c == 1 ? 2 : 1;

  List<int> _neighbors(int idx, int size) {
    final r = idx ~/ size;
    final c = idx % size;
    final result = <int>[];
    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final nr = r + dr;
        final nc = c + dc;
        if (nr >= 0 && nr < size && nc >= 0 && nc < size) {
          result.add(nr * size + nc);
        }
      }
    }
    return result;
  }
}
