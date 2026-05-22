import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:board_master/core/types.dart';
import 'package:board_master/models/chess/chess_game.dart';
import 'package:board_master/models/chess/chess_move.dart';
import 'package:board_master/engines/chess/chess_engine.dart';
import 'package:board_master/rules/chess_rules.dart';
import 'package:board_master/network/connection_service.dart';

class ChessGameState {
  final ChessGame game;
  final int? selectedIndex;
  final List<int> legalMoves;
  final bool isAIThinking;
  final bool isPlayerRed;
  final Difficulty difficulty;
  final String? statusMessage;
  final GameMode gameMode;
  final bool isMyTurn;

  const ChessGameState({
    required this.game,
    this.selectedIndex,
    this.legalMoves = const [],
    this.isAIThinking = false,
    this.isPlayerRed = true,
    this.difficulty = Difficulty.medium,
    this.statusMessage,
    this.gameMode = GameMode.offline,
    this.isMyTurn = true,
  });

  ChessGameState copyWith({
    ChessGame? game,
    int? selectedIndex,
    List<int>? legalMoves,
    bool? isAIThinking,
    bool? isPlayerRed,
    Difficulty? difficulty,
    String? statusMessage,
    GameMode? gameMode,
    bool? isMyTurn,
    bool clearSelection = false,
  }) {
    return ChessGameState(
      game: game ?? this.game,
      selectedIndex: clearSelection ? null : (selectedIndex ?? this.selectedIndex),
      legalMoves: legalMoves ?? this.legalMoves,
      isAIThinking: isAIThinking ?? this.isAIThinking,
      isPlayerRed: isPlayerRed ?? this.isPlayerRed,
      difficulty: difficulty ?? this.difficulty,
      statusMessage: statusMessage ?? this.statusMessage,
      gameMode: gameMode ?? this.gameMode,
      isMyTurn: isMyTurn ?? this.isMyTurn,
    );
  }
}

class ChessGameNotifier extends StateNotifier<ChessGameState> {
  final ChessEngine _engine;
  Timer? _aiTimer;
  GameConnectionService? _connectionService;

  ChessGameNotifier(this._engine)
      : super(ChessGameState(game: ChessGame.newGame()));

  void initializeOnline(GameConnectionService connection, {required String myColor}) {
    _connectionService = connection;
    final isRed = myColor == 'red';
    state = ChessGameState(
      game: ChessGame.newGame(),
      gameMode: GameMode.online,
      isPlayerRed: isRed,
      isMyTurn: isRed,
    );
    _wireCallbacks();
  }

  void _wireCallbacks() {
    final conn = _connectionService;
    if (conn == null) return;
    // Chess: row=fromIdx, col=toIdx (reuse move fields for flat indices)
    conn.onOpponentMove = (fromIdx, toIdx) => _applyRemoteMove(fromIdx, toIdx);
    conn.onGameOver = () {
      final playerColor = state.isPlayerRed ? ChessColor.red : ChessColor.black;
      state = state.copyWith(
        game: state.game.resign(playerColor),
        statusMessage: 'Opponent resigned. You win!',
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
      final isRed = yourColor == 'red';
      state = ChessGameState(
        game: ChessGame.newGame(),
        gameMode: GameMode.online,
        isPlayerRed: isRed,
        isMyTurn: isRed,
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

  void tapSquare(int row, int col) {
    if (state.isAIThinking) return;
    if (state.game.status != ChessGameStatus.playing) return;
    if (state.gameMode == GameMode.online && !state.isMyTurn) return;

    final pos = state.game.currentPosition;
    final idx = pos.index(row, col);
    final piece = pos.board[idx];
    final isPlayerColor = state.isPlayerRed ? ChessColor.red : ChessColor.black;

    if (state.selectedIndex != null) {
      if (state.legalMoves.contains(idx)) {
        _makeMove(state.selectedIndex!, idx);
        return;
      }
      if (piece != 0 && _colorOf(piece) == isPlayerColor &&
          _colorOf(piece) == state.game.currentPlayer) {
        _selectPiece(idx);
        return;
      }
      state = state.copyWith(clearSelection: true, legalMoves: []);
      return;
    }

    if (piece != 0 && _colorOf(piece) == isPlayerColor &&
        _colorOf(piece) == state.game.currentPlayer) {
      _selectPiece(idx);
    }
  }

  void _selectPiece(int idx) {
    final pos = state.game.currentPosition;
    final (r, c) = pos.coord(idx);
    final moves = ChessRules.legalMoves(pos, r, c);
    state = state.copyWith(
      selectedIndex: idx,
      legalMoves: moves.map((m) => pos.index(m.$1, m.$2)).toList(),
    );
  }

  void _makeMove(int fromIdx, int toIdx) {
    final pos = state.game.currentPosition;
    final (fr, fc) = pos.coord(fromIdx);
    final (tr, tc) = pos.coord(toIdx);
    final piece = pos.board[fromIdx];
    final captured = pos.board[toIdx];

    final move = ChessMove(
      fromRow: fr, fromCol: fc,
      toRow: tr, toCol: tc,
      piece: piece,
      captured: captured,
      moveNumber: state.game.moveHistory.length + 1,
    );

    final newPos = pos.copyWithMove(fromIdx, toIdx);
    final oppColor = state.game.currentPlayer == ChessColor.red
        ? ChessColor.black : ChessColor.red;
    final inCheck = ChessRules.isInCheck(newPos, oppColor);
    final isMate = ChessRules.isCheckmate(newPos, oppColor);
    final isStale = ChessRules.isStalemate(newPos, oppColor);

    ChessGameStatus? newStatus;
    if (isMate) {
      newStatus = oppColor == ChessColor.red
          ? ChessGameStatus.blackWins : ChessGameStatus.redWins;
    } else if (isStale) {
      newStatus = oppColor == ChessColor.red
          ? ChessGameStatus.blackWins : ChessGameStatus.redWins;
    }

    final newGame = state.game.makeMove(move, newPos, inCheck: inCheck, newStatus: newStatus);

    String? msg;
    if (isMate) {
      msg = 'Checkmate! ${state.game.currentPlayer == ChessColor.red ? "Red" : "Black"} wins!';
    }

    state = state.copyWith(
      game: newGame,
      clearSelection: true,
      legalMoves: [],
      statusMessage: msg,
    );

    if (newGame.status == ChessGameStatus.playing) {
      if (state.gameMode == GameMode.online) {
        _connectionService?.sendMove(fromIdx, toIdx);
        state = state.copyWith(isMyTurn: false);
      } else {
        _scheduleAI();
      }
    }
  }

  void undo() {
    if (state.isAIThinking) return;
    if (state.gameMode == GameMode.online) {
      _connectionService?.requestUndo();
      return;
    }
    _aiTimer?.cancel();
    final newGame = state.game.undo(2);
    state = state.copyWith(
      game: newGame,
      clearSelection: true,
      legalMoves: [],
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

  void resign() {
    if (state.isAIThinking) return;
    final playerColor = state.isPlayerRed ? ChessColor.red : ChessColor.black;
    state = state.copyWith(
      game: state.game.resign(playerColor),
      statusMessage: 'You resigned.',
    );
    if (state.gameMode == GameMode.online) {
      _connectionService?.sendResign();
    }
  }

  void setDifficulty(Difficulty d) {
    state = state.copyWith(difficulty: d);
  }

  void newGame() {
    if (state.gameMode == GameMode.online) {
      _connectionService?.requestNewGame();
      return;
    }
    _aiTimer?.cancel();
    state = ChessGameState(
      game: ChessGame.newGame(),
      isPlayerRed: state.isPlayerRed,
      difficulty: state.difficulty,
    );
  }

  void acceptNewGame() {
    if (state.gameMode == GameMode.online) {
      _connectionService?.acceptNewGame();
    }
  }

  void _applyRemoteMove(int fromIdx, int toIdx) {
    final pos = state.game.currentPosition;
    final (fr, fc) = pos.coord(fromIdx);
    final (tr, tc) = pos.coord(toIdx);
    final piece = pos.board[fromIdx];
    final captured = pos.board[toIdx];

    final move = ChessMove(
      fromRow: fr, fromCol: fc,
      toRow: tr, toCol: tc,
      piece: piece,
      captured: captured,
      moveNumber: state.game.moveHistory.length + 1,
    );

    final newPos = pos.copyWithMove(fromIdx, toIdx);
    final playerColor = state.isPlayerRed ? ChessColor.red : ChessColor.black;
    final inCheck = ChessRules.isInCheck(newPos, playerColor);
    final isMate = ChessRules.isCheckmate(newPos, playerColor);
    final isStale = ChessRules.isStalemate(newPos, playerColor);

    ChessGameStatus? newStatus;
    if (isMate) {
      newStatus = playerColor == ChessColor.red ? ChessGameStatus.blackWins : ChessGameStatus.redWins;
    } else if (isStale) {
      newStatus = playerColor == ChessColor.red ? ChessGameStatus.blackWins : ChessGameStatus.redWins;
    }

    String? msg;
    if (isMate) msg = 'Checkmate! You lose!';
    if (inCheck && !isMate) msg = 'Check!';

    final newGame = state.game.makeMove(move, newPos, inCheck: inCheck, newStatus: newStatus);

    state = state.copyWith(
      game: newGame,
      clearSelection: true,
      legalMoves: [],
      statusMessage: msg,
      isMyTurn: newGame.status == ChessGameStatus.playing,
    );
  }

  void _applyRemoteUndo() {
    _aiTimer?.cancel();
    final newGame = state.game.undo(2);
    state = state.copyWith(
      game: newGame,
      clearSelection: true,
      legalMoves: [],
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
      final pos = state.game.currentPosition;
      final aiColor = state.isPlayerRed ? ChessColor.black : ChessColor.red;
      final currentColorVal = aiColor == ChessColor.red ? 1 : 2;

      final result = await _engine.findBestMove(
        pos.board, 0, currentColorVal, -1, state.difficulty,
      );

      if (result.row != null && result.col != null) {
        final fromIdx = result.row!;
        final toIdx = result.col!;
        final (fr, fc) = pos.coord(fromIdx);
        final toRow = toIdx ~/ 9;
        final toCol = toIdx % 9;
        final piece = pos.board[fromIdx];
        final captured = pos.board[toIdx];

        final move = ChessMove(
          fromRow: fr, fromCol: fc,
          toRow: toRow, toCol: toCol,
          piece: piece, captured: captured,
          moveNumber: state.game.moveHistory.length + 1,
        );

        final newPos = pos.copyWithMove(fromIdx, toIdx);
        final playerColor = state.isPlayerRed ? ChessColor.red : ChessColor.black;
        final inCheck = ChessRules.isInCheck(newPos, playerColor);
        final isMate = ChessRules.isCheckmate(newPos, playerColor);
        final isStale = ChessRules.isStalemate(newPos, playerColor);

        ChessGameStatus? newStatus;
        if (isMate) {
          newStatus = playerColor == ChessColor.red ? ChessGameStatus.blackWins : ChessGameStatus.redWins;
        } else if (isStale) {
          newStatus = playerColor == ChessColor.red ? ChessGameStatus.blackWins : ChessGameStatus.redWins;
        }

        String? msg;
        if (isMate) msg = 'Checkmate! AI wins!';
        if (inCheck && !isMate) msg = 'Check!';

        final newGame = state.game.makeMove(move, newPos, inCheck: inCheck, newStatus: newStatus);
        state = state.copyWith(
          game: newGame,
          isAIThinking: false,
          clearSelection: true,
          legalMoves: [],
          statusMessage: msg,
        );
      }
    } catch (e) {
      state = state.copyWith(isAIThinking: false);
    }
  }

  ChessColor _colorOf(int piece) =>
      piece > 10 ? ChessColor.black : ChessColor.red;

  @override
  void dispose() {
    _aiTimer?.cancel();
    _connectionService?.disconnect();
    super.dispose();
  }
}
