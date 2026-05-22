import 'package:flutter/material.dart';
import 'package:board_master/models/gomoku/gomoku_game.dart';
import 'package:board_master/ui/theme.dart';

class GomokuBoardPainter extends CustomPainter {
  final GomokuGame game;
  final int? lastMoveIndex;

  GomokuBoardPainter({required this.game, this.lastMoveIndex});

  @override
  void paint(Canvas canvas, Size size) {
    final bs = game.boardSize;
    final cellSize = size.width / (bs - 1 + 1.2); // 0.6 padding on each side
    final pad = cellSize * 0.6;

    // Board background
    final bg = RRect.fromRectAndRadius(
      Rect.fromLTWH(pad - cellSize * 0.15, pad - cellSize * 0.15,
          cellSize * (bs - 1) + cellSize * 0.3,
          cellSize * (bs - 1) + cellSize * 0.3),
      const Radius.circular(4),
    );
    canvas.drawRRect(bg, Paint()..color = AppTheme.woodBoard);

    // Grid lines
    final linePaint = Paint()
      ..color = AppTheme.gridLine
      ..strokeWidth = 0.6;

    for (int i = 0; i < bs; i++) {
      final offset = pad + i * cellSize;
      canvas.drawLine(Offset(pad, offset), Offset(pad + (bs - 1) * cellSize, offset), linePaint);
      canvas.drawLine(Offset(offset, pad), Offset(offset, pad + (bs - 1) * cellSize), linePaint);
    }

    // Star points (for 15x15 and 19x19)
    _drawStarPoints(canvas, pad, cellSize, bs);

    // Last move highlight
    if (lastMoveIndex != null) {
      final r = lastMoveIndex! ~/ bs;
      final c = lastMoveIndex! % bs;
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(pad + c * cellSize, pad + r * cellSize),
          width: cellSize * 0.85,
          height: cellSize * 0.85,
        ),
        Paint()..color = Colors.red.withAlpha(60),
      );
    }

    // Stones
    for (int r = 0; r < bs; r++) {
      for (int c = 0; c < bs; c++) {
        final piece = game.pieceAt(r, c);
        if (piece == 0) continue;
        _drawStone(canvas, pad + c * cellSize, pad + r * cellSize,
            cellSize * 0.44, piece);
      }
    }
  }

  void _drawStarPoints(Canvas canvas, double pad, double s, int bs) {
    List<(int, int)> stars;
    if (bs == 15) {
      stars = [
        (3, 3), (3, 7), (3, 11),
        (7, 3), (7, 7), (7, 11),
        (11, 3), (11, 7), (11, 11),
      ];
    } else if (bs == 19) {
      stars = [
        (3, 3), (3, 9), (3, 15),
        (9, 3), (9, 9), (9, 15),
        (15, 3), (15, 9), (15, 15),
      ];
    } else if (bs == 13) {
      stars = [
        (3, 3), (3, 9), (6, 6), (9, 3), (9, 9),
      ];
    } else {
      stars = [];
    }

    final paint = Paint()..color = AppTheme.gridLine;
    for (final (r, c) in stars) {
      canvas.drawCircle(
        Offset(pad + c * s, pad + r * s),
        s * 0.1,
        paint,
      );
    }
  }

  void _drawStone(Canvas canvas, double x, double y, double r, int color) {
    // Shadow
    canvas.drawCircle(
      Offset(x + 1.5, y + 2),
      r,
      Paint()..color = Colors.black.withAlpha(60)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // Stone
    final gradient = RadialGradient(
      colors: color == 1
          ? [Colors.grey.shade500, Colors.black]
          : [Colors.white, Colors.grey.shade400],
    );
    canvas.drawCircle(
      Offset(x, y),
      r,
      Paint()..shader = gradient.createShader(Rect.fromCircle(center: Offset(x, y), radius: r)),
    );

    if (color == 2) {
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()..color = Colors.grey.shade400..style = PaintingStyle.stroke..strokeWidth = 0.8,
      );
    }
  }

  @override
  bool shouldRepaint(covariant GomokuBoardPainter oldDelegate) {
    return game != oldDelegate.game || lastMoveIndex != oldDelegate.lastMoveIndex;
  }
}
