import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:board_master/core/types.dart';
import 'package:board_master/state/providers.dart';

class GoControls extends ConsumerWidget {
  const GoControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(goGameProvider);
    final game = gameState.game;
    final isThinking = gameState.isAIThinking;
    final isPlaying = game.status == GoGameStatus.playing;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(230),
        border: const Border(top: BorderSide(color: Color(0xFFDDD0C0))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _ControlButton(
              icon: Icons.undo,
              label: 'Undo',
              enabled: isPlaying && !isThinking && game.moveHistory.length >= 2,
              onTap: () => ref.read(goGameProvider.notifier).undo(),
            ),
            _ControlButton(
              icon: Icons.pause_circle_outline,
              label: 'Pass',
              enabled: isPlaying && !isThinking,
              onTap: () => ref.read(goGameProvider.notifier).pass(),
            ),
            _ControlButton(
              icon: Icons.flag_outlined,
              label: 'Resign',
              enabled: isPlaying && !isThinking,
              onTap: () => _confirmResign(context, ref),
            ),
            _ControlButton(
              icon: Icons.refresh,
              label: 'New',
              enabled: !isThinking,
              onTap: () => _confirmNewGame(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmResign(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resign?'),
        content: const Text('Are you sure you want to resign?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(goGameProvider.notifier).resign();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Resign'),
          ),
        ],
      ),
    );
  }

  void _confirmNewGame(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Game?'),
        content: const Text('Start a new game? Current game will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(goGameProvider.notifier).newGame();
            },
            child: const Text('New Game'),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF5C3A28), size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: const Color(0xFF5C3A28).withAlpha(enabled ? 255 : 150),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
