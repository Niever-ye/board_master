import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:board_master/core/types.dart';
import 'package:board_master/state/chess_game_notifier.dart';
import 'package:board_master/state/providers.dart';
import 'package:board_master/ui/chess/chess_board_painter.dart';
import 'package:board_master/ui/chess/chess_controls.dart';
import 'package:board_master/ui/widgets/thinking_indicator.dart';
import 'package:board_master/ui/widgets/difficulty_chip.dart';

class ChessBoardScreen extends ConsumerStatefulWidget {
  const ChessBoardScreen({super.key});

  @override
  ConsumerState<ChessBoardScreen> createState() => _ChessBoardScreenState();
}

class _ChessBoardScreenState extends ConsumerState<ChessBoardScreen> {
  @override
  Widget build(BuildContext context) {
    final gs = ref.watch(chessGameProvider);
    final game = gs.game;
    final pos = game.currentPosition;

    // Compute last move indices
    int? lastFrom, lastTo;
    if (game.moveHistory.isNotEmpty) {
      final m = game.moveHistory.last;
      lastFrom = pos.index(m.fromRow, m.fromCol);
      lastTo = pos.index(m.toRow, m.toCol);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chinese Chess'),
        actions: [
          DifficultyChip(
            difficulty: gs.difficulty,
            onChanged: (d) => ref.read(chessGameProvider.notifier).setDifficulty(d),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _InfoBar(gs: gs),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final boardW = constraints.maxWidth * 0.95;
                final boardH = constraints.maxHeight * 0.95;
                // 9 cells across (8 intervals + padding), 10 cells high (9 intervals + padding)
                final cellFromW = boardW / 9.0;
                final cellFromH = boardH / 10.0;
                final cellSize = cellFromW < cellFromH ? cellFromW : cellFromH;
                final actualW = cellSize * 9;
                final actualH = cellSize * 10;

                return Center(
                  child: SizedBox(
                    width: actualW,
                    height: actualH,
                    child: GestureDetector(
                      onTapUp: (details) {
                        if (gs.isAIThinking ||
                            game.status != ChessGameStatus.playing) {
                          return;
                        }
                        final pad = cellSize * 0.5;
                        final col = ((details.localPosition.dx - pad) / cellSize).round();
                        final row = ((details.localPosition.dy - pad) / cellSize).round();
                        if (row >= 0 && row < 10 && col >= 0 && col < 9) {
                          ref.read(chessGameProvider.notifier).tapSquare(row, col);
                        }
                      },
                      child: CustomPaint(
                        painter: ChessBoardPainter(
                          position: pos,
                          selectedIndex: gs.selectedIndex,
                          legalMoveIndices: gs.legalMoves,
                          lastFromIdx: lastFrom,
                          lastToIdx: lastTo,
                        ),
                        size: Size(actualW, actualH),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (gs.isAIThinking) const ThinkingIndicator(),
          if (gs.statusMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(gs.statusMessage!, style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF8B4513))),
            ),
          const ChessControls(),
        ],
      ),
    );
  }
}

class _InfoBar extends StatelessWidget {
  final ChessGameState gs;
  const _InfoBar({required this.gs});

  @override
  Widget build(BuildContext context) {
    final game = gs.game;
    final isPlayerTurn = game.currentPlayer == (gs.isPlayerRed ? ChessColor.red : ChessColor.black);
    final currentColorName = game.currentPlayer == ChessColor.red ? 'Red' : 'Black';
    String statusText;
    if (game.status != ChessGameStatus.playing) {
      statusText = game.status == ChessGameStatus.redWins ? 'Red wins!' :
          game.status == ChessGameStatus.blackWins ? 'Black wins!' : 'Draw!';
    } else if (game.isInCheck) {
      statusText = 'Check!';
    } else {
      statusText = isPlayerTurn ? 'Your turn ($currentColorName)' : 'AI thinking...';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF0E6D3),
        border: Border(bottom: BorderSide(color: Color(0xFFDDD0C0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(statusText, style: const TextStyle(fontSize: 14,
              fontWeight: FontWeight.w500, color: Color(0xFF5C3A28))),
          Text('Move ${game.moveHistory.length}',
              style: const TextStyle(fontSize: 13, color: Color(0xFF8B4513))),
        ],
      ),
    );
  }
}
