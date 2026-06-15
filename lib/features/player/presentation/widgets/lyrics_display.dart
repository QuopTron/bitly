import 'package:flutter/material.dart';

class LyricsDisplay extends StatelessWidget {
  final List<String> lines;
  final int currentLineIndex;

  const LyricsDisplay({
    super.key,
    required this.lines,
    required this.currentLineIndex,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: lines.length,
      itemBuilder: (context, index) {
        final isCurrent = index == currentLineIndex;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Text(
            lines[index],
            style: TextStyle(
              color: isCurrent ? const Color(0xFF1DB954) : Colors.grey[500],
              fontSize: isCurrent ? 18 : 14,
              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }
}
