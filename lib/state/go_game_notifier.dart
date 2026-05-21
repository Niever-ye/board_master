import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:board_master/core/types.dart';
import 'package:board_master/engines/go/go_engine.dart';
import 'package:board_master/models/go/go_game.dart';

class GoGameState {
  final GoGame game;
  final bool isAIThinking;
  final bool isPlayerBlack;
  final Difficulty difficulty;
  final String? statusMessage;

  const GoGameState({
    required this.game,
    this.isAIThinking = false,
    this.isPlayerBlack = true,
    this.difficulty = Difficulty.medium,
    this.statusMessage,
  });

  GoGameState copyWith({
    GoGame? game,
    bool? isAIThinking,
    bool? isPlayerBlack,
    Difficulty? difficulty,
    String? statusMessage,
  }) {
    return GoGameState(
      game: game ?? this.game,
      isAIThinking: isAIThinking ?? this.isAIThinking,
      isPlayerBlack: isPlayerBlack ?? this.isPlayerBlack,
      difficulty: difficulty ?? this.difficulty,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}

class GoGameNotifier extends StateNotifier<GoGameState> {
  final GoEngine _engine;
  Timer? _aiTimer;

  GoGameNotifier(this._engine)
      : super(GoGameState(game: GoGame.newGame()));

  void placeStone(int row, int col) {
    if (state.isAIThinking) return;
    if (state.game.status != GoGameStatus.playing) return;

    final newGame = state.game.placeStone(row, col);
    if (newGame == null) return;

    state = state.copyWith(
      game: newGame,
      statusMessage: _gameStatusMessage(newGame),
    );

    if (newGame.status == GoGameStatus.playing) {
      _scheduleAI();
    }
  }

  void pass() {
    if (state.isAIThinking) return;
    final result = state.game.pass();
    if (result == null) return;

    state = state.copyWith(
      game: result,
      statusMessage: _gameStatusMessage(result),
    );

    if (result.status == GoGameStatus.playing) {
      _scheduleAI();
    }
  }

  void resign() {
    if (state.isAIThinking) return;
    final newGame = state.game.resign();
    state = state.copyWith(
      game: newGame,
      statusMessage: _gameStatusMessage(newGame),
    );
  }

  void undo() {
    if (state.isAIThinking) return;
    _aiTimer?.cancel();
    final newGame = state.game.undo(2);
    state = state.copyWith(
      game: newGame,
      statusMessage: null,
    );
  }

  void setDifficulty(Difficulty d) {
    state = state.copyWith(difficulty: d);
  }

  void newGame({int boardSize = 19, double komi = 6.5}) {
    _aiTimer?.cancel();
    state = GoGameState(
      game: GoGame.newGame(boardSize: boardSize, komi: komi),
      isPlayerBlack: state.isPlayerBlack,
      difficulty: state.difficulty,
    );
  }

  void _scheduleAI() {
    _aiTimer?.cancel();
    state = state.copyWith(isAIThinking: true);
    _aiTimer = Timer(const Duration(milliseconds: 200), () {
      _makeAIMove();
    });
  }

  Future<void> _makeAIMove() async {
    try {
      final pos = state.game.currentPosition;
      final currentColor = state.game.currentPlayer == Stone.black ? 1 : 2;

      final result = await _engine.findBestMove(
        pos.board,
        pos.size,
        currentColor,
        pos.koPoint,
        state.difficulty,
      );

      if (result.isPass) {
        final newGame = state.game.pass();
        if (newGame != null) {
          state = state.copyWith(
            game: newGame,
            isAIThinking: false,
            statusMessage: _gameStatusMessage(newGame),
          );
        }
      } else if (result.row != null && result.col != null) {
        final newGame = state.game.placeStone(result.row!, result.col!);
        if (newGame != null) {
          state = state.copyWith(
            game: newGame,
            isAIThinking: false,
            statusMessage: _gameStatusMessage(newGame),
          );
        }
      }
    } catch (e) {
      // AI error fallback: pass
      final newGame = state.game.pass();
      if (newGame != null) {
        state = state.copyWith(
          game: newGame,
          isAIThinking: false,
          statusMessage: _gameStatusMessage(newGame),
        );
      }
    }
  }

  String? _gameStatusMessage(GoGame game) {
    switch (game.status) {
      case GoGameStatus.blackWins:
        return 'Black wins! ${game.getScoreString()}';
      case GoGameStatus.whiteWins:
        return 'White wins! ${game.getScoreString()}';
      case GoGameStatus.draw:
        return 'Draw! ${game.getScoreString()}';
      default:
        return null;
    }
  }

  @override
  void dispose() {
    _aiTimer?.cancel();
    super.dispose();
  }
}
