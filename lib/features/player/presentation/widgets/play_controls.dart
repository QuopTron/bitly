import 'package:flutter/material.dart';

class PlayControls extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  const PlayControls({
    super.key,
    required this.isPlaying,
    required this.onPlay,
    required this.onPause,
    required this.onNext,
    required this.onPrevious,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isPlaying ? onPause : onPlay,
      child: Container(
        width: 64,
        height: 64,
        decoration: const BoxDecoration(
          color: Color(0xFF1DB954),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isPlaying ? Icons.pause : Icons.play_arrow,
          color: Colors.black,
          size: 36,
        ),
      ),
    );
  }
}
