import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:board_master/core/types.dart';
import 'package:board_master/engines/go/go_engine.dart';
import 'package:board_master/models/go/go_game.dart';
import 'package:board_master/network/connection_service.dart';

class GoGameState {
  final GoGame game;
  final bool isAIThinking;
  final bool isPlayerBlack;
  final Difficulty difficulty;
  final String? statusMessage;
  final GameMode gameMode;
  final bool isMyTurn;

  const GoGameState({
    required this.game,
    this.isAIThinking = false,
    this.isPlayerBlack = true,
    this.difficulty = Difficulty.medium,
    this.statusMessage,
    this.gameMode = GameMode.offline,
    this.isMyTurn = true,
  });

  GoGameState copyWith({
    GoGame? game,
    bool? isAIThinking,
    bool? isPlayerBlack,
    Difficulty? difficulty,
    String? statusMessage,
    GameMode? gameMode,
    bool? isMyTurn,
  }) {
    return GoGameState(
      game: game ?? this.game,
      isAIThinking: isAIThinking ?? this.isAIThinking,
      isPlayerBlack: isPlayerBlack ?? this.isPlayerBlack,
      difficulty: difficulty ?? this.difficulty,
      statusMessage: statusMessage ?? this.statusMessage,
      gameMode: gameMode ?? this.gameMode,
      isMyTurn: isMyTurn ?? this.isMyTurn,
    );
  }
}

class GoGameNotifier extends StateNotifier<GoGameState> {
  final GoEngine _engine;
  Timer? _aiTimer;
  GameConnectionService? _connectionService;
  bool _processingRemote = false;

  GoGameNotifier(this._engine)
      : super(GoGameState(game: GoGame.newGame()));

  // ---------- Online mode initialization ----------

  void initializeOnline(GameConnectionService connection, {required String myColor}) {
    _connectionService = connection;
    final isBlack = myColor == 'black';
    state = GoGameState(
      game: GoGame.newGame(),
      gameMode: GameMode.online,
      isPlayerBlack: isBlack,
      isMyTurn: isBlack,
    );
    _wireCallbacks();
  }

  void _wireCallbacks() {
    final conn = _connectionService;
    if (conn == null) return;
    conn.onOpponentMove = (row, col) => _applyRemoteMove(row, col);
    conn.onOpponentPass = () => _applyRemotePass();
    conn.onGameOver = () {
      // opponent resigned
      final newGame = state.game.resign();
      state = state.copyWith(
        game: newGame,
        statusMessage: _gameStatusMessage(newGame),
        isMyTurn: false,
      );
    };
    conn.onUndoRequested = () {
      state = state.copyWith(statusMessage: 'Opponent requests undo');
    };
    conn.onUndoAccepted = () {
      _applyRemoteUndo();
    };
    conn.onUndoRejected = () {
      state = state.copyWith(statusMessage: 'Undo rejected');
    };
    conn.onNewGameRequested = () {
      state = state.copyWith(statusMessage: 'Opponent wants a rematch');
    };
    conn.onNewGameStarted = (yourColor) {
      final isBlack = yourColor == 'black';
      state = GoGameState(
        game: GoGame.newGame(),
        gameMode: GameMode.online,
        isPlayerBlack: isBlack,
        isMyTurn: isBlack,
        statusMessage: 'New game!',
      );
    };
    conn.onOpponentDisconnected = () {
      state = state.copyWith(statusMessage: 'Opponent disconnected');
    };
    conn.onOpponentReconnected = () {
      state = state.copyWith(statusMessage: null);
    };
  }

  // ---------- Shared actions (branch on mode) ----------

  void placeStone(int row, int col) {
    if (state.isAIThinking || _processingRemote) return;
    if (state.game.status != GoGameStatus.playing) return;
    if (state.gameMode == GameMode.online && !state.isMyTurn) return;

    final newGame = state.game.placeStone(row, col);
    if (newGame == null) return;

    state = state.copyWith(
      game: newGame,
      statusMessage: _gameStatusMessage(newGame),
    );

    if (newGame.status == GoGameStatus.playing) {
      if (state.gameMode == GameMode.online) {
        _connectionService?.sendMove(row, col);
        state = state.copyWith(isMyTurn: false);
      } else {
        _scheduleAI();
      }
    }
  }

  void pass() {
    if (state.isAIThinking || _processingRemote) return;
    if (state.gameMode == GameMode.online && !state.isMyTurn) return;

    final result = state.game.pass();
    if (result == null) return;

    state = state.copyWith(
      game: result,
      statusMessage: _gameStatusMessage(result),
    );

    if (result.status == GoGameStatus.playing) {
      if (state.gameMode == GameMode.online) {
        _connectionService?.sendPass();
        state = state.copyWith(isMyTurn: false);
      } else {
        _scheduleAI();
      }
    }
  }

  void resign() {
    if (state.isAIThinking) return;
    final newGame = state.game.resign();
    state = state.copyWith(
      game: newGame,
      statusMessage: _gameStatusMessage(newGame),
    );

    if (state.gameMode == GameMode.online) {
      _connectionService?.sendResign();
    }
  }

  void undo() {
    if (state.isAIThinking || _processingRemote) return;
    if (state.gameMode == GameMode.online) {
      _connectionService?.requestUndo();
    } else {
      _aiTimer?.cancel();
      final newGame = state.game.undo(2);
      state = state.copyWith(
        game: newGame,
        statusMessage: null,
      );
    }
  }

  void acceptUndo() {
    if (state.gameMode == GameMode.online) {
      _connectionService?.acceptUndo();
    }
  }

  void rejectUndo() {
    if (state.gameMode == GameMode.online) {
      _connectionService?.rejectUndo();
    }
  }

  void newGame({int boardSize = 19, double komi = 6.5}) {
    if (state.gameMode == GameMode.online) {
      _connectionService?.requestNewGame();
      return;
    }
    _aiTimer?.cancel();
    state = GoGameState(
      game: GoGame.newGame(boardSize: boardSize, komi: komi),
      isPlayerBlack: state.isPlayerBlack,
      difficulty: state.difficulty,
    );
  }

  void acceptNewGame() {
    if (state.gameMode == GameMode.online) {
      _connectionService?.acceptNewGame();
    }
  }

  void setDifficulty(Difficulty d) {
    state = state.copyWith(difficulty: d);
  }

  // ---------- Remote move application ----------

  void _applyRemoteMove(int row, int col) {
    _processingRemote = true;
    final newGame = state.game.placeStone(row, col);
    if (newGame != null) {
      state = state.copyWith(
        game: newGame,
        statusMessage: _gameStatusMessage(newGame),
        isMyTurn: newGame.status == GoGameStatus.playing,
      );
    }
    _processingRemote = false;
  }

  void _applyRemotePass() {
    _processingRemote = true;
    final result = state.game.pass();
    if (result != null) {
      state = state.copyWith(
        game: result,
        statusMessage: _gameStatusMessage(result),
        isMyTurn: result.status == GoGameStatus.playing,
      );
    }
    _processingRemote = false;
  }

  void _applyRemoteUndo() {
    _aiTimer?.cancel();
    final newGame = state.game.undo(2);
    state = state.copyWith(
      game: newGame,
      statusMessage: null,
      isMyTurn: true,
    );
  }

  // ---------- AI (offline mode) ----------

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
    _connectionService?.disconnect();
    super.dispose();
  }
}
