import 'dart:math';

import 'package:board_master/core/constants.dart';
import 'package:board_master/core/types.dart';
import 'package:board_master/engines/engine_interface.dart';
import 'package:board_master/engines/go/mcts_node.dart';
import 'package:board_master/engines/go/playout.dart';

/// MCTS Go engine. Runs on the main isolate (web-compatible).
/// All board operations are in-place with undo to avoid copies.
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

  // Collect legal moves with fast check
  final legalMoves = _fastLegalMoves(board, size, currentColor, koPoint);
  if (legalMoves.isEmpty) return -1;

  int maxIterations;
  int maxMs;
  double c;
  bool usePatterns;

  switch (difficulty) {
    case Difficulty.easy:
      maxIterations = AiConstants.easyIterations;
      maxMs = 2000;
      c = 2.0;
      usePatterns = false;
      break;
    case Difficulty.medium:
      maxIterations = AiConstants.mediumIterations;
      maxMs = 6000;
      c = 1.4;
      usePatterns = true;
      break;
    case Difficulty.hard:
      maxIterations = AiConstants.hardIterations;
      maxMs = 15000;
      c = 1.2;
      usePatterns = true;
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

  // Precompute neighbor indices for each board position
  final neighbors = _buildNeighborCache(size);

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
      _applyInPlace(board, size, node.moveIndex, simColor, undoStack);
      simKo = _captureAndKo(board, size, node.moveIndex, simColor, undoStack);
      simColor = simColor == 1 ? 2 : 1;
    }

    // 2. Expansion
    if (!node.isFullyExpanded && node.unexploredMoves.isNotEmpty) {
      final pickIdx = rng.nextInt(node.unexploredMoves.length);
      final moveIdx = node.unexploredMoves.removeAt(pickIdx);

      _applyInPlace(board, size, moveIdx, simColor, undoStack);
      simKo = _captureAndKo(board, size, moveIdx, simColor, undoStack);

      final newNode = MctsNode(
        moveIndex: moveIdx,
        stonePlayed: simColor,
        parent: node,
      );
      simColor = simColor == 1 ? 2 : 1;

      // Fast unexplored moves scan for the new node
      newNode.unexploredMoves =
          _fastLegalMoves(board, size, simColor, simKo);

      node.children.add(newNode);
      node = newNode;
    }

    // 3. Simulation (playout — already in-place with undo)
    final winner = playout(board, size, simColor, simKo, usePatterns);

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

/// Fast collect all legal moves. Uses the same early-exit approach as playout.
List<int> _fastLegalMoves(List<int> board, int size, int color, int ko) {
  final result = <int>[];
  final oppColor = color == 1 ? 2 : 1;

  for (int i = 0; i < board.length; i++) {
    if (board[i] != 0 || i == ko) continue;

    // Early exit: if a neighbor is empty, it's legal
    bool nearEmpty = false;
    bool nearOpp = false;
    for (final nb in _neighborIndices(i, size)) {
      if (board[nb] == 0) {
        nearEmpty = true;
        break;
      }
      if (board[nb] == oppColor) nearOpp = true;
    }

    if (nearEmpty) {
      result.add(i);
    } else if (nearOpp) {
      // Only check full legality for possible capture-only moves
      if (_isLegalInPlace(board, size, i, color)) {
        result.add(i);
      }
    }
    // else: surrounded by own stones only = suicide, skip
  }

  return result;
}

/// Check if placing a stone at index is legal. Temporarily places the stone.
bool _isLegalInPlace(List<int> board, int size, int index, int color) {
  final oppColor = color == 1 ? 2 : 1;

  for (final nb in _neighborIndices(index, size)) {
    if (board[nb] == oppColor) {
      final g = _findGroup(board, size, nb, oppColor);
      if (g != null && _countLiberties(board, size, g) == 1) {
        return true; // capture makes it legal
      }
    }
  }

  // Place stone temporarily to check own liberties
  board[index] = color;
  bool hasLiberty = false;
  for (final nb in _neighborIndices(index, size)) {
    if (board[nb] == 0) {
      hasLiberty = true;
      break;
    }
    if (board[nb] == color) {
      final g = _findGroup(board, size, nb, color);
      if (g != null) {
        final libs = _countLiberties(board, size, g);
        if (libs > 0) {
          hasLiberty = true;
          break;
        }
      }
    }
  }
  board[index] = 0;
  return hasLiberty;
}

/// Place a stone in-place and track the change for undo.
void _applyInPlace(
    List<int> board, int size, int index, int color, List<_Change> undo) {
  undo.add(_Change(index, board[index]));
  board[index] = color;
}

/// Remove captured opponent stones after a move. Track changes for undo.
/// Returns the new ko point (or -1).
int _captureAndKo(
    List<int> board, int size, int index, int color, List<_Change> undo) {
  final oppColor = color == 1 ? 2 : 1;
  int newKo = -1;

  for (final nb in _neighborIndices(index, size)) {
    if (board[nb] == oppColor) {
      final g = _findGroup(board, size, nb, oppColor);
      if (g != null && _countLiberties(board, size, g) == 0) {
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

Set<int>? _findGroup(List<int> board, int size, int start, int color) {
  if (board[start] != color) return null;
  final group = <int>{};
  final queue = <int>[start];
  group.add(start);
  while (queue.isNotEmpty) {
    final cur = queue.removeAt(0);
    for (final nb in _neighborIndices(cur, size)) {
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
    for (final nb in _neighborIndices(idx, size)) {
      if (board[nb] == 0) libs.add(nb);
    }
  }
  return libs.length;
}

List<int> _neighborIndices(int idx, int size) {
  final r = idx ~/ size;
  final c = idx % size;
  final result = <int>[];
  if (r > 0) result.add(idx - size);
  if (r < size - 1) result.add(idx + size);
  if (c > 0) result.add(idx - 1);
  if (c < size - 1) result.add(idx + 1);
  return result;
}

/// Precompute neighbors for all board positions.
List<List<int>> _buildNeighborCache(int size) {
  final cache = <List<int>>[];
  for (int i = 0; i < size * size; i++) {
    cache.add(_neighborIndices(i, size));
  }
  return cache;
}
