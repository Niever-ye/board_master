import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:board_master/ui/theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Board Master'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Text(
                'Choose a Game',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: _GameCard(
                        title: '围棋',
                        subtitle: 'Go',
                        icon: Icons.circle_outlined,
                        color: const Color(0xFF5C3A28),
                        onTap: () => context.go('/go'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _GameCard(
                        title: '中国象棋',
                        subtitle: 'Chinese Chess',
                        icon: Icons.grid_on,
                        color: const Color(0xFF8B2500),
                        onTap: () => context.go('/chess'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _GameCard(
                        title: '五子棋',
                        subtitle: 'Gomoku',
                        icon: Icons.circle_outlined,
                        color: const Color(0xFF2E7D32),
                        onTap: () => context.go('/gomoku'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SecondaryButton(
                icon: Icons.library_books,
                label: 'Game Records',
                onTap: () => context.go('/records'),
              ),
              const SizedBox(height: 8),
              _SecondaryButton(
                icon: Icons.settings,
                label: 'Settings',
                onTap: () => context.go('/settings'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _GameCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [color.withAlpha(230), color],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 48, color: Colors.white.withAlpha(230)),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withAlpha(200),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SecondaryButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.accent,
        side: BorderSide(color: AppTheme.accent.withAlpha(100)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
