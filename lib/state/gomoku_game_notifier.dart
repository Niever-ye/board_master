import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:board_master/core/types.dart';
import 'package:board_master/engines/gomoku/gomoku_engine.dart';
import 'package:board_master/models/gomoku/gomoku_game.dart';
import 'package:board_master/network/connection_service.dart';

class GomokuGameState {
  final GomokuGame game;
  final bool isAIThinking;
  final bool isPlayerBlack;
  final Difficulty difficulty;
  final String? statusMessage;
  final GameMode gameMode;
  final bool isMyTurn;

  const GomokuGameState({
    required this.game,
    this.isAIThinking = false,
    this.isPlayerBlack = true,
    this.difficulty = Difficulty.medium,
    this.statusMessage,
    this.gameMode = GameMode.offline,
    this.isMyTurn = true,
  });

  GomokuGameState copyWith({
    GomokuGame? game,
    bool? isAIThinking,
    bool? isPlayerBlack,
    Difficulty? difficulty,
    String? statusMessage,
    GameMode? gameMode,
    bool? isMyTurn,
  }) {
    return GomokuGameState(
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

class GomokuGameNotifier extends StateNotifier<GomokuGameState> {
  final GomokuEngine _engine;
  Timer? _aiTimer;
  GameConnectionService? _connectionService;

  GomokuGameNotifier(this._engine)
      : super(GomokuGameState(game: GomokuGame.newGame()));

  void initializeOnline(GameConnectionService connection, {required String myColor}) {
    _connectionService = connection;
    final isBlack = myColor == 'black';
    state = GomokuGameState(
      game: GomokuGame.newGame(),
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
    conn.onGameOver = () {
      final isBlack = state.isPlayerBlack;
      state = state.copyWith(
        game: _winGame(state.game, isBlack ? 2 : 1),
        statusMessage: isBlack ? 'White wins (resign)' : 'Black wins (resign)',
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
      state = GomokuGameState(
        game: GomokuGame.newGame(),
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

  void placeStone(int row, int col) {
    if (state.isAIThinking) return;
    if (state.game.status != GomokuGameStatus.playing) return;
    if (state.gameMode == GameMode.online && !state.isMyTurn) return;

    final newGame = state.game.placeStone(row, col);
    if (newGame == null) return;

    state = state.copyWith(
      game: newGame,
      statusMessage: _statusText(newGame),
    );

    if (newGame.status == GomokuGameStatus.playing) {
      if (state.gameMode == GameMode.online) {
        _connectionService?.sendMove(row, col);
        state = state.copyWith(isMyTurn: false);
      } else {
        _scheduleAI();
      }
    }
  }

  void resign() {
    if (state.isAIThinking) return;
    final isPlayerBlack = state.isPlayerBlack;
    final game = _winGame(state.game, isPlayerBlack ? 2 : 1);
    state = state.copyWith(
      game: game,
      statusMessage: isPlayerBlack ? 'White wins (resign)' : 'Black wins (resign)',
    );
    if (state.gameMode == GameMode.online) {
      _connectionService?.sendResign();
    }
  }

  GomokuGame _winGame(GomokuGame old, int winner) {
    return GomokuGame(
      boardSize: old.boardSize,
      board: List<int>.from(old.board),
      currentPlayer: old.currentPlayer,
      status: winner == 1 ? GomokuGameStatus.blackWins : GomokuGameStatus.whiteWins,
      moveHistory: old.moveHistory,
    );
  }

  void undo() {
    if (state.isAIThinking) return;
    if (state.gameMode == GameMode.online) {
      _connectionService?.requestUndo();
      return;
    }
    _aiTimer?.cancel();
    final hist = state.game.moveHistory;
    if (hist.length < 2) return;
    final newHistory = hist.sublist(0, hist.length - 2);
    final newBoard = List.filled(state.game.boardSize * state.game.boardSize, 0);
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

  void setDifficulty(Difficulty d) {
    state = state.copyWith(difficulty: d);
  }

  void newGame({int boardSize = 15}) {
    if (state.gameMode == GameMode.online) {
      _connectionService?.requestNewGame();
      return;
    }
    _aiTimer?.cancel();
    state = GomokuGameState(
      game: GomokuGame.newGame(boardSize: boardSize),
      isPlayerBlack: state.isPlayerBlack,
      difficulty: state.difficulty,
    );
  }

  void acceptNewGame() {
    if (state.gameMode == GameMode.online) {
      _connectionService?.acceptNewGame();
    }
  }

  void _applyRemoteMove(int row, int col) {
    final newGame = state.game.placeStone(row, col);
    if (newGame != null) {
      state = state.copyWith(
        game: newGame,
        statusMessage: _statusText(newGame),
        isMyTurn: newGame.status == GomokuGameStatus.playing,
      );
    }
  }

  void _applyRemoteUndo() {
    _aiTimer?.cancel();
    final hist = state.game.moveHistory;
    if (hist.length < 2) return;
    final newHistory = hist.sublist(0, hist.length - 2);
    final newBoard = List.filled(state.game.boardSize * state.game.boardSize, 0);
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
      isMyTurn: true,
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
      final currentColor = game.currentPlayer;
      final result = await _engine.findBestMove(
        game.board, game.boardSize, currentColor, -1, state.difficulty,
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
      state = state.copyWith(isAIThinking: false);
    } catch (e) {
      state = state.copyWith(isAIThinking: false);
    }
  }

  String? _statusText(GomokuGame game) {
    switch (game.status) {
      case GomokuGameStatus.blackWins: return 'Black wins!';
      case GomokuGameStatus.whiteWins: return 'White wins!';
      case GomokuGameStatus.draw: return 'Draw!';
      default: return null;
    }
  }

  @override
  void dispose() {
    _aiTimer?.cancel();
    _connectionService?.disconnect();
    super.dispose();
  }
}
