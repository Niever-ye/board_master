import 'package:board_master/core/types.dart';
import 'package:board_master/models/chess/chess_move.dart';
import 'package:board_master/models/chess/chess_position.dart';

class ChessGame {
  final List<ChessPosition> positionHistory;
  final List<ChessMove> moveHistory;
  final ChessColor currentPlayer;
  final ChessGameStatus status;
  final bool isInCheck;

  const ChessGame._({
    required this.positionHistory,
    required this.moveHistory,
    required this.currentPlayer,
    required this.status,
    this.isInCheck = false,
  });

  factory ChessGame.newGame() {
    return ChessGame._(
      positionHistory: [ChessPosition.initial()],
      moveHistory: [],
      currentPlayer: ChessColor.red,
      status: ChessGameStatus.playing,
    );
  }

  ChessPosition get currentPosition => positionHistory.last;

  ChessGame makeMove(ChessMove move, ChessPosition newPos, {
    bool inCheck = false,
    ChessGameStatus? newStatus,
  }) {
    return ChessGame._(
      positionHistory: [...positionHistory, newPos],
      moveHistory: [...moveHistory, move],
      currentPlayer: currentPlayer == ChessColor.red
          ? ChessColor.black
          : ChessColor.red,
      status: newStatus ?? ChessGameStatus.playing,
      isInCheck: inCheck,
    );
  }

  ChessGame undo(int count) {
    if (moveHistory.length < count) return this;
    final newHistory = moveHistory.sublist(0, moveHistory.length - count);
    final newPositions = positionHistory.sublist(0, positionHistory.length - count);
    return ChessGame._(
      positionHistory: newPositions,
      moveHistory: newHistory,
      currentPlayer: newHistory.isEmpty
          ? ChessColor.red
          : (newHistory.last.color == ChessColor.red
              ? ChessColor.black
              : ChessColor.red),
      status: ChessGameStatus.playing,
    );
  }

  ChessGame resign(ChessColor resigner) {
    return ChessGame._(
      positionHistory: positionHistory,
      moveHistory: moveHistory,
      currentPlayer: currentPlayer,
      status: resigner == ChessColor.red
          ? ChessGameStatus.blackWins
          : ChessGameStatus.redWins,
      isInCheck: isInCheck,
    );
  }

  ChessGame withStatus(ChessGameStatus newStatus) {
    return ChessGame._(
      positionHistory: positionHistory,
      moveHistory: moveHistory,
      currentPlayer: currentPlayer,
      status: newStatus,
      isInCheck: isInCheck,
    );
  }
}
