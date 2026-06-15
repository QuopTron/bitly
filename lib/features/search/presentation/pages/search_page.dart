import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/search_bloc.dart';
import '../bloc/search_event.dart';
import '../bloc/search_state.dart';
import '../widgets/search_bar.dart';
import '../widgets/search_filters.dart';
import '../widgets/track_result_card.dart';
import '../widgets/album_result_card.dart';
import '../widgets/artist_result_card.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: const CustomSearchBar(),
        elevation: 0,
      ),
      body: Column(
        children: [
          const SearchFilters(),
          Expanded(
            child: BlocBuilder<SearchBloc, SearchState>(
              builder: (context, state) {
                if (state.isLoading && state.tracks.isEmpty) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF1DB954)));
                }
                if (state.error != null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(state.error!,
                          style: const TextStyle(color: Colors.red)),
                    ),
                  );
                }
                if (state.query.isEmpty) {
                  return _buildRecentSearches(context, state);
                }
                if (state.tracks.isEmpty &&
                    state.albums.isEmpty &&
                    state.artists.isEmpty) {
                  return const Center(
                    child: Text('No results found',
                        style: TextStyle(color: Colors.grey)),
                  );
                }
                return _buildResultsList(context, state);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSearches(BuildContext context, SearchState state) {
    if (state.recentSearches.isEmpty) {
      return const Center(
        child: Text('Search for music',
            style: TextStyle(color: Colors.grey, fontSize: 18)),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent Searches',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            TextButton(
              onPressed: () =>
                  context.read<SearchBloc>().add(const ClearRecent()),
              child: const Text('Clear',
                  style: TextStyle(color: Color(0xFF1DB954))),
            ),
          ],
        ),
        ...state.recentSearches.map((q) => ListTile(
              title: Text(q, style: const TextStyle(color: Colors.white)),
              leading: const Icon(Icons.history, color: Colors.grey),
              onTap: () => context
                  .read<SearchBloc>()
                  .add(QueryChanged(q)),
            )),
      ],
    );
  }

  Widget _buildResultsList(BuildContext context, SearchState state) {
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        if (state.tracks.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Tracks',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ),
          ...state.tracks
              .map((t) => TrackResultCard(track: t)),
        ],
        if (state.albums.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Albums',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ),
          ...state.albums
              .map((a) => AlbumResultCard(album: a)),
        ],
        if (state.artists.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Artists',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ),
          ...state.artists
              .map((a) => ArtistResultCard(artist: a)),
        ],
        if (state.isLoading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF1DB954))),
          ),
      ],
    );
  }
}
