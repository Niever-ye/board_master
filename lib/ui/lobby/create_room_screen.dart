import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:board_master/core/types.dart';
import 'package:board_master/network/connection_service.dart';
import 'package:board_master/state/providers.dart';

class CreateRoomScreen extends ConsumerStatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  GameType _selectedGame = GameType.go;
  int _boardSize = 19;
  bool _creating = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Room')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Select Game', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _GameSelector(
              selected: _selectedGame,
              onChanged: (g) => setState(() => _selectedGame = g),
            ),
            if (_selectedGame == GameType.go) ...[
              const SizedBox(height: 20),
              const Text('Board Size', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _BoardSizeSelector(
                value: _boardSize,
                onChanged: (s) => setState(() => _boardSize = s),
              ),
            ],
            const Spacer(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
              ),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _creating ? null : _createRoom,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5C3A28),
                  foregroundColor: Colors.white,
                ),
                child: _creating
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Create Room', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _createRoom() async {
    setState(() { _creating = true; _error = null; });
    try {
      final conn = ref.read(connectionServiceProvider);
      final gameName = _selectedGame == GameType.go ? 'go'
          : _selectedGame == GameType.chess ? 'chess' : 'gomoku';
      await conn.createRoom(gameName, boardSize: _boardSize);
      if (!mounted) return;

      final st = conn.currentState;
      _navigateToGame(st.game ?? gameName, conn);
    } catch (e) {
      setState(() { _error = e.toString(); _creating = false; });
    }
  }

  void _navigateToGame(String game, GameConnectionService conn) {
    final st = conn.currentState;
    final color = st.myColor ?? 'black';

    // Initialize the appropriate notifier
    switch (game) {
      case 'go':
        ref.read(goGameProvider.notifier).initializeOnline(conn, myColor: color);
        context.go('/go');
        break;
      case 'chess':
        ref.read(chessGameProvider.notifier).initializeOnline(conn, myColor: color == 'black' ? 'red' : 'black');
        context.go('/chess');
        break;
      case 'gomoku':
        ref.read(gomokuGameProvider.notifier).initializeOnline(conn, myColor: color);
        context.go('/gomoku');
        break;
      default:
        context.go('/go');
    }
  }
}

class _GameSelector extends StatelessWidget {
  final GameType selected;
  final ValueChanged<GameType> onChanged;

  const _GameSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: GameType.values.map((g) {
        final name = g == GameType.go ? 'Go' : g == GameType.chess ? 'Chess' : 'Gomoku';
        final selected = this.selected == g;
        return ChoiceChip(
          label: Text(name),
          selected: selected,
          onSelected: (_) => onChanged(g),
        );
      }).toList(),
    );
  }
}

class _BoardSizeSelector extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _BoardSizeSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      segments: const [
        ButtonSegment(value: 9, label: Text('9x9')),
        ButtonSegment(value: 13, label: Text('13x13')),
        ButtonSegment(value: 19, label: Text('19x19')),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}
