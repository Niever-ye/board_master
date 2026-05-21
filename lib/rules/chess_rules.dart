import 'package:board_master/core/types.dart';
import 'package:board_master/models/chess/chess_position.dart';

class ChessRules {
  /// Returns all legal move destinations for a piece at (row, col).
  /// Filters out moves that leave own general in check.
  static List<(int, int)> legalMoves(ChessPosition pos, int row, int col) {
    final piece = pos.pieceAt(row, col);
    if (piece == 0) return [];

    final color = piece > 10 ? ChessColor.black : ChessColor.red;
    final type = _typeOf(piece);
    final pseudo = _pseudoMoves(pos, row, col, color, type);

    // Filter moves that leave own general in check
    final fromIdx = pos.index(row, col);
    pseudo.removeWhere((dest) {
      final toIdx = pos.index(dest.$1, dest.$2);
      final newPos = pos.copyWithMove(fromIdx, toIdx);
      return isInCheck(newPos, color);
    });

    // Check flying general rule
    pseudo.removeWhere((dest) {
      final toIdx = pos.index(dest.$1, dest.$2);
      final newPos = pos.copyWithMove(fromIdx, toIdx);
      return generalsAreFacing(newPos);
    });

    return pseudo;
  }

  static List<(int, int)> _pseudoMoves(
      ChessPosition pos, int row, int col, ChessColor color, PieceType type) {
    switch (type) {
      case PieceType.general:
        return _generalMoves(pos, row, col, color);
      case PieceType.advisor:
        return _advisorMoves(pos, row, col, color);
      case PieceType.elephant:
        return _elephantMoves(pos, row, col, color);
      case PieceType.horse:
        return _horseMoves(pos, row, col);
      case PieceType.chariot:
        return _chariotMoves(pos, row, col);
      case PieceType.cannon:
        return _cannonMoves(pos, row, col);
      case PieceType.soldier:
        return _soldierMoves(pos, row, col, color);
    }
  }

  // General: 1 step orthogonal within palace
  static List<(int, int)> _generalMoves(
      ChessPosition pos, int row, int col, ChessColor color) {
    final moves = <(int, int)>[];
    final palaceRowMin = color == ChessColor.red ? 7 : 0;
    final palaceRowMax = color == ChessColor.red ? 9 : 2;
    const palaceColMin = 3;
    const palaceColMax = 5;

    for (final (dr, dc) in [(0, 1), (0, -1), (1, 0), (-1, 0)]) {
      final nr = row + dr;
      final nc = col + dc;
      if (nr >= palaceRowMin && nr <= palaceRowMax &&
          nc >= palaceColMin && nc <= palaceColMax) {
        final target = pos.pieceAt(nr, nc);
        if (target == 0 || _colorOf(target) != color) {
          moves.add((nr, nc));
        }
      }
    }
    return moves;
  }

  // Advisor: 1 step diagonal within palace
  static List<(int, int)> _advisorMoves(
      ChessPosition pos, int row, int col, ChessColor color) {
    final moves = <(int, int)>[];
    final palaceRowMin = color == ChessColor.red ? 7 : 0;
    final palaceRowMax = color == ChessColor.red ? 9 : 2;

    for (final (dr, dc) in [(1, 1), (1, -1), (-1, 1), (-1, -1)]) {
      final nr = row + dr;
      final nc = col + dc;
      if (nr >= palaceRowMin && nr <= palaceRowMax &&
          nc >= 3 && nc <= 5) {
        final target = pos.pieceAt(nr, nc);
        if (target == 0 || _colorOf(target) != color) {
          moves.add((nr, nc));
        }
      }
    }
    return moves;
  }

  // Elephant: 2 steps diagonal, cannot cross river, must check blocking eye
  static List<(int, int)> _elephantMoves(
      ChessPosition pos, int row, int col, ChessColor color) {
    final moves = <(int, int)>[];
    // Red elephants stay in rows 5-9, Black in rows 0-4
    // (Actually: Red in own half: rows 5-9, Black: rows 0-4)
    final rowMin = color == ChessColor.red ? 5 : 0;
    final rowMax = color == ChessColor.red ? 9 : 4;

    for (final (dr, dc, er, ec) in [
      (2, 2, 1, 1), (2, -2, 1, -1),
      (-2, 2, -1, 1), (-2, -2, -1, -1),
    ]) {
      final nr = row + dr;
      final nc = col + dc;
      final eyeR = row + er;
      final eyeC = col + ec;

      if (nr >= rowMin && nr <= rowMax && nc >= 0 && nc < 9) {
        if (pos.pieceAt(eyeR, eyeC) == 0) {
          final target = pos.pieceAt(nr, nc);
          if (target == 0 || _colorOf(target) != color) {
            moves.add((nr, nc));
          }
        }
      }
    }
    return moves;
  }

  // Horse: L-shape, checking blocking leg
  static List<(int, int)> _horseMoves(ChessPosition pos, int row, int col) {
    final moves = <(int, int)>[];
    final color = _colorOf(pos.pieceAt(row, col));

    for (final (dr, dc, lr, lc) in [
      // leg: 1 step orthogonal, then 1 step diagonal from there
      (-1, -2, 0, -1), (-2, -1, -1, 0),
      (-2, 1, -1, 0), (-1, 2, 0, 1),
      (1, -2, 0, -1), (2, -1, 1, 0),
      (2, 1, 1, 0), (1, 2, 0, 1),
    ]) {
      final nr = row + dr;
      final nc = col + dc;
      final legR = row + lr;
      final legC = col + lc;

      if (nr >= 0 && nr < 10 && nc >= 0 && nc < 9) {
        if (pos.pieceAt(legR, legC) == 0) {
          final target = pos.pieceAt(nr, nc);
          if (target == 0 || _colorOf(target) != color) {
            moves.add((nr, nc));
          }
        }
      }
    }
    return moves;
  }

  // Chariot: any distance orthogonal, blocked by first piece
  static List<(int, int)> _chariotMoves(ChessPosition pos, int row, int col) {
    final moves = <(int, int)>[];
    final color = _colorOf(pos.pieceAt(row, col));

    for (final (dr, dc) in [(0, 1), (0, -1), (1, 0), (-1, 0)]) {
      int nr = row + dr;
      int nc = col + dc;
      while (nr >= 0 && nr < 10 && nc >= 0 && nc < 9) {
        final target = pos.pieceAt(nr, nc);
        if (target == 0) {
          moves.add((nr, nc));
        } else {
          if (_colorOf(target) != color) {
            moves.add((nr, nc)); // capture
          }
          break;
        }
        nr += dr;
        nc += dc;
      }
    }
    return moves;
  }

  // Cannon: moves like chariot, captures by jumping over exactly one piece
  static List<(int, int)> _cannonMoves(ChessPosition pos, int row, int col) {
    final moves = <(int, int)>[];
    final color = _colorOf(pos.pieceAt(row, col));

    for (final (dr, dc) in [(0, 1), (0, -1), (1, 0), (-1, 0)]) {
      int nr = row + dr;
      int nc = col + dc;
      // Non-capture: move to empty space before first piece
      while (nr >= 0 && nr < 10 && nc >= 0 && nc < 9) {
        final target = pos.pieceAt(nr, nc);
        if (target == 0) {
          moves.add((nr, nc));
        } else {
          // Found screen, look for capture target
          int cr = nr + dr;
          int cc = nc + dc;
          while (cr >= 0 && cr < 10 && cc >= 0 && cc < 9) {
            final capTarget = pos.pieceAt(cr, cc);
            if (capTarget != 0) {
              if (_colorOf(capTarget) != color) {
                moves.add((cr, cc)); // capture
              }
              break;
            }
            cr += dr;
            cc += dc;
          }
          break;
        }
        nr += dr;
        nc += dc;
      }
    }
    return moves;
  }

  // Soldier: forward only before crossing river; forward/left/right after
  static List<(int, int)> _soldierMoves(
      ChessPosition pos, int row, int col, ChessColor color) {
    final moves = <(int, int)>[];
    final forward = color == ChessColor.red ? -1 : 1;
    final crossed = color == ChessColor.red ? row <= 4 : row >= 5;

    // Forward
    final fr = row + forward;
    if (fr >= 0 && fr < 10) {
      final target = pos.pieceAt(fr, col);
      if (target == 0 || _colorOf(target) != color) {
        moves.add((fr, col));
      }
    }

    // Sideways (only after crossing river)
    if (crossed) {
      for (final dc in [-1, 1]) {
        final nc = col + dc;
        if (nc >= 0 && nc < 9) {
          final target = pos.pieceAt(row, nc);
          if (target == 0 || _colorOf(target) != color) {
            moves.add((row, nc));
          }
        }
      }
    }
    return moves;
  }

  /// Check if the given color's general is in check.
  static bool isInCheck(ChessPosition pos, ChessColor color) {
    final generalIdx = pos.findGeneral(color);
    if (generalIdx == -1) return true; // no general = captured (shouldn't happen)
    final (gr, gc) = pos.coord(generalIdx);
    final oppColor = color == ChessColor.red ? ChessColor.black : ChessColor.red;

    // Check if any opponent piece attacks the general
    for (int r = 0; r < 10; r++) {
      for (int c = 0; c < 9; c++) {
        final piece = pos.pieceAt(r, c);
        if (piece == 0 || _colorOf(piece) != oppColor) continue;
        final type = _typeOf(piece);
        final pseudo = _pseudoMoves(pos, r, c, oppColor, type);
        if (pseudo.any((m) => m.$1 == gr && m.$2 == gc)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Check if both generals face each other on the same column with no pieces between.
  static bool generalsAreFacing(ChessPosition pos) {
    final redGen = pos.findGeneral(ChessColor.red);
    final blackGen = pos.findGeneral(ChessColor.black);
    if (redGen == -1 || blackGen == -1) return false;

    final (rr, rc) = pos.coord(redGen);
    final (br, bc) = pos.coord(blackGen);

    if (rc != bc) return false;

    // Check all squares between the two generals
    final minR = rr < br ? rr : br;
    final maxR = rr > br ? rr : br;
    for (int r = minR + 1; r < maxR; r++) {
      if (pos.pieceAt(r, rc) != 0) return false;
    }
    return true; // They face each other — illegal state
  }

  /// Check if the given color is checkmated (in check with no legal moves).
  static bool isCheckmate(ChessPosition pos, ChessColor color) {
    if (!isInCheck(pos, color)) return false;
    return !_hasLegalMove(pos, color);
  }

  /// Check if the given color is stalemated (not in check but no legal moves).
  static bool isStalemate(ChessPosition pos, ChessColor color) {
    if (isInCheck(pos, color)) return false;
    return !_hasLegalMove(pos, color);
  }

  static bool _hasLegalMove(ChessPosition pos, ChessColor color) {
    for (int r = 0; r < 10; r++) {
      for (int c = 0; c < 9; c++) {
        final piece = pos.pieceAt(r, c);
        if (piece == 0 || _colorOf(piece) != color) continue;
        if (legalMoves(pos, r, c).isNotEmpty) return true;
      }
    }
    return false;
  }

  static ChessColor _colorOf(int piece) =>
      piece > 10 ? ChessColor.black : ChessColor.red;

  static PieceType _typeOf(int piece) {
    final idx = piece > 10 ? piece - 11 : piece - 1;
    return PieceType.values[idx];
  }
}
