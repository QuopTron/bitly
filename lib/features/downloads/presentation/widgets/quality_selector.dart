import 'package:flutter/material.dart';

class QualitySelector extends StatelessWidget {
  final String selectedQuality;
  final ValueChanged<String> onChanged;

  const QualitySelector({
    super.key,
    required this.selectedQuality,
    required this.onChanged,
  });

  static const _qualities = [
    {'label': '128 kbps', 'value': '128'},
    {'label': '320 kbps', 'value': '320'},
    {'label': 'FLAC', 'value': 'flac'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF282828),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedQuality,
          dropdownColor: const Color(0xFF282828),
          icon: const Icon(Icons.arrow_drop_down,
              color: Color(0xFF1DB954)),
          style: const TextStyle(color: Colors.white),
          items: _qualities.map((q) {
            return DropdownMenuItem(
              value: q['value'],
              child: Row(
                children: [
                  Icon(Icons.audio_file,
                      size: 16,
                      color: selectedQuality == q['value']
                          ? const Color(0xFF1DB954)
                          : Colors.grey),
                  const SizedBox(width: 8),
                  Text(q['label']!),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ),
    );
  }
}
