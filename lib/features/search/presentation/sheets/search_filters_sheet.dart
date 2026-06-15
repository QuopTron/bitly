import 'package:flutter/material.dart';

class SearchFiltersSheet extends StatefulWidget {
  const SearchFiltersSheet({super.key});

  @override
  State<SearchFiltersSheet> createState() => _SearchFiltersSheetState();
}

class _SearchFiltersSheetState extends State<SearchFiltersSheet> {
  final Set<String> _selectedSources = {};
  String _selectedQuality = 'Any';
  String _selectedType = 'track';

  static const _sources = ['youtube', 'spotify', 'soundcloud', 'deezer'];
  static const _qualities = ['Any', '128', '320', 'FLAC'];
  static const _types = ['track', 'album', 'artist'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Filters',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const Text('Source',
              style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _sources.map((s) {
              final selected = _selectedSources.contains(s);
              return FilterChip(
                label: Text(s[0].toUpperCase() + s.substring(1),
                    style: TextStyle(
                        color: selected ? Colors.white : Colors.grey)),
                selected: selected,
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      _selectedSources.add(s);
                    } else {
                      _selectedSources.remove(s);
                    }
                  });
                },
                backgroundColor: const Color(0xFF282828),
                selectedColor: const Color(0xFF1DB954),
                side: BorderSide.none,
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Text('Quality',
              style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _qualities.map((q) {
              final selected = _selectedQuality == q;
              return ChoiceChip(
                label: Text(q,
                    style: TextStyle(
                        color: selected ? Colors.white : Colors.grey)),
                selected: selected,
                onSelected: (_) =>
                    setState(() => _selectedQuality = q),
                backgroundColor: const Color(0xFF282828),
                selectedColor: const Color(0xFF1DB954),
                side: BorderSide.none,
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Text('Type',
              style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _types.map((t) {
              final selected = _selectedType == t;
              return ChoiceChip(
                label: Text(t[0].toUpperCase() + t.substring(1),
                    style: TextStyle(
                        color: selected ? Colors.white : Colors.grey)),
                selected: selected,
                onSelected: (_) =>
                    setState(() => _selectedType = t),
                backgroundColor: const Color(0xFF282828),
                selectedColor: const Color(0xFF1DB954),
                side: BorderSide.none,
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, {
                'sources': _selectedSources.toList(),
                'quality': _selectedQuality,
                'type': _selectedType,
              }),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DB954),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Apply Filters',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
