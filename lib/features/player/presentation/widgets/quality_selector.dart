import 'package:flutter/material.dart';
import '../../domain/entities/audio_quality.dart';

class QualitySelector extends StatefulWidget {
  const QualitySelector({super.key});

  @override
  State<QualitySelector> createState() => _QualitySelectorState();
}

class _QualitySelectorState extends State<QualitySelector> {
  AudioQuality _selected = AudioQuality.mp3_320;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<AudioQuality>(
      onSelected: (q) => setState(() => _selected = q),
      icon: const Icon(Icons.settings, color: Colors.grey, size: 20),
      color: const Color(0xFF282828),
      initialValue: _selected,
      itemBuilder: (_) => AudioQuality.values.map((q) {
        return PopupMenuItem(
          value: q,
          child: Row(
            children: [
              Icon(
                Icons.check,
                size: 16,
                color: q == _selected ? const Color(0xFF1DB954) : Colors.transparent,
              ),
              const SizedBox(width: 8),
              Text(q.label, style: const TextStyle(color: Colors.white)),
            ],
          ),
        );
      }).toList(),
    );
  }
}
