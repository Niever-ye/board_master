import 'package:flutter/material.dart';
import 'package:board_master/core/types.dart';
import 'package:board_master/models/chess/chess_position.dart';
import 'package:board_master/ui/theme.dart';

class ChessBoardPainter extends CustomPainter {
  final ChessPosition position;
  final int? selectedIndex;
  final List<int> legalMoveIndices;
  final int? lastFromIdx;
  final int? lastToIdx;

  ChessBoardPainter({
    required this.position,
    this.selectedIndex,
    this.legalMoveIndices = const [],
    this.lastFromIdx,
    this.lastToIdx,
  });

  static const _redPieceColor = Color(0xFFCC0000);
  static const _blackPieceColor = Color(0xFF1A1A1A);
  static const _pieceBgColor = Color(0xFFF5DEB3);

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / 9.0;
    final pad = cellSize * 0.5;
    final boardW = cellSize * 8;
    final boardH = cellSize * 9;

    // Board background
    final boardRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(pad - cellSize * 0.2, pad - cellSize * 0.2,
          boardW + cellSize * 0.4, boardH + cellSize * 0.4),
      const Radius.circular(4),
    );
    canvas.drawRRect(boardRect, Paint()..color = AppTheme.woodBoard);
    canvas.drawRRect(boardRect,
        Paint()..color = AppTheme.gridLine.withAlpha(40)..style = PaintingStyle.stroke..strokeWidth = 2);

    // Grid
    final gridPaint = Paint()
      ..color = AppTheme.gridLine
      ..strokeWidth = 0.8;

    // Horizontal lines
    for (int i = 0; i < 10; i++) {
      final y = pad + i * cellSize;
      canvas.drawLine(Offset(pad, y), Offset(pad + boardW, y), gridPaint);
    }

    // Vertical lines (top half, gap at river, bottom half)
    for (int i = 0; i < 9; i++) {
      final x = pad + i * cellSize;
      // Top half (rows 0-4)
      canvas.drawLine(Offset(x, pad), Offset(x, pad + 4 * cellSize), gridPaint);
      // Bottom half (rows 5-9)
      canvas.drawLine(Offset(x, pad + 5 * cellSize), Offset(x, pad + 9 * cellSize), gridPaint);
    }

    // Left and right border lines cross the river
    canvas.drawLine(
      Offset(pad, pad), Offset(pad, pad + 9 * cellSize), gridPaint);
    canvas.drawLine(
      Offset(pad + boardW, pad),
      Offset(pad + boardW, pad + 9 * cellSize),
      gridPaint,
    );

    // Palace diagonals
    _drawPalace(canvas, pad, cellSize, 0); // Black palace (top)
    _drawPalace(canvas, pad, cellSize, 7); // Red palace (bottom)

    // River text
    final riverY = pad + 4.5 * cellSize;
    final tp = TextPainter(
      text: TextSpan(
        text: '楚  河　　　　漢  界',
        style: TextStyle(
          color: AppTheme.gridLine.withAlpha(160),
          fontSize: cellSize * 0.45,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(pad + (boardW - tp.width) / 2, riverY - tp.height / 2));

    // Last move highlight
    if (lastFromIdx != null) {
      final (r, c) = position.coord(lastFromIdx!);
      _drawHighlight(canvas, pad + c * cellSize, pad + r * cellSize, cellSize, cellSize,
          Colors.yellow.withAlpha(80));
    }
    if (lastToIdx != null) {
      final (r, c) = position.coord(lastToIdx!);
      _drawHighlight(canvas, pad + c * cellSize, pad + r * cellSize, cellSize, cellSize,
          Colors.yellow.withAlpha(120));
    }

    // Selected piece highlight
    if (selectedIndex != null) {
      final (r, c) = position.coord(selectedIndex!);
      _drawHighlight(canvas, pad + c * cellSize, pad + r * cellSize, cellSize, cellSize,
          Colors.green.withAlpha(100));
    }

    // Legal move indicators
    for (final idx in legalMoveIndices) {
      final (r, c) = position.coord(idx);
      final x = pad + c * cellSize;
      final y = pad + r * cellSize;
      if (position.board[idx] != 0) {
        // Capture indicator
        canvas.drawCircle(
          Offset(x, y),
          cellSize * 0.42,
          Paint()..color = Colors.red.withAlpha(60)..style = PaintingStyle.stroke..strokeWidth = 2.5,
        );
      } else {
        canvas.drawCircle(
          Offset(x, y),
          cellSize * 0.15,
          Paint()..color = Colors.green.withAlpha(120),
        );
      }
    }

    // Pieces
    for (int r = 0; r < 10; r++) {
      for (int c = 0; c < 9; c++) {
        final piece = position.pieceAt(r, c);
        if (piece == 0) continue;
        _drawPiece(canvas, pad + c * cellSize, pad + r * cellSize, cellSize * 0.42, piece);
      }
    }
  }

  void _drawPalace(Canvas canvas, double pad, double cellSize, int topRow) {
    final paint = Paint()
      ..color = AppTheme.gridLine
      ..strokeWidth = 0.5;
    final x1 = pad + 3 * cellSize;
    final y1 = pad + topRow * cellSize;
    final x2 = pad + 5 * cellSize;
    final y2 = pad + (topRow + 2) * cellSize;
    canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
    canvas.drawLine(Offset(x2, y1), Offset(x1, y2), paint);
  }

  void _drawHighlight(Canvas canvas, double x, double y, double w, double h, Color color) {
    canvas.drawRect(
      Rect.fromCenter(center: Offset(x, y), width: w * 0.9, height: h * 0.9),
      Paint()..color = color,
    );
  }

  void _drawPiece(Canvas canvas, double x, double y, double radius, int piece) {
    final isRed = piece <= 10;
    final type = piece > 10 ? piece - 11 : piece - 1;
    final color = isRed ? _redPieceColor : _blackPieceColor;
    final char = _pieceChar(PieceType.values[type]);

    // Shadow
    canvas.drawCircle(
      Offset(x + 1, y + 1.5),
      radius,
      Paint()..color = Colors.black.withAlpha(50)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // Piece background
    canvas.drawCircle(
      Offset(x, y),
      radius,
      Paint()..color = _pieceBgColor,
    );
    canvas.drawCircle(
      Offset(x, y),
      radius,
      Paint()..color = AppTheme.gridLine..style = PaintingStyle.stroke..strokeWidth = 1.5,
    );

    // Inner ring
    canvas.drawCircle(
      Offset(x, y),
      radius * 0.88,
      Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.2,
    );

    // Character
    final tp = TextPainter(
      text: TextSpan(
        text: char,
        style: TextStyle(
          color: color,
          fontSize: radius * 1.1,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
  }

  String _pieceChar(PieceType type) {
    // Red pieces use one character, black pieces use another (handled by color)
    switch (type) {
      case PieceType.general: return '帅'; // will be overridden for black
      case PieceType.advisor: return '仕';
      case PieceType.elephant: return '相';
      case PieceType.horse: return '马';
      case PieceType.chariot: return '车';
      case PieceType.cannon: return '炮';
      case PieceType.soldier: return '兵';
    }
  }

  /// Get piece character considering color (red and black have different chars)
  static String pieceChar(int piece) {
    final isRed = piece <= 10;
    final type = piece > 10 ? piece - 11 : piece - 1;
    switch (PieceType.values[type]) {
      case PieceType.general: return isRed ? '帅' : '将';
      case PieceType.advisor: return isRed ? '仕' : '士';
      case PieceType.elephant: return isRed ? '相' : '象';
      case PieceType.horse: return isRed ? '马' : '馬';
      case PieceType.chariot: return isRed ? '车' : '車';
      case PieceType.cannon: return isRed ? '炮' : '砲';
      case PieceType.soldier: return isRed ? '兵' : '卒';
    }
  }

  @override
  bool shouldRepaint(covariant ChessBoardPainter oldDelegate) {
    return position != oldDelegate.position ||
        selectedIndex != oldDelegate.selectedIndex ||
        legalMoveIndices != oldDelegate.legalMoveIndices ||
        lastFromIdx != oldDelegate.lastFromIdx ||
        lastToIdx != oldDelegate.lastToIdx;
  }
}
