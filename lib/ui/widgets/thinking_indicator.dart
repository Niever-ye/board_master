import 'package:flutter/material.dart';

class ThinkingIndicator extends StatelessWidget {
  const ThinkingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: const Color(0xFFE8DCC8),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5C3A28)),
            ),
          ),
          SizedBox(width: 8),
          Text(
            'AI is thinking...',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF5C3A28),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
