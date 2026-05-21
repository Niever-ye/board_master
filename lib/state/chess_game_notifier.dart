import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:board_master/core/types.dart';
import 'package:board_master/models/chess/chess_game.dart';
import 'package:board_master/models/chess/chess_move.dart';
import 'package:board_master/engines/chess/chess_engine.dart';
import 'package:board_master/rules/chess_rules.dart';

class ChessGameState {
  final ChessGame game;
  final int? selectedIndex;
  final List<int> legalMoves; // indices
  final bool isAIThinking;
  final bool isPlayerRed;
  final Difficulty difficulty;
  final String? statusMessage;

  const ChessGameState({
    required this.game,
    this.selectedIndex,
    this.legalMoves = const [],
    this.isAIThinking = false,
    this.isPlayerRed = true,
    this.difficulty = Difficulty.medium,
    this.statusMessage,
  });

  ChessGameState copyWith({
    ChessGame? game,
    int? selectedIndex,
    List<int>? legalMoves,
    bool? isAIThinking,
    bool? isPlayerRed,
    Difficulty? difficulty,
    String? statusMessage,
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
    );
  }
}

class ChessGameNotifier extends StateNotifier<ChessGameState> {
  final ChessEngine _engine;
  Timer? _aiTimer;

  ChessGameNotifier(this._engine)
      : super(ChessGameState(game: ChessGame.newGame()));

  void tapSquare(int row, int col) {
    if (state.isAIThinking) return;
    if (state.game.status != ChessGameStatus.playing) return;

    final pos = state.game.currentPosition;
    final idx = pos.index(row, col);
    final piece = pos.board[idx];
    final isPlayerColor = state.isPlayerRed
        ? ChessColor.red
        : ChessColor.black;

    // If a piece is selected
    if (state.selectedIndex != null) {
      // If tapping a legal move destination
      if (state.legalMoves.contains(idx)) {
        _makeHumanMove(state.selectedIndex!, idx);
        return;
      }
      // If tapping own piece, reselect
      if (piece != 0 && _colorOf(piece) == isPlayerColor &&
          _colorOf(piece) == state.game.currentPlayer) {
        _selectPiece(idx);
        return;
      }
      // Otherwise deselect
      state = state.copyWith(clearSelection: true, legalMoves: []);
      return;
    }

    // Select own piece
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

  void _makeHumanMove(int fromIdx, int toIdx) {
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

    // Check if move leaves opponent in check/checkmate
    final oppColor = state.game.currentPlayer == ChessColor.red
        ? ChessColor.black
        : ChessColor.red;
    final inCheck = ChessRules.isInCheck(newPos, oppColor);
    final isMate = ChessRules.isCheckmate(newPos, oppColor);
    final isStale = ChessRules.isStalemate(newPos, oppColor);

    ChessGameStatus? newStatus;
    if (isMate) {
      newStatus = oppColor == ChessColor.red
          ? ChessGameStatus.blackWins
          : ChessGameStatus.redWins;
    } else if (isStale) {
      newStatus = oppColor == ChessColor.red
          ? ChessGameStatus.blackWins
          : ChessGameStatus.redWins;
    }

    final newGame = state.game.makeMove(move, newPos,
        inCheck: inCheck, newStatus: newStatus);

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
      _scheduleAI();
    }
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
        pos.board,
        0, // size unused for chess
        currentColorVal,
        -1, // koPoint unused
        state.difficulty,
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

  void undo() {
    if (state.isAIThinking) return;
    _aiTimer?.cancel();
    final newGame = state.game.undo(2);
    state = state.copyWith(
      game: newGame,
      clearSelection: true,
      legalMoves: [],
      statusMessage: null,
    );
  }

  void resign() {
    if (state.isAIThinking) return;
    final playerColor = state.isPlayerRed ? ChessColor.red : ChessColor.black;
    state = state.copyWith(
      game: state.game.resign(playerColor),
      statusMessage: 'You resigned.',
    );
  }

  void setDifficulty(Difficulty d) {
    state = state.copyWith(difficulty: d);
  }

  void newGame() {
    _aiTimer?.cancel();
    state = ChessGameState(
      game: ChessGame.newGame(),
      isPlayerRed: state.isPlayerRed,
      difficulty: state.difficulty,
    );
  }

  ChessColor _colorOf(int piece) =>
      piece > 10 ? ChessColor.black : ChessColor.red;

  @override
  void dispose() {
    _aiTimer?.cancel();
    super.dispose();
  }
}

