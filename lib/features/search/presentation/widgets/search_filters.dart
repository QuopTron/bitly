import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/search_bloc.dart';
import '../bloc/search_event.dart';

class SearchFilters extends StatelessWidget {
  const SearchFilters({super.key});

  static const _types = ['track', 'album', 'artist'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _types.map((type) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(type[0].toUpperCase() + type.substring(1),
                    style: const TextStyle(color: Colors.white)),
                selected: false,
                onSelected: (_) => context
                    .read<SearchBloc>()
                    .add(TypeFilterChanged(type)),
                backgroundColor: const Color(0xFF282828),
                selectedColor: const Color(0xFF1DB954),
                checkmarkColor: Colors.white,
                side: BorderSide.none,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
