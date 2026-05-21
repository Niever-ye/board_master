import 'package:flutter/material.dart';
import 'package:board_master/core/types.dart';

class DifficultyChip extends StatelessWidget {
  final Difficulty difficulty;
  final ValueChanged<Difficulty> onChanged;

  const DifficultyChip({
    super.key,
    required this.difficulty,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Difficulty>(
      initialValue: difficulty,
      onSelected: onChanged,
      icon: const Icon(Icons.tune, size: 20),
      itemBuilder: (context) => [
        _item(Difficulty.easy, 'Easy'),
        _item(Difficulty.medium, 'Medium'),
        _item(Difficulty.hard, 'Hard'),
      ],
    );
  }

  PopupMenuItem<Difficulty> _item(Difficulty d, String label) {
    return PopupMenuItem(
      value: d,
      child: Row(
        children: [
          if (d == difficulty)
            const Icon(Icons.check, size: 16, color: Colors.green)
          else
            const SizedBox(width: 16),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}
