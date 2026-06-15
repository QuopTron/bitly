import 'package:flutter/material.dart';

class AvailabilityIndicator extends StatelessWidget {
  final bool isAvailable;
  final double size;

  const AvailabilityIndicator({
    super.key,
    required this.isAvailable,
    this.size = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isAvailable
            ? const Color(0xFF1DB954)
            : Colors.red[400],
      ),
    );
  }
}
