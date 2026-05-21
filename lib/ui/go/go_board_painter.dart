import 'package:flutter/material.dart';
import 'package:board_master/core/types.dart';
import 'package:board_master/models/go/go_position.dart';
import 'package:board_master/ui/theme.dart';

class GoBoardPainter extends CustomPainter {
  final GoPosition position;
  final int? lastMoveIndex;
  final int? hoverIndex;
  final double boardSize;

  GoBoardPainter({
    required this.position,
    this.lastMoveIndex,
    this.hoverIndex,
    required this.boardSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / (position.size - 1);
    final padding = cellSize * 0.6;
    final boardPixelSize = cellSize * (position.size - 1);

    // Board background
    final boardRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(padding - cellSize * 0.3, padding - cellSize * 0.3,
          boardPixelSize + cellSize * 0.6, boardPixelSize + cellSize * 0.6),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      boardRect,
      Paint()..color = AppTheme.woodBoard,
    );
    canvas.drawRRect(
      boardRect,
      Paint()
        ..color = AppTheme.gridLine.withAlpha(40)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Grid lines
    final gridPaint = Paint()
      ..color = AppTheme.gridLine
      ..strokeWidth = 0.8;

    for (int i = 0; i < position.size; i++) {
      final offset = padding + i * cellSize;
      canvas.drawLine(
        Offset(padding, offset),
        Offset(padding + boardPixelSize, offset),
        gridPaint,
      );
      canvas.drawLine(
        Offset(offset, padding),
        Offset(offset, padding + boardPixelSize),
        gridPaint,
      );
    }

    // Star points
    _drawStarPoints(canvas, padding, cellSize);

    // Coordinate labels
    _drawCoordinates(canvas, padding, cellSize, boardPixelSize);

    // Stones
    for (int r = 0; r < position.size; r++) {
      for (int c = 0; c < position.size; c++) {
        final idx = position.index(r, c);
        final stone = position.board[idx];
        if (stone == 0) continue;

        final x = padding + c * cellSize;
        final y = padding + r * cellSize;
        final radius = cellSize * 0.44;

        _drawStone(canvas, Offset(x, y), radius,
            stone == 1 ? Stone.black : Stone.white);

        // Last move marker
        if (idx == lastMoveIndex) {
          final markerColor =
              stone == 1 ? Colors.white.withAlpha(180) : Colors.black.withAlpha(180);
          canvas.drawCircle(
            Offset(x, y),
            radius * 0.28,
            Paint()..color = markerColor,
          );
        }
      }
    }

    // Hover indicator
    if (hoverIndex != null) {
      final (r, c) = position.coord(hoverIndex!);
      final x = padding + c * cellSize;
      final y = padding + r * cellSize;
      final stone = position.board[hoverIndex!] == 1
          ? Stone.black
          : Stone.white;
      canvas.drawCircle(
        Offset(x, y),
        cellSize * 0.44,
        Paint()
          ..color = (stone == Stone.black ? Colors.white : Colors.black)
              .withAlpha(120),
      );
    }
  }

  void _drawStone(
      Canvas canvas, Offset center, double radius, Stone stone) {
    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withAlpha(40)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(center + const Offset(1, 1.5), radius, shadowPaint);

    // Stone body with gradient
    final gradient = RadialGradient(
      center: const Alignment(-0.3, -0.3),
      radius: 0.8,
      colors: stone == Stone.black
          ? [Colors.grey.shade700, Colors.grey.shade900, Colors.black]
          : [Colors.white, Colors.grey.shade200, Colors.grey.shade400],
      stops: const [0.0, 0.5, 1.0],
    );

    canvas.drawCircle(
      center,
      radius,
      Paint()..shader = gradient.createShader(
          Rect.fromCircle(center: center, radius: radius)),
    );

    // Subtle border
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = stone == Stone.black
            ? Colors.black
            : Colors.grey.shade300
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );
  }

  void _drawStarPoints(Canvas canvas, double padding, double cellSize) {
    final starPaint = Paint()
      ..color = AppTheme.gridLine
      ..style = PaintingStyle.fill;

    final points = _getStarPoints();
    for (final (r, c) in points) {
      canvas.drawCircle(
        Offset(padding + c * cellSize, padding + r * cellSize),
        cellSize * 0.1,
        starPaint,
      );
    }
  }

  List<(int, int)> _getStarPoints() {
    if (position.size == 19) {
      return [
        (3, 3), (3, 9), (3, 15),
        (9, 3), (9, 9), (9, 15),
        (15, 3), (15, 9), (15, 15),
      ];
    } else if (position.size == 13) {
      return [(3, 3), (3, 9), (6, 6), (9, 3), (9, 9)];
    } else if (position.size == 9) {
      return [(2, 2), (2, 6), (4, 4), (6, 2), (6, 6)];
    }
    return [];
  }

  void _drawCoordinates(
      Canvas canvas, double padding, double cellSize, double boardSize) {
    final textStyle = TextStyle(
      color: AppTheme.gridLine.withAlpha(180),
      fontSize: cellSize * 0.35,
      fontWeight: FontWeight.w500,
    );

    for (int i = 0; i < position.size; i++) {
      // Column labels (top)
      final colLabel = _colChar(i);
      final tp = TextPainter(
        text: TextSpan(text: colLabel, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(padding + i * cellSize - tp.width / 2, padding * 0.15),
      );

      // Row labels (left)
      final rowLabel = '${position.size - i}';
      final rp = TextPainter(
        text: TextSpan(text: rowLabel, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      rp.paint(
        canvas,
        Offset(padding * 0.05, padding + i * cellSize - rp.height / 2),
      );
    }
  }

  String _colChar(int i) {
    // SGF columns: A-T, skip I
    const cols = 'ABCDEFGHJKLMNOPQRST';
    return cols[i < cols.length ? i : i + 1];
  }

  @override
  bool shouldRepaint(covariant GoBoardPainter oldDelegate) {
    return position != oldDelegate.position ||
        lastMoveIndex != oldDelegate.lastMoveIndex ||
        hoverIndex != oldDelegate.hoverIndex;
  }
}
