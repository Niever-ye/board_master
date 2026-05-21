import 'dart:collection';

import 'package:board_master/core/types.dart';
import 'package:board_master/models/go/go_move.dart';
import 'package:board_master/models/go/go_position.dart';

class GoGame {
  final List<GoPosition> positionHistory;
  final List<GoMove> moveHistory;
  final Stone currentPlayer;
  final GoGameStatus status;
  final double komi;
  final int boardSize;
  final int consecutivePasses;

  const GoGame._({
    required this.positionHistory,
    required this.moveHistory,
    required this.currentPlayer,
    required this.status,
    required this.komi,
    required this.boardSize,
    required this.consecutivePasses,
  });

  factory GoGame.newGame({
    int boardSize = 19,
    double komi = 6.5,
  }) {
    return GoGame._(
      positionHistory: [GoPosition.empty(boardSize)],
      moveHistory: [],
      currentPlayer: Stone.black,
      status: GoGameStatus.playing,
      komi: komi,
      boardSize: boardSize,
      consecutivePasses: 0,
    );
  }

  GoPosition get currentPosition => positionHistory.last;

  /// Returns a new GoGame after a pass, or null if game ends.
  GoGame? pass() {
    if (status != GoGameStatus.playing) return null;

    final passMove = GoMove(
      stone: currentPlayer,
      isPass: true,
      isResign: false,
      moveNumber: moveHistory.length + 1,
    );

    final newPasses = consecutivePasses + 1;

    if (newPasses >= 2) {
      // Game over, score it
      final result = _score();
      return GoGame._(
        positionHistory: positionHistory,
        moveHistory: [...moveHistory, passMove],
        currentPlayer: currentPlayer,
        status: result,
        komi: komi,
        boardSize: boardSize,
        consecutivePasses: newPasses,
      );
    }

    return GoGame._(
      positionHistory: positionHistory,
      moveHistory: [...moveHistory, passMove],
      currentPlayer: currentPlayer == Stone.black ? Stone.white : Stone.black,
      status: status,
      komi: komi,
      boardSize: boardSize,
      consecutivePasses: newPasses,
    );
  }

  /// Returns a new GoGame after placing a stone, or null if illegal.
  GoGame? placeStone(int row, int col) {
    if (status != GoGameStatus.playing) return null;

    final newPos = currentPosition.placeStone(row, col, currentPlayer);
    if (newPos == null) return null;

    final move = GoMove(
      stone: currentPlayer,
      row: row,
      col: col,
      isPass: false,
      isResign: false,
      moveNumber: moveHistory.length + 1,
    );

    return GoGame._(
      positionHistory: [...positionHistory, newPos],
      moveHistory: [...moveHistory, move],
      currentPlayer: currentPlayer == Stone.black ? Stone.white : Stone.black,
      status: status,
      komi: komi,
      boardSize: boardSize,
      consecutivePasses: 0,
    );
  }

  /// Returns a new GoGame after resignation.
  GoGame resign() {
    final move = GoMove(
      stone: currentPlayer,
      isPass: false,
      isResign: true,
      moveNumber: moveHistory.length + 1,
    );

    return GoGame._(
      positionHistory: positionHistory,
      moveHistory: [...moveHistory, move],
      currentPlayer: currentPlayer,
      status: currentPlayer == Stone.black
          ? GoGameStatus.whiteWins
          : GoGameStatus.blackWins,
      komi: komi,
      boardSize: boardSize,
      consecutivePasses: consecutivePasses,
    );
  }

  /// Undo the last move (player + AI if in PvE mode).
  GoGame undo(int count) {
    if (moveHistory.length < count) return this;
    final newHistory = moveHistory.sublist(0, moveHistory.length - count);
    final newPositions = positionHistory.sublist(
        0, positionHistory.length - count);
    return GoGame._(
      positionHistory: newPositions,
      moveHistory: newHistory,
      currentPlayer: newHistory.isEmpty
          ? Stone.black
          : (newHistory.last.stone == Stone.black
              ? Stone.white
              : Stone.black),
      status: GoGameStatus.playing, // reset status on undo
      komi: komi,
      boardSize: boardSize,
      consecutivePasses: 0,
    );
  }

  GoGameStatus _score() {
    final pos = currentPosition;
    double blackScore = 0;
    double whiteScore = komi;

    // Chinese area scoring: stones on board + surrounded territory
    final visited = <int>{};
    for (int r = 0; r < boardSize; r++) {
      for (int c = 0; c < boardSize; c++) {
        final idx = pos.index(r, c);
        if (visited.contains(idx)) continue;

        final stone = pos.board[idx];
        if (stone == 1) {
          blackScore += 1;
        } else if (stone == 2) {
          whiteScore += 1;
        } else {
          // Empty point: flood fill to see who surrounds it
          final territory = _floodFillEmpty(pos, idx);
          visited.addAll(territory);

          // Check borders: what colors touch this territory?
          bool touchesBlack = false;
          bool touchesWhite = false;
          for (final ti in territory) {
            for (final nb in pos.neighbors(ti)) {
              if (pos.board[nb] == 1) touchesBlack = true;
              if (pos.board[nb] == 2) touchesWhite = true;
            }
          }

          if (touchesBlack && !touchesWhite) {
            blackScore += territory.length;
          } else if (touchesWhite && !touchesBlack) {
            whiteScore += territory.length;
          }
        }
        visited.add(idx);
      }
    }

    // Add captures
    blackScore += pos.blackCaptures;
    whiteScore += pos.whiteCaptures;

    if (blackScore > whiteScore) return GoGameStatus.blackWins;
    if (whiteScore > blackScore) return GoGameStatus.whiteWins;
    return GoGameStatus.draw;
  }

  Set<int> _floodFillEmpty(GoPosition pos, int start) {
    final territory = <int>{};
    final queue = ListQueue<int>()..add(start);
    territory.add(start);

    while (queue.isNotEmpty) {
      final cur = queue.removeFirst();
      for (final nb in pos.neighbors(cur)) {
        if (pos.board[nb] == 0 && territory.add(nb)) {
          queue.add(nb);
        }
      }
    }
    return territory;
  }

  /// Returns the score difference as a formatted string.
  String getScoreString() {
    if (status == GoGameStatus.playing) return 'Playing...';
    if (status == GoGameStatus.draw) return 'Draw';

    final pos = currentPosition;
    double blackScore = pos.blackCaptures.toDouble();
    double whiteScore = pos.whiteCaptures.toDouble() + komi;

    final visited = <int>{};
    for (int r = 0; r < boardSize; r++) {
      for (int c = 0; c < boardSize; c++) {
        final idx = pos.index(r, c);
        if (visited.contains(idx)) continue;
        final stone = pos.board[idx];
        if (stone == 1) {
          blackScore += 1;
          visited.add(idx);
        } else if (stone == 2) {
          whiteScore += 1;
          visited.add(idx);
        } else {
          final territory = _floodFillEmpty(pos, idx);
          visited.addAll(territory);
          bool tB = false, tW = false;
          for (final ti in territory) {
            for (final nb in pos.neighbors(ti)) {
              if (pos.board[nb] == 1) tB = true;
              if (pos.board[nb] == 2) tW = true;
            }
          }
          if (tB && !tW) blackScore += territory.length;
          if (tW && !tB) whiteScore += territory.length;
        }
      }
    }

    final diff = (blackScore - whiteScore).abs();
    if (blackScore > whiteScore) return 'B+${diff.toStringAsFixed(1)}';
    return 'W+${diff.toStringAsFixed(1)}';
  }
}

