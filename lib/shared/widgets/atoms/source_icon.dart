import 'package:flutter/material.dart';

class SourceIcon extends StatelessWidget {
  final String source;
  final double size;

  const SourceIcon({super.key, required this.source, this.size = 16});

  IconData _icon() {
    switch (source.toLowerCase()) {
      case 'deezer':
        return Icons.audiotrack;
      case 'qobuz':
        return Icons.music_note;
      case 'tidal':
        return Icons.waves;
      case 'spotify':
        return Icons.circle;
      case 'youtube':
      case 'yt':
      case 'youtube_music':
        return Icons.play_circle_fill;
      case 'soundcloud':
        return Icons.cloud;
      case 'bandcamp':
        return Icons.shopping_bag;
      default:
        return Icons.web;
    }
  }

  Color _color() {
    switch (source.toLowerCase()) {
      case 'deezer':
        return const Color(0xFFA238FF);
      case 'qobuz':
        return const Color(0xFF8C4799);
      case 'tidal':
        return const Color(0xFF00FFFF);
      case 'spotify':
        return const Color(0xFF1DB954);
      case 'youtube':
      case 'yt':
      case 'youtube_music':
        return const Color(0xFFFF0000);
      case 'soundcloud':
        return const Color(0xFFFF7700);
      case 'bandcamp':
        return const Color(0xFF629AA6);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Icon(_icon(), color: _color(), size: size);
  }
}
