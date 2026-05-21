import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:board_master/core/types.dart';
import 'package:board_master/state/providers.dart';

class ChessControls extends ConsumerWidget {
  const ChessControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gs = ref.watch(chessGameProvider);
    final game = gs.game;
    final isThinking = gs.isAIThinking;
    final isPlaying = game.status == ChessGameStatus.playing;

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
            _Btn(Icons.undo, 'Undo',
                isPlaying && !isThinking && game.moveHistory.length >= 2,
                () => ref.read(chessGameProvider.notifier).undo()),
            _Btn(Icons.flag_outlined, 'Resign',
                isPlaying && !isThinking,
                () => _confirmResign(context, ref)),
            _Btn(Icons.refresh, 'New', !isThinking,
                () => _confirmNew(context, ref)),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(chessGameProvider.notifier).resign();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Resign'),
          ),
        ],
      ),
    );
  }

  void _confirmNew(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Game?'),
        content: const Text('Start a new game?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(chessGameProvider.notifier).newGame();
            },
            child: const Text('New Game'),
          ),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  const _Btn(this.icon, this.label, this.enabled, this.onTap);

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
            Text(label, style: TextStyle(fontSize: 11,
                color: const Color(0xFF5C3A28).withAlpha(enabled ? 255 : 150))),
          ],
        ),
      ),
    );
  }
}
