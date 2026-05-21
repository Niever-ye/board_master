import 'dart:math';

import 'package:board_master/core/constants.dart';
import 'package:board_master/core/types.dart';
import 'package:board_master/engines/engine_interface.dart';
import 'package:board_master/engines/go/mcts_node.dart';
import 'package:board_master/engines/go/playout.dart';

/// MCTS Go engine. Runs on the main isolate (web-compatible).
class GoEngine implements EngineInterface {
  @override
  Future<EngineResult> findBestMove(
    List<int> board,
    int size,
    int currentColor,
    int koPoint,
    Difficulty difficulty,
  ) async {
    // Check if there are any legal moves
    final legalMoves = <int>[];
    for (int i = 0; i < board.length; i++) {
      if (board[i] == 0 && i != koPoint) {
        legalMoves.add(i);
      }
    }

    if (legalMoves.isEmpty) {
      return const EngineResult(isPass: true);
    }

    final params = _MctsParams(
      board: board,
      size: size,
      currentColor: currentColor,
      koPoint: koPoint,
      difficulty: difficulty,
    );

    // Run MCTS synchronously (no Isolate — Flutter Web doesn't support isolates)
    final result = _mctsSearch(params);
    if (result == -1) return const EngineResult(isPass: true);

    final row = result ~/ size;
    final col = result % size;
    return EngineResult(row: row, col: col);
  }
}

class _MctsParams {
  final List<int> board;
  final int size;
  final int currentColor;
  final int koPoint;
  final Difficulty difficulty;

  _MctsParams({
    required this.board,
    required this.size,
    required this.currentColor,
    required this.koPoint,
    required this.difficulty,
  });
}

int _mctsSearch(_MctsParams params) {
  final rng = Random();

  // Get all legal moves (simple check: empty, not ko, not suicide)
  final legalMoves = <int>[];
  for (int i = 0; i < params.board.length; i++) {
    if (params.board[i] == 0 && i != params.koPoint) {
      // Quick suicide check
      if (_quickLegal(params.board, params.size, i, params.currentColor)) {
        legalMoves.add(i);
      }
    }
  }

  if (legalMoves.isEmpty) return -1;

  // Determine iterations based on difficulty
  int iterations;
  double c;
  bool usePatterns;

  switch (params.difficulty) {
    case Difficulty.easy:
      iterations = AiConstants.easyIterations;
      c = 2.0;
      usePatterns = false;
      break;
    case Difficulty.medium:
      iterations = AiConstants.mediumIterations;
      c = 1.4;
      usePatterns = true;
      break;
    case Difficulty.hard:
      iterations = AiConstants.hardIterations;
      c = 1.2;
      usePatterns = true;
      break;
  }

  // Reduce iterations for larger boards to keep response time reasonable
  if (params.size == 19 && iterations > 15000) {
    iterations = 15000;
  }

  // Create root node
  final root = MctsNode(
    moveIndex: -1,
    stonePlayed: params.currentColor == 1 ? 2 : 1,
    visits: 1,
    unexploredMoves: List.from(legalMoves),
  );

  // MCTS loop
  for (int iter = 0; iter < iterations; iter++) {
    // 1. Selection
    var node = root;
    var simBoard = List<int>.from(params.board);
    var simKo = params.koPoint;
    var simColor = params.currentColor;

    while (!node.isLeaf && node.isFullyExpanded) {
      node = node.bestChild(c);
      // Apply the move
      final result = _applyMoveFast(simBoard, params.size, node.moveIndex, simColor);
      simBoard = result.board;
      simKo = result.koPoint;
      simColor = simColor == 1 ? 2 : 1;
    }

    // 2. Expansion
    if (!node.isFullyExpanded && node.unexploredMoves.isNotEmpty) {
      // Pick a random unexplored move
      final pickIdx = rng.nextInt(node.unexploredMoves.length);
      final moveIdx = node.unexploredMoves.removeAt(pickIdx);

      // Apply the move
      final result = _applyMoveFast(simBoard, params.size, moveIdx, simColor);
      simBoard = result.board;
      simKo = result.koPoint;
      final newNode = MctsNode(
        moveIndex: moveIdx,
        stonePlayed: simColor,
        parent: node,
      );
      simColor = simColor == 1 ? 2 : 1;

      // Initialize unexplored moves for the new node
      for (int i = 0; i < simBoard.length; i++) {
        if (simBoard[i] == 0 && i != simKo) {
          if (_quickLegal(simBoard, params.size, i, simColor)) {
            newNode.unexploredMoves.add(i);
          }
        }
      }

      node.children.add(newNode);
      node = newNode;
    }

    // 3. Simulation (playout)
    final result = playout(simBoard, params.size, simColor, simKo, usePatterns);

    // 4. Backpropagation
    MctsNode? backNode = node;
    while (backNode != null) {
      backNode.visits++;
      backNode.wins += result;
      backNode = backNode.parent;
    }
  }

  // Return the move with the most visits
  final best = root.mostVisitedChild();
  return best.moveIndex;
}

/// Quick legality check for MCTS (no full board copy needed for basic check).
bool _quickLegal(List<int> board, int size, int index, int color) {
  // Simple check: if placing here would be suicide without captures
  final oppColor = color == 1 ? 2 : 1;
  final neighbors = _neighborIndices(index, size);
  bool hasLiberty = false;
  bool capturesOpp = false;

  for (final nb in neighbors) {
    if (board[nb] == 0) {
      hasLiberty = true;
    }
    if (board[nb] == oppColor) {
      // Check if this opponent group would be captured
      final nbLibs = _quickLiberties(board, size, nb, oppColor);
      if (nbLibs == 1) {
        capturesOpp = true;
      }
    }
  }

  // If we capture something, it's legal (doesn't check full board but good enough for MCTS)
  if (capturesOpp) return true;

  // If any neighbor is empty, it's legal (not suicide)
  if (hasLiberty) return true;

  // Might be suicide - do quick check
  final ownGroup = _quickFindGroup(board, size, index, color);
  if (ownGroup != null) {
    int ownLibs = 0;
    for (final gi in ownGroup) {
      for (final nb in _neighborIndices(gi, size)) {
        if (board[nb] == 0) {
          ownLibs++;
          if (ownLibs > 1) return true;
        }
      }
    }
    return ownLibs > 0;
  }

  return false;
}

int _quickLiberties(List<int> board, int size, int index, int color) {
  final group = _quickFindGroup(board, size, index, color);
  if (group == null) return 0;
  final libs = <int>{};
  for (final gi in group) {
    for (final nb in _neighborIndices(gi, size)) {
      if (board[nb] == 0) libs.add(nb);
    }
  }
  return libs.length;
}

Set<int>? _quickFindGroup(List<int> board, int size, int start, int color) {
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

_ApplyResultFast _applyMoveFast(List<int> board, int size, int index, int color) {
  final newBoard = List<int>.from(board);
  newBoard[index] = color;
  final oppColor = color == 1 ? 2 : 1;

  int newKo = -1;
  int captured = 0;

  for (final nb in _neighborIndices(index, size)) {
    if (newBoard[nb] == oppColor) {
      final g = _quickFindGroup(newBoard, size, nb, oppColor);
      if (g != null) {
        int libs = 0;
        for (final gi in g) {
          for (final gnb in _neighborIndices(gi, size)) {
            if (newBoard[gnb] == 0) libs++;
          }
        }
        if (libs == 0) {
          captured += g.length;
          for (final gi in g) {
            newBoard[gi] = 0;
          }
          if (captured == 1 && g.length == 1) {
            newKo = g.first;
          }
        }
      }
    }
  }

  return _ApplyResultFast(newBoard, newKo);
}

class _ApplyResultFast {
  final List<int> board;
  final int koPoint;
  _ApplyResultFast(this.board, this.koPoint);
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
