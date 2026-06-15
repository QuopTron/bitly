import 'package:flutter/material.dart';

class QualityBadge extends StatelessWidget {
  final String quality;
  final double fontSize;

  const QualityBadge({super.key, required this.quality, this.fontSize = 10});

  Color _bgColor() {
    if (quality.contains('FLAC') || quality.contains('lossless')) {
      return const Color(0xFF00E676);
    }
    if (quality.contains('320')) return Colors.orange;
    if (quality.contains('128')) return Colors.grey;
    return Colors.blueGrey;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _bgColor().withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _bgColor().withValues(alpha: 0.5), width: 1),
      ),
      child: Text(
        quality.toUpperCase(),
        style: TextStyle(
          color: _bgColor(),
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
