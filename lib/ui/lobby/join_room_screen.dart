import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:board_master/state/providers.dart';

class JoinRoomScreen extends ConsumerStatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  ConsumerState<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends ConsumerState<JoinRoomScreen> {
  final _controller = TextEditingController();
  bool _joining = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Room')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter room code',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 32, letterSpacing: 8, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: 'ABCD',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 32, letterSpacing: 8),
                counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 8),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
              ),
            const Spacer(),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _joining ? null : _join,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5C3A28),
                  foregroundColor: Colors.white,
                ),
                child: _joining
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Join', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _join() async {
    final code = _controller.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _error = 'Please enter a room code');
      return;
    }
    setState(() { _joining = true; _error = null; });
    try {
      final conn = ref.read(connectionServiceProvider);
      await conn.joinRoom(code);
      if (!mounted) return;

      final st = conn.currentState;
      final game = st.game ?? 'go';
      final color = st.myColor ?? 'white';

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
    } catch (e) {
      setState(() { _error = 'Room not found or full'; _joining = false; });
    }
  }
}
