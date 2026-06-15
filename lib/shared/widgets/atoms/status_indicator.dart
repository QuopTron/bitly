import 'package:flutter/material.dart';

enum StatusType { success, error, warning, info }

class StatusIndicator extends StatelessWidget {
  final StatusType status;
  final double size;
  final bool animated;

  const StatusIndicator({
    super.key,
    this.status = StatusType.info,
    this.size = 10,
    this.animated = true,
  });

  Color _color() {
    switch (status) {
      case StatusType.success:
        return Colors.green;
      case StatusType.error:
        return Colors.red;
      case StatusType.warning:
        return Colors.orange;
      case StatusType.info:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _color(),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _color().withValues(alpha: 0.5),
            blurRadius: size * 0.5,
            spreadRadius: size * 0.1,
          ),
        ],
      ),
    );
  }
}
