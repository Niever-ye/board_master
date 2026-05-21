import 'dart:collection';
import 'package:board_master/core/types.dart';

class GoPosition {
  final int size;
  final List<int> board; // size*size, 0=empty 1=black 2=white
  final int koPoint; // index of ko-forbidden point, -1 if none
  final int blackCaptures;
  final int whiteCaptures;

  const GoPosition({
    required this.size,
    required this.board,
    this.koPoint = -1,
    this.blackCaptures = 0,
    this.whiteCaptures = 0,
  });

  factory GoPosition.empty(int size) {
    return GoPosition(
      size: size,
      board: List.filled(size * size, 0),
    );
  }

  int index(int row, int col) => row * size + col;
  (int, int) coord(int index) => (index ~/ size, index % size);

  int stoneAt(int row, int col) => board[row * size + col];

  bool isWithinBounds(int row, int col) =>
      row >= 0 && row < size && col >= 0 && col < size;

  List<int> neighbors(int index) {
    final r = index ~/ size;
    final c = index % size;
    final result = <int>[];
    if (r > 0) result.add(index - size);
    if (r < size - 1) result.add(index + size);
    if (c > 0) result.add(index - 1);
    if (c < size - 1) result.add(index + 1);
    return result;
  }

  /// Returns a copy with the stone placed, including capture resolution.
  /// Returns null if the move is illegal.
  GoPosition? placeStone(int row, int col, Stone stone) {
    if (!isWithinBounds(row, col)) return null;
    final idx = index(row, col);
    if (board[idx] != 0) return null;
    if (idx == koPoint) return null;

    final stoneVal = stone == Stone.black ? 1 : 2;
    final oppVal = stone == Stone.black ? 2 : 1;
    final newBoard = List<int>.from(board);
    newBoard[idx] = stoneVal;

    // Check opponent captures
    int captured = 0;
    final oppNeighbors = neighbors(idx)
        .where((n) => newBoard[n] == oppVal)
        .toSet();
    for (final oppIdx in oppNeighbors) {
      final group = _findGroup(newBoard, oppIdx, oppVal);
      if (_countLiberties(newBoard, group) == 0) {
        for (final gi in group) {
          newBoard[gi] = 0;
          captured++;
        }
      }
    }

    // Check suicide
    final ownGroup = _findGroup(newBoard, idx, stoneVal);
    if (_countLiberties(newBoard, ownGroup) == 0) {
      return null; // suicide is illegal
    }

    // Ko detection: if exactly 1 stone captured and new stone has 1 liberty,
    // the capturing point could be ko
    int newKoPoint = -1;
    if (captured == 1) {
      final group = _findGroup(newBoard, idx, stoneVal);
      if (_countLiberties(newBoard, group) == 1) {
        // Find the captured stone's position as ko point
        for (final oppIdx in oppNeighbors) {
          if (board[oppIdx] == oppVal && newBoard[oppIdx] == 0) {
            final capturedGroup = _findGroup(board, oppIdx, oppVal);
            if (capturedGroup.length == 1) {
              newKoPoint = oppIdx;
            }
          }
        }
      }
    }

    return GoPosition(
      size: size,
      board: newBoard,
      koPoint: newKoPoint,
      blackCaptures: blackCaptures + (stone == Stone.black ? captured : 0),
      whiteCaptures: whiteCaptures + (stone == Stone.white ? captured : 0),
    );
  }

  Set<int> _findGroup(List<int> boardState, int start, int color) {
    final group = <int>{};
    final queue = Queue<int>();
    queue.add(start);
    group.add(start);

    while (queue.isNotEmpty) {
      final cur = queue.removeFirst();
      for (final nb in neighbors(cur)) {
        if (boardState[nb] == color && group.add(nb)) {
          queue.add(nb);
        }
      }
    }
    return group;
  }

  int _countLiberties(List<int> boardState, Set<int> group) {
    final liberties = <int>{};
    for (final idx in group) {
      for (final nb in neighbors(idx)) {
        if (boardState[nb] == 0) liberties.add(nb);
      }
    }
    return liberties.length;
  }

  @override
  bool operator ==(Object other) =>
      other is GoPosition &&
      other.size == size &&
      other.koPoint == koPoint &&
      other.blackCaptures == blackCaptures &&
      other.whiteCaptures == whiteCaptures &&
      _listEquals(other.board, board);

  @override
  int get hashCode => Object.hash(size, koPoint, blackCaptures, whiteCaptures);

  bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
