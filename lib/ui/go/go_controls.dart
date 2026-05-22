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
    final isOnline = gameState.gameMode == GameMode.online;
    final canAct = isPlaying && !isThinking && (isOnline ? gameState.isMyTurn : true);

    // Show undo request dialog in online mode
    if (isOnline && gameState.statusMessage == 'Opponent requests undo') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showUndoRequestDialog(context, ref);
      });
    }
    if (isOnline && gameState.statusMessage == 'Opponent wants a rematch') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showRematchRequestDialog(context, ref);
      });
    }

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
              enabled: isPlaying && !isThinking && game.moveHistory.length >= 2 && (isOnline ? gameState.isMyTurn : true),
              onTap: () => ref.read(goGameProvider.notifier).undo(),
            ),
            _ControlButton(
              icon: Icons.pause_circle_outline,
              label: 'Pass',
              enabled: canAct,
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
              label: isOnline ? 'Rematch' : 'New',
              enabled: !isThinking,
              onTap: () => _confirmNewGame(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  void _showUndoRequestDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Undo Request'),
        content: const Text('Opponent wants to undo the last move.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(goGameProvider.notifier).rejectUndo();
            },
            child: const Text('Reject'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(goGameProvider.notifier).acceptUndo();
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  void _showRematchRequestDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rematch?'),
        content: const Text('Opponent wants a rematch.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(goGameProvider.notifier).newGame();
            },
            child: const Text('Reject'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(goGameProvider.notifier).acceptNewGame();
            },
            child: const Text('Accept'),
          ),
        ],
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
    final gameState = ref.read(goGameProvider);
    final isOnline = gameState.gameMode == GameMode.online;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isOnline ? 'Request Rematch?' : 'New Game?'),
        content: Text(isOnline
            ? 'Request a rematch with your opponent?'
            : 'Start a new game? Current game will be lost.'),
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
            child: Text(isOnline ? 'Request' : 'New Game'),
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
