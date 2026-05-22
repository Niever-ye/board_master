import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:board_master/core/types.dart';
import 'package:board_master/engines/gomoku/gomoku_engine.dart';
import 'package:board_master/models/gomoku/gomoku_game.dart';

class GomokuGameState {
  final GomokuGame game;
  final bool isAIThinking;
  final bool isPlayerBlack;
  final Difficulty difficulty;
  final String? statusMessage;

  const GomokuGameState({
    required this.game,
    this.isAIThinking = false,
    this.isPlayerBlack = true,
    this.difficulty = Difficulty.medium,
    this.statusMessage,
  });

  GomokuGameState copyWith({
    GomokuGame? game,
    bool? isAIThinking,
    bool? isPlayerBlack,
    Difficulty? difficulty,
    String? statusMessage,
  }) {
    return GomokuGameState(
      game: game ?? this.game,
      isAIThinking: isAIThinking ?? this.isAIThinking,
      isPlayerBlack: isPlayerBlack ?? this.isPlayerBlack,
      difficulty: difficulty ?? this.difficulty,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}

class GomokuGameNotifier extends StateNotifier<GomokuGameState> {
  final GomokuEngine _engine;
  Timer? _aiTimer;

  GomokuGameNotifier(this._engine)
      : super(GomokuGameState(game: GomokuGame.newGame()));

  void placeStone(int row, int col) {
    if (state.isAIThinking) return;
    if (state.game.status != GomokuGameStatus.playing) return;

    final newGame = state.game.placeStone(row, col);
    if (newGame == null) return;

    state = state.copyWith(
      game: newGame,
      statusMessage: _statusText(newGame),
    );

    if (newGame.status == GomokuGameStatus.playing) {
      _scheduleAI();
    }
  }

  void resign() {
    if (state.isAIThinking) return;
    final isPlayerBlack = state.isPlayerBlack;
    final newBoard = List<int>.from(state.game.board);
    final game = GomokuGame(
      boardSize: state.game.boardSize,
      board: newBoard,
      currentPlayer: state.game.currentPlayer,
      status: isPlayerBlack
          ? GomokuGameStatus.whiteWins
          : GomokuGameStatus.blackWins,
      moveHistory: state.game.moveHistory,
    );
    state = state.copyWith(
      game: game,
      statusMessage: isPlayerBlack ? 'White wins (resign)' : 'Black wins (resign)',
    );
  }

  void undo() {
    if (state.isAIThinking) return;
    _aiTimer?.cancel();
    final hist = state.game.moveHistory;
    if (hist.length < 2) return;

    // Remove last 2 moves (AI + player)
    final newHistory = hist.sublist(0, hist.length - 2);
    final newBoard = List.filled(
        state.game.boardSize * state.game.boardSize, 0);

    // Replay all remaining moves
    for (final m in newHistory) {
      newBoard[m.row * state.game.boardSize + m.col] = m.player;
    }

    state = state.copyWith(
      game: GomokuGame(
        boardSize: state.game.boardSize,
        board: newBoard,
        currentPlayer: state.isPlayerBlack ? 1 : 2,
        moveHistory: newHistory,
      ),
      statusMessage: null,
    );
  }

  void setDifficulty(Difficulty d) {
    state = state.copyWith(difficulty: d);
  }

  void newGame({int boardSize = 15}) {
    _aiTimer?.cancel();
    state = GomokuGameState(
      game: GomokuGame.newGame(boardSize: boardSize),
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
      final game = state.game;
      final currentColor = game.currentPlayer; // 1=black, 2=white

      final result = await _engine.findBestMove(
        game.board,
        game.boardSize,
        currentColor,
        -1, // no ko in Gomoku
        state.difficulty,
      );

      if (result.row != null && result.col != null) {
        final newGame = game.placeStone(result.row!, result.col!);
        if (newGame != null) {
          state = state.copyWith(
            game: newGame,
            isAIThinking: false,
            statusMessage: _statusText(newGame),
          );
          return;
        }
      }
      // Fallback
      state = state.copyWith(isAIThinking: false);
    } catch (e) {
      state = state.copyWith(isAIThinking: false);
    }
  }

  String? _statusText(GomokuGame game) {
    switch (game.status) {
      case GomokuGameStatus.blackWins:
        return 'Black wins!';
      case GomokuGameStatus.whiteWins:
        return 'White wins!';
      case GomokuGameStatus.draw:
        return 'Draw!';
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
