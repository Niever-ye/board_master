import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:board_master/core/types.dart';
import 'package:board_master/state/providers.dart';
import 'package:board_master/ui/gomoku/gomoku_board_painter.dart';
import 'package:board_master/ui/gomoku/gomoku_controls.dart';
import 'package:board_master/ui/widgets/thinking_indicator.dart';
import 'package:board_master/ui/widgets/difficulty_chip.dart';

class GomokuBoardScreen extends ConsumerStatefulWidget {
  const GomokuBoardScreen({super.key});

  @override
  ConsumerState<GomokuBoardScreen> createState() => _GomokuBoardScreenState();
}

class _GomokuBoardScreenState extends ConsumerState<GomokuBoardScreen> {
  @override
  Widget build(BuildContext context) {
    final gs = ref.watch(gomokuGameProvider);
    final game = gs.game;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gomoku'),
        actions: [
          DifficultyChip(
            difficulty: gs.difficulty,
            onChanged: (d) =>
                ref.read(gomokuGameProvider.notifier).setDifficulty(d),
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
                final bs = game.boardSize;
                final boardMax = constraints.maxWidth < constraints.maxHeight
                    ? constraints.maxWidth * 0.95
                    : constraints.maxHeight * 0.95;
                final cellSize = boardMax / (bs - 1 + 1.2);
                final boardPx = cellSize * (bs - 1 + 1.2);

                return Center(
                  child: SizedBox(
                    width: boardPx,
                    height: boardPx,
                    child: GestureDetector(
                      onTapUp: (details) {
                        if (gs.isAIThinking ||
                            game.status != GomokuGameStatus.playing) {
                          return;
                        }
                        final pad = cellSize * 0.6;
                        final col =
                            ((details.localPosition.dx - pad) / cellSize).round();
                        final row =
                            ((details.localPosition.dy - pad) / cellSize).round();
                        if (game.isWithinBounds(row, col) &&
                            game.pieceAt(row, col) == 0) {
                          ref
                              .read(gomokuGameProvider.notifier)
                              .placeStone(row, col);
                        }
                      },
                      child: CustomPaint(
                        painter: GomokuBoardPainter(
                          game: game,
                          lastMoveIndex: game.lastMoveIndex,
                        ),
                        size: Size(boardPx, boardPx),
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
              child: Text(gs.statusMessage!,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8B4513))),
            ),
          const GomokuControls(),
        ],
      ),
    );
  }
}

class _InfoBar extends StatelessWidget {
  final GomokuGameState gs;
  const _InfoBar({required this.gs});

  @override
  Widget build(BuildContext context) {
    final game = gs.game;
    final isPlayerTurn = game.currentPlayer == (gs.isPlayerBlack ? 1 : 2);

    String statusText;
    if (game.status != GomokuGameStatus.playing) {
      statusText = game.status == GomokuGameStatus.blackWins
          ? 'Black wins!'
          : game.status == GomokuGameStatus.whiteWins
              ? 'White wins!'
              : 'Draw!';
    } else {
      statusText = isPlayerTurn
          ? 'Your turn (${game.currentPlayerName})'
          : 'AI thinking...';
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
          Text(statusText,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF5C3A28))),
          Text('Move ${game.moveHistory.length}',
              style: const TextStyle(fontSize: 13, color: Color(0xFF8B4513))),
        ],
      ),
    );
  }
}
