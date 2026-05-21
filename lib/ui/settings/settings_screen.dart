import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:board_master/core/constants.dart';
import 'package:board_master/core/types.dart';
import 'package:board_master/state/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goState = ref.watch(goGameProvider);
    final chessState = ref.watch(chessGameProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionTitle('Go Settings'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Board Size'),
                  subtitle: Text('${GoConstants.defaultBoardSize}x${GoConstants.defaultBoardSize}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Komi'),
                  subtitle: const Text('6.5'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Default Difficulty'),
                  subtitle: Text(_diffName(goState.difficulty)),
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle('Chinese Chess Settings'),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              title: const Text('Default Difficulty'),
              subtitle: Text(_diffName(chessState.difficulty)),
              onTap: () {},
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle('About'),
          const SizedBox(height: 8),
          const Card(
            child: Column(
              children: [
                ListTile(
                  title: Text('Version'),
                  subtitle: Text('1.0.0'),
                ),
                Divider(height: 1),
                ListTile(
                  title: Text('Board Master'),
                  subtitle: Text('Offline Go & Chinese Chess with AI'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _diffName(Difficulty d) {
    switch (d) {
      case Difficulty.easy: return 'Easy';
      case Difficulty.medium: return 'Medium';
      case Difficulty.hard: return 'Hard';
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF5C3A28),
            letterSpacing: 0.5));
  }
}
