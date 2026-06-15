import 'package:flutter/material.dart';

class SleepTimerSheet extends StatefulWidget {
  const SleepTimerSheet({super.key});

  @override
  State<SleepTimerSheet> createState() => _SleepTimerSheetState();
}

class _SleepTimerSheetState extends State<SleepTimerSheet> {
  String _selected = 'off';

  static const _options = [
    ('off', 'Off'),
    ('15', '15 minutes'),
    ('30', '30 minutes'),
    ('60', '1 hour'),
    ('end', 'End of track'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Sleep Timer', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          RadioGroup<String>(
            groupValue: _selected,
            onChanged: (v) => setState(() => _selected = v ?? _selected),
            child: Column(
              children: _options.map((opt) {
                return RadioListTile<String>(
                  title: Text(opt.$2, style: const TextStyle(color: Colors.white)),
                  value: opt.$1,
                  activeColor: const Color(0xFF1DB954),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
