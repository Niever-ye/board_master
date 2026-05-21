import 'package:board_master/core/types.dart';
import 'package:board_master/engines/chess/evaluation.dart';
import 'package:board_master/engines/chess/move_gen.dart';
import 'package:board_master/engines/chess/move_ordering.dart';
import 'package:board_master/engines/chess/transposition_table.dart';
import 'package:board_master/models/chess/chess_position.dart';
import 'package:board_master/rules/chess_rules.dart';

class SearchResult {
  final int score;
  final int bestFrom;
  final int bestTo;

  const SearchResult({
    required this.score,
    required this.bestFrom,
    required this.bestTo,
  });
}

class SearchParams {
  final List<int> board;
  final ChessColor aiColor;
  final int maxDepth;
  final double timeLimitSec;
  final TranspositionTable tt;

  SearchParams({
    required this.board,
    required this.aiColor,
    required this.maxDepth,
    required this.timeLimitSec,
    required this.tt,
  });
}

SearchResult search(SearchParams params) {
  final startTime = DateTime.now();
  final killerMoves = List.generate(64, (_) => <int>[]);
  final historyTable = List.generate(18, (_) => List.filled(90, 0));

  int bestFrom = -1;
  int bestTo = -1;
  int bestScore = 0;

  // Iterative deepening
  for (int depth = 1; depth <= params.maxDepth; depth++) {
    final elapsed = DateTime.now().difference(startTime).inMilliseconds / 1000.0;
    if (elapsed > params.timeLimitSec * 0.8) break;

    int alpha = -100000;
    int beta = 100000;

    // Generate and order moves
    final moves = generateMoves(params.board, params.aiColor);
    if (moves.isEmpty) break;

    // Score and sort moves
    final scored = moves.map((m) {
      final s = scoreMove(
        board: params.board,
        fromIdx: m.$1,
        toIdx: m.$2,
        ttMoveFrom: bestFrom,
        ttMoveTo: bestTo,
        killerMoves: killerMoves,
        historyTable: historyTable,
        depth: depth,
      );
      return (m.$1, m.$2, s);
    }).toList();
    scored.sort((a, b) => b.$3.compareTo(a.$3));

    int currentBestFrom = scored.first.$1;
    int currentBestTo = scored.first.$2;
    bool found = false;

    for (final (fromIdx, toIdx, _) in scored) {
      final newBoard = _makeMove(params.board, fromIdx, toIdx);
      final oppColor = params.aiColor == ChessColor.red
          ? ChessColor.black
          : ChessColor.red;

      // Null-move pruning: skip if time exceeded
      final e = DateTime.now().difference(startTime).inMilliseconds / 1000.0;
      if (e > params.timeLimitSec) break;

      final score = -_negamax(
        newBoard,
        depth - 1,
        -beta,
        -alpha,
        oppColor,
        startTime,
        params.timeLimitSec,
        killerMoves,
        historyTable,
        params.tt,
      );

      if (score > alpha) {
        alpha = score;
        currentBestFrom = fromIdx;
        currentBestTo = toIdx;
        found = true;
      }
    }

    if (found) {
      bestFrom = currentBestFrom;
      bestTo = currentBestTo;
      bestScore = alpha;
    }
  }

  // If no move found, pick first legal move
  if (bestFrom == -1) {
    final moves = generateMoves(params.board, params.aiColor);
    if (moves.isNotEmpty) {
      bestFrom = moves.first.$1;
      bestTo = moves.first.$2;
    }
  }

  return SearchResult(score: bestScore, bestFrom: bestFrom, bestTo: bestTo);
}

int _negamax(
  List<int> board,
  int depth,
  int alpha,
  int beta,
  ChessColor color,
  DateTime startTime,
  double timeLimit,
  List<List<int>> killerMoves,
  List<List<int>> historyTable,
  TranspositionTable tt,
) {
  // Time check
  final e = DateTime.now().difference(startTime).inMilliseconds / 1000.0;
  if (e > timeLimit) return 0;

  // TT probe
  final hash = Zobrist.hash(board);
  final entry = tt.probe(hash);
  if (entry != null && entry.depth >= depth) {
    if (entry.flag == 0) return entry.score;
    if (entry.flag == 1 && entry.score >= beta) return entry.score;
    if (entry.flag == 2 && entry.score <= alpha) return entry.score;
  }

  // Check for checkmate/stalemate
  if (_isCheckmate(board, color)) return -99990 - (20 - depth);
  if (_isStalemate(board, color)) return -99980;

  if (depth <= 0) {
    return _quiescence(board, alpha, beta, color, startTime, timeLimit, 4);
  }

  // Null-move pruning
  if (depth >= 3 && !_isInCheck(board, color)) {
    final oppColor = color == ChessColor.red ? ChessColor.black : ChessColor.red;
    final nullScore = -_negamax(board, depth - 3, -beta, -beta + 1, oppColor,
        startTime, timeLimit, killerMoves, historyTable, tt);
    if (nullScore >= beta) return beta;
  }

  final moves = generateMoves(board, color);
  if (moves.isEmpty) {
    // No legal moves
    if (_isInCheck(board, color)) return -99990 - (20 - depth); // checkmate
    return 0; // stalemate
  }

  // Score and sort
  final scored = moves.map((m) {
    final s = scoreMove(
      board: board, fromIdx: m.$1, toIdx: m.$2,
      ttMoveFrom: entry?.bestFrom ?? -1, ttMoveTo: entry?.bestTo ?? -1,
      killerMoves: killerMoves, historyTable: historyTable, depth: depth,
    );
    return (m.$1, m.$2, s);
  }).toList();
  scored.sort((a, b) => b.$3.compareTo(a.$3));

  int bestScore = -100000;
  int bestFrom = -1;
  int bestTo = -1;
  int flag = 2; // UPPER_BOUND

  for (int i = 0; i < scored.length; i++) {
    final (fromIdx, toIdx, _) = scored[i];
    final newBoard = _makeMove(board, fromIdx, toIdx);
    final oppColor = color == ChessColor.red ? ChessColor.black : ChessColor.red;

    // Late move reduction
    int newDepth = depth - 1;
    if (i >= 4 && depth >= 3 && board[toIdx] == 0) {
      newDepth = depth - 2;
    }

    int score = -_negamax(newBoard, newDepth, -beta, -alpha, oppColor,
        startTime, timeLimit, killerMoves, historyTable, tt);

    // Re-search if reduced search beat alpha
    if (newDepth < depth - 1 && score > alpha) {
      score = -_negamax(newBoard, depth - 1, -beta, -alpha, oppColor,
          startTime, timeLimit, killerMoves, historyTable, tt);
    }

    if (score > bestScore) {
      bestScore = score;
      bestFrom = fromIdx;
      bestTo = toIdx;
    }

    if (score >= beta) {
      // Store killer move
      if (board[toIdx] == 0) {
        storeKillerMove(killerMoves, depth, fromIdx, toIdx);
      }
      // Store history
      historyTable[board[fromIdx]][toIdx] += depth * depth;

      // TT store (lower bound)
      tt.store(TTEntry(
        hash: hash, depth: depth, score: score, flag: 1,
        bestFrom: fromIdx, bestTo: toIdx,
      ));
      return beta;
    }

    if (score > alpha) {
      alpha = score;
      flag = 0; // EXACT
    }
  }

  // TT store
  tt.store(TTEntry(
    hash: hash, depth: depth, score: bestScore, flag: flag,
    bestFrom: bestFrom, bestTo: bestTo,
  ));

  return bestScore;
}

int _quiescence(
  List<int> board,
  int alpha,
  int beta,
  ChessColor color,
  DateTime startTime,
  double timeLimit,
  int maxDepth,
) {
  final e = DateTime.now().difference(startTime).inMilliseconds / 1000.0;
  if (e > timeLimit) return 0;

  final standPat = color == ChessColor.red
      ? evaluate(board)
      : -evaluate(board);

  if (standPat >= beta) return beta;
  if (standPat > alpha) alpha = standPat;

  if (maxDepth <= 0) return alpha;

  final captures = generateCaptures(board, color);
  if (captures.isEmpty) return alpha;

  // Score captures for ordering
  final scoredCaps = captures.map((m) {
    final victim = board[m.$2];
    final attacker = board[m.$1];
    final victimVal = _captureValue(victim);
    final attackerVal = _captureValue(attacker);
    return (m.$1, m.$2, victimVal * 10 - attackerVal);
  }).toList();
  scoredCaps.sort((a, b) => b.$3.compareTo(a.$3));

  for (final (fromIdx, toIdx, _) in scoredCaps) {
    // SEE-like pruning: skip losing captures in quiescence
    final victim = board[toIdx];
    final attacker = board[fromIdx];
    if (_captureValue(victim) < _captureValue(attacker)) continue;

    final newBoard = _makeMove(board, fromIdx, toIdx);
    final oppColor = color == ChessColor.red ? ChessColor.black : ChessColor.red;
    final score = -_quiescence(newBoard, -beta, -alpha, oppColor,
        startTime, timeLimit, maxDepth - 1);

    if (score >= beta) return beta;
    if (score > alpha) alpha = score;
  }

  return alpha;
}

int _captureValue(int piece) {
  if (piece == 0) return 0;
  final typeIdx = piece > 10 ? piece - 11 : piece - 1;
  return pieceValues[PieceType.values[typeIdx]] ?? 0;
}

List<int> _makeMove(List<int> board, int fromIdx, int toIdx) {
  final newBoard = List<int>.from(board);
  newBoard[toIdx] = newBoard[fromIdx];
  newBoard[fromIdx] = 0;
  return newBoard;
}

bool _isInCheck(List<int> board, ChessColor color) {
  final pos = ChessPosition(board: board);
  return ChessRules.isInCheck(pos, color);
}

bool _isCheckmate(List<int> board, ChessColor color) {
  final pos = ChessPosition(board: board);
  return ChessRules.isCheckmate(pos, color);
}

bool _isStalemate(List<int> board, ChessColor color) {
  final pos = ChessPosition(board: board);
  return ChessRules.isStalemate(pos, color);
}
