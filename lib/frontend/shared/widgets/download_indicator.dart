import 'package:flutter/material.dart';
import '../../../backend/cache/download_state.dart';
export '../../../backend/cache/download_state.dart';

class DownloadIndicator extends StatelessWidget {
  final DownloadState state;
  final double size;

  /// Default dot size used across the app for download status indicators.
  static const double defaultSize = 8;

  const DownloadIndicator({super.key, this.state = DownloadState.none, this.size = defaultSize});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _color,
        shape: BoxShape.circle,
      ),
    );
  }

  Color get _color {
    switch (state) {
      case DownloadState.completed:
        return const Color(0xFF4CAF50); // verde
      case DownloadState.inProgress:
        return const Color(0xFFFF9800); // naranja
      case DownloadState.interrupted:
        return const Color(0xFFE53935); // rojo (error)
      case DownloadState.none:
        return const Color(0xFF808080); // gris
    }
  }
}


