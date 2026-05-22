import 'dart:math';

import 'package:board_master/core/constants.dart';
import 'package:board_master/core/types.dart';
import 'package:board_master/engines/engine_interface.dart';
import 'package:board_master/engines/go/mcts_node.dart';
import 'package:board_master/engines/go/playout.dart';

/// MCTS Go engine. All board operations are in-place with undo to avoid copies.
/// Neighbor cache is computed once and reused everywhere to eliminate per-call
/// list allocations (was the source of GC freezes with millions of allocations).
class GoEngine implements EngineInterface {
  @override
  Future<EngineResult> findBestMove(
    List<int> board,
    int size,
    int currentColor,
    int koPoint,
    Difficulty difficulty,
  ) async {
    final result = _mctsSearch(
      board: board,
      size: size,
      currentColor: currentColor,
      koPoint: koPoint,
      difficulty: difficulty,
    );
    if (result == -1) return const EngineResult(isPass: true);

    final row = result ~/ size;
    final col = result % size;
    return EngineResult(row: row, col: col);
  }
}

/// A single change to the board, tracked for undo.
class _Change {
  final int index;
  final int oldValue;
  _Change(this.index, this.oldValue);
}

int _mctsSearch({
  required List<int> board,
  required int size,
  required int currentColor,
  required int koPoint,
  required Difficulty difficulty,
}) {
  final rng = Random();

  // Precompute neighbor indices — this is the cache that eliminates
  // billions of list allocations in the MCTS + playout hot path.
  final neigh = _buildNeighborCache(size);

  // Collect legal moves with fast check
  final legalMoves = _fastLegalMoves(board, size, currentColor, koPoint, neigh);
  if (legalMoves.isEmpty) return -1;

  int maxIterations;
  int maxMs;
  double c;

  switch (difficulty) {
    case Difficulty.easy:
      maxIterations = AiConstants.easyIterations;
      maxMs = 2000;
      c = 2.0;
      break;
    case Difficulty.medium:
      maxIterations = AiConstants.mediumIterations;
      maxMs = 6000;
      c = 1.4;
      break;
    case Difficulty.hard:
      maxIterations = AiConstants.hardIterations;
      maxMs = 15000;
      c = 1.2;
      break;
  }

  // Cap for 19x19
  if (size >= 19 && maxIterations > 15000) maxIterations = 15000;
  if (size >= 19 && maxMs > 15000) maxMs = 15000;

  final root = MctsNode(
    moveIndex: -1,
    stonePlayed: currentColor == 1 ? 2 : 1,
    visits: 1,
    unexploredMoves: legalMoves,
  );

  final startTime = DateTime.now();
  int iter = 0;

  // MCTS loop with time budget
  for (; iter < maxIterations; iter++) {
    if (iter % 50 == 0 &&
        DateTime.now().difference(startTime).inMilliseconds > maxMs) {
      break;
    }

    // 1. Selection: walk down the tree, applying moves in-place
    var node = root;
    int simColor = currentColor;
    int simKo = koPoint;
    final undoStack = <_Change>[];

    while (!node.isLeaf && node.isFullyExpanded) {
      node = node.bestChild(c);
      _applyInPlace(board, neigh, node.moveIndex, simColor, undoStack);
      simKo = _captureAndKo(board, neigh, node.moveIndex, simColor, undoStack);
      simColor = simColor == 1 ? 2 : 1;
    }

    // 2. Expansion
    if (!node.isFullyExpanded && node.unexploredMoves.isNotEmpty) {
      final pickIdx = rng.nextInt(node.unexploredMoves.length);
      final moveIdx = node.unexploredMoves.removeAt(pickIdx);

      _applyInPlace(board, neigh, moveIdx, simColor, undoStack);
      simKo = _captureAndKo(board, neigh, moveIdx, simColor, undoStack);

      final newNode = MctsNode(
        moveIndex: moveIdx,
        stonePlayed: simColor,
        parent: node,
      );
      simColor = simColor == 1 ? 2 : 1;

      newNode.unexploredMoves =
          _fastLegalMoves(board, size, simColor, simKo, neigh);
      node.children.add(newNode);
      node = newNode;
    }

    // 3. Simulation (playout — in-place with undo, uses neighbor cache)
    final winner = playout(board, size, simColor, simKo, true, neigh);

    // Undo all selection/expansion moves (reverse order)
    for (int i = undoStack.length - 1; i >= 0; i--) {
      board[undoStack[i].index] = undoStack[i].oldValue;
    }

    // 4. Backpropagation
    MctsNode? backNode = node;
    while (backNode != null) {
      backNode.visits++;
      backNode.wins += winner;
      backNode = backNode.parent;
    }
  }

  final best = root.mostVisitedChild();
  return best.moveIndex;
}

/// Fast collect all legal moves using the precomputed neighbor cache.
List<int> _fastLegalMoves(List<int> board, int size, int color, int ko,
    List<List<int>> neigh) {
  final result = <int>[];
  final oppColor = color == 1 ? 2 : 1;

  for (int i = 0; i < board.length; i++) {
    if (board[i] != 0 || i == ko) continue;

    final nbs = neigh[i];
    bool nearEmpty = false;
    bool nearOpp = false;
    for (final nb in nbs) {
      if (board[nb] == 0) {
        nearEmpty = true;
        break;
      }
      if (board[nb] == oppColor) nearOpp = true;
    }

    if (nearEmpty) {
      result.add(i);
    } else if (nearOpp) {
      if (_isLegalInPlace(board, neigh, i, color)) {
        result.add(i);
      }
    }
  }

  return result;
}

bool _isLegalInPlace(
    List<int> board, List<List<int>> neigh, int index, int color) {
  final oppColor = color == 1 ? 2 : 1;

  for (final nb in neigh[index]) {
    if (board[nb] == oppColor) {
      final g = _findGroup(board, neigh, nb, oppColor);
      if (g != null && _countLiberties(board, neigh, g) == 1) {
        return true;
      }
    }
  }

  board[index] = color;
  bool hasLiberty = false;
  for (final nb in neigh[index]) {
    if (board[nb] == 0) {
      hasLiberty = true;
      break;
    }
    if (board[nb] == color) {
      final g = _findGroup(board, neigh, nb, color);
      if (g != null) {
        if (_countLiberties(board, neigh, g) > 0) {
          hasLiberty = true;
          break;
        }
      }
    }
  }
  board[index] = 0;
  return hasLiberty;
}

void _applyInPlace(List<int> board, List<List<int>> neigh, int index,
    int color, List<_Change> undo) {
  undo.add(_Change(index, board[index]));
  board[index] = color;
}

int _captureAndKo(List<int> board, List<List<int>> neigh, int index, int color,
    List<_Change> undo) {
  final oppColor = color == 1 ? 2 : 1;
  int newKo = -1;

  for (final nb in neigh[index]) {
    if (board[nb] == oppColor) {
      final g = _findGroup(board, neigh, nb, oppColor);
      if (g != null && _countLiberties(board, neigh, g) == 0) {
        for (final gi in g) {
          undo.add(_Change(gi, board[gi]));
          board[gi] = 0;
        }
        if (g.length == 1) {
          newKo = g.first;
        }
      }
    }
  }

  return newKo;
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

int _countLiberties(
    List<int> board, List<List<int>> neigh, Set<int> group) {
  final libs = <int>{};
  for (final idx in group) {
    for (final nb in neigh[idx]) {
      if (board[nb] == 0) libs.add(nb);
    }
  }
  return libs.length;
}

/// Precompute neighbor indices for all board positions.
List<List<int>> _buildNeighborCache(int size) {
  final cache = <List<int>>[];
  final total = size * size;
  for (int i = 0; i < total; i++) {
    final r = i ~/ size;
    final c = i % size;
    final nbs = <int>[];
    if (r > 0) nbs.add(i - size);
    if (r < size - 1) nbs.add(i + size);
    if (c > 0) nbs.add(i - 1);
    if (c < size - 1) nbs.add(i + 1);
    cache.add(nbs);
  }
  return cache;
}