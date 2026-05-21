import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:board_master/core/types.dart';
import 'package:board_master/models/go/go_game.dart';
import 'package:board_master/models/go/go_position.dart';
import 'package:board_master/state/go_game_notifier.dart';
import 'package:board_master/state/providers.dart';
import 'package:board_master/ui/go/go_board_painter.dart';
import 'package:board_master/ui/go/go_controls.dart';
import 'package:board_master/ui/widgets/thinking_indicator.dart';
import 'package:board_master/ui/widgets/difficulty_chip.dart';

class GoBoardScreen extends ConsumerStatefulWidget {
  const GoBoardScreen({super.key});

  @override
  ConsumerState<GoBoardScreen> createState() => _GoBoardScreenState();
}

class _GoBoardScreenState extends ConsumerState<GoBoardScreen> {
  double _boardScale = 1.0;

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(goGameProvider);
    final game = gameState.game;
    final pos = game.currentPosition;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Go'),
        actions: [
          DifficultyChip(
            difficulty: gameState.difficulty,
            onChanged: (d) =>
                ref.read(goGameProvider.notifier).setDifficulty(d),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Info bar
          _InfoBar(gameState: gameState),
          // Board
          Expanded(
            child: GestureDetector(
              onScaleStart: (_) {},
              onScaleUpdate: (details) {
                setState(() {
                  _boardScale = (_boardScale * details.scale).clamp(0.8, 2.5);
                });
              },
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final boardWidth = constraints.maxWidth * _boardScale;
                  final boardHeight = constraints.maxHeight * _boardScale;
                  final boardSize = boardWidth < boardHeight
                      ? boardWidth
                      : boardHeight;

                  return InteractiveViewer(
                    transformationController: TransformationController(),
                    minScale: 0.8,
                    maxScale: 2.5,
                    child: Center(
                      child: SizedBox(
                        width: boardSize,
                        height: boardSize,
                        child: GestureDetector(
                          onTapUp: (details) {
                            if (gameState.isAIThinking ||
                                game.status != GoGameStatus.playing) {
                              return;
                            }

                            final cellSize =
                                boardSize / (pos.size - 1);
                            final padding = cellSize * 0.6;
                            final col = ((details.localPosition.dx - padding) /
                                    cellSize)
                                .round();
                            final row = ((details.localPosition.dy - padding) /
                                    cellSize)
                                .round();

                            if (pos.isWithinBounds(row, col)) {
                              ref
                                  .read(goGameProvider.notifier)
                                  .placeStone(row, col);
                            }
                          },
                          child: CustomPaint(
                            painter: GoBoardPainter(
                              position: pos,
                              lastMoveIndex: game.moveHistory.isNotEmpty
                                  ? _lastMoveIndex(pos, game)
                                  : null,
                              boardSize: boardSize,
                            ),
                            size: Size(boardSize, boardSize),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // Captures display
          _CapturesDisplay(pos: pos),
          // Thinking indicator
          if (gameState.isAIThinking) const ThinkingIndicator(),
          // Controls
          const GoControls(),
        ],
      ),
    );
  }

  int? _lastMoveIndex(GoPosition pos, GoGame game) {
    if (game.moveHistory.isEmpty) return null;
    final lastMove = game.moveHistory.last;
    if (lastMove.isPlacement) {
      return pos.index(lastMove.row!, lastMove.col!);
    }
    return null;
  }
}

class _InfoBar extends StatelessWidget {
  final GoGameState gameState;

  const _InfoBar({required this.gameState});

  @override
  Widget build(BuildContext context) {
    final game = gameState.game;
    final isPlayerTurn = game.currentPlayer ==
        (gameState.isPlayerBlack ? Stone.black : Stone.white);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF0E6D3),
        border: Border(bottom: BorderSide(color: Color(0xFFDDD0C0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Turn indicator
          Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: game.currentPlayer == Stone.black
                        ? [Colors.grey.shade700, Colors.black]
                        : [Colors.white, Colors.grey.shade300],
                  ),
                  border: Border.all(color: Colors.grey.shade500, width: 0.5),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                game.status == GoGameStatus.playing
                    ? (isPlayerTurn ? 'Your turn' : 'AI thinking...')
                    : 'Game over',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF5C3A28),
                ),
              ),
            ],
          ),
          // Move count + status message
          if (gameState.statusMessage != null)
            Expanded(
              child: Text(
                gameState.statusMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8B4513),
                ),
              ),
            ),
          Text(
            'Move ${game.moveHistory.length}',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF8B4513),
            ),
          ),
        ],
      ),
    );
  }
}

class _CapturesDisplay extends StatelessWidget {
  final GoPosition pos;

  const _CapturesDisplay({required this.pos});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _CaptureChip('B', pos.blackCaptures, Colors.black),
          const SizedBox(width: 24),
          _CaptureChip('W', pos.whiteCaptures, Colors.white),
          const SizedBox(width: 24),
          Text(
            'Komi: 6.5',
            style: TextStyle(
              fontSize: 12,
              color: Colors.brown.shade400,
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptureChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _CaptureChip(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$label caps: $count',
          style: TextStyle(
            fontSize: 12,
            color: Colors.brown.shade500,
          ),
        ),
      ],
    );
  }
}
