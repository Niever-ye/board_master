import 'package:board_master/core/types.dart';
import 'package:board_master/engines/engine_interface.dart';

/// Gomoku AI using threat-aware alpha-beta search.
///
/// Candidate moves are scored for both offense (our patterns) and defense
/// (opponent patterns) so that blocking threats ranks as high as making them.
class GomokuEngine implements EngineInterface {

  @override
  Future<EngineResult> findBestMove(
    List<int> board,
    int size,
    int currentColor,
    int koPoint,
    Difficulty difficulty,
  ) async {
    int depth;
    int candidateWidth;
    switch (difficulty) {
      case Difficulty.easy:
        depth = 2;
        candidateWidth = 15;
        break;
      case Difficulty.medium:
        depth = 4;
        candidateWidth = 22;
        break;
      case Difficulty.hard:
        depth = 6;
        candidateWidth = 30;
        break;
    }

    final opp = _oppColor(currentColor);

    // Check immediate win first
    for (int i = 0; i < board.length; i++) {
      if (board[i] != 0) continue;
      board[i] = currentColor;
      final w = _checkWinFast(board, size);
      board[i] = 0;
      if (w == currentColor) {
        return EngineResult(row: i ~/ size, col: i % size);
      }
    }

    // Collect threat-aware candidates
    final candidates = _threatRankedCandidates(
        board, size, currentColor, opp, candidateWidth);
    if (candidates.isEmpty) return const EngineResult(isPass: true);

    int bestIdx = candidates.first;
    int bestScore = -99999999;
    int alpha = -99999999;
    final beta = 99999999;

    for (final idx in candidates) {
      board[idx] = currentColor;
      final score = -_negamax(board, size, opp, depth - 1, -beta, -alpha,
          candidateWidth);
      board[idx] = 0;

      if (score > bestScore) {
        bestScore = score;
        bestIdx = idx;
      }
      if (score > alpha) alpha = score;
    }

    return EngineResult(row: bestIdx ~/ size, col: bestIdx % size);
  }

  /// Score every empty cell by max(offense, defense), return top N.
  List<int> _threatRankedCandidates(
      List<int> board, int size, int self, int opp, int limit) {
    final scores = <int, int>{};

    for (int i = 0; i < board.length; i++) {
      if (board[i] != 0) continue;

      // Offensive score: how good if WE place here
      board[i] = self;
      final offScore = _patternsAt(board, size, i, self);
      board[i] = 0;

      // Defensive score: how good if OPPONENT places here (we MUST block)
      board[i] = opp;
      final defScore = _patternsAt(board, size, i, opp);
      board[i] = 0;

      // Threat-aware score: prioritize must-block positions
      int threatScore;
      if (defScore >= 10000) {
        // Opponent would make open-4 here → must block
        threatScore = 200000 + defScore;
      } else if (offScore >= 10000) {
        // We would make open-4 here → must play
        threatScore = 100000 + offScore;
      } else if (defScore >= 1000) {
        // Opponent would make open-3 → important to block
        threatScore = 50000 + defScore;
      } else {
        threatScore = offScore > defScore ? offScore : defScore;
      }

      // Center proximity bonus (small)
      final r = i ~/ size;
      final c = i % size;
      final center = size ~/ 2;
      threatScore -= ((r - center).abs() + (c - center).abs());

      scores[i] = threatScore;
    }

    final list = scores.keys.toList();
    list.sort((a, b) => scores[b]!.compareTo(scores[a]!));
    return list.length > limit ? list.sublist(0, limit) : list;
  }

  int _negamax(List<int> board, int size, int color, int depth, int alpha,
      int beta, int candidateWidth) {
    final opp = _oppColor(color);

    // Check if previous move won
    final w = _checkWinFast(board, size);
    if (w == opp) return 100000 + depth;
    if (w == color) return -100000 - depth;

    if (depth == 0) {
      return _evaluate(board, size, color);
    }

    final moves = _threatNearbyMoves(board, size, color, opp, candidateWidth);
    if (moves.isEmpty) return 0;

    int best = -99999999;
    for (final idx in moves) {
      board[idx] = color;
      final score =
          -_negamax(board, size, opp, depth - 1, -beta, -alpha, candidateWidth);
      board[idx] = 0;

      if (score > best) best = score;
      if (score > alpha) alpha = score;
      if (alpha >= beta) break;
    }
    return best;
  }

  /// Generate candidate moves near existing stones, scored by max(self, opp).
  List<int> _threatNearMoves(
      List<int> board, int size, int self, int opp, int limit) {
    final near = <int>{};

    for (int i = 0; i < board.length; i++) {
      if (board[i] != 0) {
        // Check 2-cell radius for better threat detection
        final r = i ~/ size;
        final c = i % size;
        for (int dr = -2; dr <= 2; dr++) {
          for (int dc = -2; dc <= 2; dc++) {
            if (dr == 0 && dc == 0) continue;
            final nr = r + dr;
            final nc = c + dc;
            if (nr >= 0 && nr < size && nc >= 0 && nc < size) {
              final ni = nr * size + nc;
              if (board[ni] == 0) near.add(ni);
            }
          }
        }
      }
    }

    if (near.isEmpty) {
      return [size * (size ~/ 2) + (size ~/ 2)];
    }

    // Score by max(self pattern, opponent pattern)
    final list = near.toList();
    list.sort((a, b) {
      board[a] = self;
      final sa = _patternsAt(board, size, a, self);
      board[a] = opp;
      final oa = _patternsAt(board, size, a, opp);
      board[a] = 0;

      board[b] = self;
      final sb = _patternsAt(board, size, b, self);
      board[b] = opp;
      final ob = _patternsAt(board, size, b, opp);
      board[b] = 0;

      final ma = sa > oa ? sa : oa;
      final mb = sb > ob ? sb : ob;
      return mb.compareTo(ma);
    });

    return list.length > limit ? list.sublist(0, limit) : list;
  }

  /// Board evaluation from `color`'s perspective.
  /// Each stone is visited once; _patternsAt counts the full line from it.
  /// Adjacent same-color stones in the same line will also be counted, but
  /// this is consistent between sides and acts as an implicit weight.
  int _evaluate(List<int> board, int size, int color) {
    int score = 0;
    final seen = <int>{};

    for (int i = 0; i < board.length; i++) {
      if (board[i] == 0 || seen.contains(i)) continue;
      seen.add(i);
      final c = board[i];
      final multiplier = c == color ? 1 : -1;
      score += multiplier * _patternsAt(board, size, i, c);
    }
    return score;
  }

  int _lineScore(int count, int openEnds) {
    if (count >= 5) return 100000;
    if (count == 4) {
      if (openEnds == 2) return 25000;
      if (openEnds == 1) return 3000;
      return 0;
    }
    if (count == 3) {
      if (openEnds == 2) return 2000;
      if (openEnds == 1) return 200;
      return 0;
    }
    if (count == 2) {
      if (openEnds == 2) return 200;
      if (openEnds == 1) return 15;
      return 0;
    }
    if (count == 1) {
      if (openEnds == 2) return 10;
      if (openEnds == 1) return 1;
      return 0;
    }
    return 0;
  }

  int _checkWinFast(List<int> board, int size) {
    const dirs = [(0, 1), (1, 0), (1, 1), (1, -1)];
    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        final idx = r * size + c;
        final color = board[idx];
        if (color == 0) continue;
        for (final (dr, dc) in dirs) {
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

  /// Pattern score for the stone at `idx` (used for quick candidate scoring).
  int _patternsAt(List<int> board, int size, int idx, int color) {
    final r = idx ~/ size;
    final c = idx % size;
    const dirs = [(0, 1), (1, 0), (1, 1), (1, -1)];
    int total = 0;

    for (final (dr, dc) in dirs) {
      int count = 1;
      int openEnds = 0;

      int pr = r + dr, pc = c + dc;
      while (pr >= 0 && pr < size && pc >= 0 && pc < size &&
          board[pr * size + pc] == color) {
        count++;
        pr += dr;
        pc += dc;
      }
      if (pr >= 0 && pr < size && pc >= 0 && pc < size &&
          board[pr * size + pc] == 0) openEnds++;

      pr = r - dr;
      pc = c - dc;
      while (pr >= 0 && pr < size && pc >= 0 && pc < size &&
          board[pr * size + pc] == color) {
        count++;
        pr -= dr;
        pc -= dc;
      }
      if (pr >= 0 && pr < size && pc >= 0 && pc < size &&
          board[pr * size + pc] == 0) openEnds++;

      total += _lineScore(count, openEnds);
    }
    return total;
  }

  int _oppColor(int c) => c == 1 ? 2 : 1;
}
