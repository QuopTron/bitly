import 'package:flutter/material.dart';

class SourceBadges extends StatelessWidget {
  final List<String> sources;

  const SourceBadges({super.key, required this.sources});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: sources.map((source) {
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF1DB954).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                  color: const Color(0xFF1DB954).withValues(alpha: 0.3)),
            ),
            child: Text(
              source.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF1DB954),
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
