import 'package:flutter/material.dart';

class LibraryFiltersSheet extends StatefulWidget {
  final String currentSort;
  final String currentFilter;
  final ValueChanged<String> onSortChanged;
  final ValueChanged<String> onFilterChanged;

  const LibraryFiltersSheet({
    super.key,
    required this.currentSort,
    required this.currentFilter,
    required this.onSortChanged,
    required this.onFilterChanged,
  });

  @override
  State<LibraryFiltersSheet> createState() => _LibraryFiltersSheetState();
}

class _LibraryFiltersSheetState extends State<LibraryFiltersSheet> {
  late String _sort;
  late String _filter;

  static const _sortOptions = [
    ('name', 'Name'),
    ('date', 'Date Added'),
    ('duration', 'Duration'),
    ('size', 'File Size'),
  ];

  static const _filterOptions = [
    ('all', 'All Formats'),
    ('mp3', 'MP3'),
    ('flac', 'FLAC'),
    ('wav', 'WAV'),
    ('aac', 'AAC'),
  ];

  @override
  void initState() {
    super.initState();
    _sort = widget.currentSort;
    _filter = widget.currentFilter;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Sort by', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: _sortOptions.map((opt) {
              final selected = _sort == opt.$1;
              return ChoiceChip(
                label: Text(opt.$2),
                selected: selected,
                onSelected: (_) => setState(() => _sort = opt.$1),
                selectedColor: const Color(0xFF1DB954),
                labelStyle: TextStyle(color: selected ? Colors.black : Colors.white),
                backgroundColor: const Color(0xFF282828),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          const Text('Filter by format', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: _filterOptions.map((opt) {
              final selected = _filter == opt.$1;
              return ChoiceChip(
                label: Text(opt.$2),
                selected: selected,
                onSelected: (_) => setState(() => _filter = opt.$1),
                selectedColor: const Color(0xFF1DB954),
                labelStyle: TextStyle(color: selected ? Colors.black : Colors.white),
                backgroundColor: const Color(0xFF282828),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onSortChanged(_sort);
                widget.onFilterChanged(_filter);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DB954),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: const Text('Apply', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
