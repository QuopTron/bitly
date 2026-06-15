import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/search_bloc.dart';
import '../bloc/search_event.dart';

class CustomSearchBar extends StatefulWidget {
  const CustomSearchBar({super.key});

  @override
  State<CustomSearchBar> createState() => _CustomSearchBarState();
}

class _CustomSearchBarState extends State<CustomSearchBar> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isUrl(String text) {
    return text.startsWith('http://') ||
        text.startsWith('https://') ||
        text.startsWith('www.');
  }

  void _onSubmit(String value) {
    if (_isUrl(value)) {
      context.read<SearchBloc>().add(SearchByUrlEvent(value));
    } else {
      context.read<SearchBloc>().add(QueryChanged(value));
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Search tracks, albums, artists or paste URL...',
        hintStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: const Color(0xFF282828),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        prefixIcon:
            const Icon(Icons.search, color: Colors.grey),
        suffixIcon: _controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, color: Colors.grey),
                onPressed: () {
                  _controller.clear();
                  context
                      .read<SearchBloc>()
                      .add(const QueryChanged(''));
                },
              )
            : null,
      ),
      onChanged: (value) {
        setState(() {});
        if (!_isUrl(value)) {
          context.read<SearchBloc>().add(QueryChanged(value));
        }
      },
      onSubmitted: _onSubmit,
      textInputAction: TextInputAction.search,
    );
  }
}
