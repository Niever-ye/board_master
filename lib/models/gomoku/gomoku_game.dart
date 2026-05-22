import 'package:board_master/core/types.dart';

class GomokuMove {
  final int row;
  final int col;
  final int player; // 1=black, 2=white

  const GomokuMove(this.row, this.col, this.player);
}

class GomokuGame {
  final int boardSize;
  final List<int> board; // flat array, 0=empty, 1=black, 2=white
  final int currentPlayer; // 1=black, 2=white
  final GomokuGameStatus status;
  final List<GomokuMove> moveHistory;
  final int? lastMoveIndex;

  GomokuGame({
    required this.boardSize,
    required this.board,
    this.currentPlayer = 1,
    this.status = GomokuGameStatus.playing,
    List<GomokuMove>? moveHistory,
    this.lastMoveIndex,
  }) : moveHistory = moveHistory ?? [];

  factory GomokuGame.newGame({int boardSize = 15}) {
    return GomokuGame(
      boardSize: boardSize,
      board: List.filled(boardSize * boardSize, 0),
    );
  }

  int index(int row, int col) => row * boardSize + col;

  bool isWithinBounds(int row, int col) =>
      row >= 0 && row < boardSize && col >= 0 && col < boardSize;

  int pieceAt(int row, int col) => board[index(row, col)];

  /// Place a stone. Returns null if illegal, otherwise new game state.
  GomokuGame? placeStone(int row, int col) {
    if (status != GomokuGameStatus.playing) return null;
    if (!isWithinBounds(row, col)) return null;
    if (board[index(row, col)] != 0) return null;

    final newBoard = List<int>.from(board);
    final idx = index(row, col);
    newBoard[idx] = currentPlayer;

    final move = GomokuMove(row, col, currentPlayer);
    final newHistory = [...moveHistory, move];

    // Check win
    if (_checkWin(newBoard, row, col, currentPlayer)) {
      return GomokuGame(
        boardSize: boardSize,
        board: newBoard,
        currentPlayer: _opponent(currentPlayer),
        status: currentPlayer == 1 ? GomokuGameStatus.blackWins : GomokuGameStatus.whiteWins,
        moveHistory: newHistory,
        lastMoveIndex: idx,
      );
    }

    // Check draw (board full)
    if (newHistory.length >= boardSize * boardSize) {
      return GomokuGame(
        boardSize: boardSize,
        board: newBoard,
        currentPlayer: _opponent(currentPlayer),
        status: GomokuGameStatus.draw,
        moveHistory: newHistory,
        lastMoveIndex: idx,
      );
    }

    return GomokuGame(
      boardSize: boardSize,
      board: newBoard,
      currentPlayer: _opponent(currentPlayer),
      moveHistory: newHistory,
      lastMoveIndex: idx,
    );
  }

  bool _checkWin(List<int> b, int row, int col, int player) {
    // 4 directions: horizontal, vertical, diag-down, diag-up
    const dirs = [(0, 1), (1, 0), (1, 1), (1, -1)];
    for (final (dr, dc) in dirs) {
      int count = 1;
      // Positive direction
      for (int i = 1; i < 5; i++) {
        final r = row + dr * i;
        final c = col + dc * i;
        if (!isWithinBounds(r, c) || b[index(r, c)] != player) break;
        count++;
      }
      // Negative direction
      for (int i = 1; i < 5; i++) {
        final r = row - dr * i;
        final c = col - dc * i;
        if (!isWithinBounds(r, c) || b[index(r, c)] != player) break;
        count++;
      }
      if (count >= 5) return true;
    }
    return false;
  }

  int _opponent(int player) => player == 1 ? 2 : 1;

  /// Get the color name string
  String get currentPlayerName => currentPlayer == 1 ? 'Black' : 'White';
}
