import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../bloc/library_bloc/library_bloc.dart';
import '../bloc/library_bloc/library_event.dart';
import '../bloc/library_bloc/library_state.dart';
import '../bloc/scan_bloc/scan_bloc.dart';
import '../bloc/scan_bloc/scan_event.dart';
import 'library_tracks_page.dart';
import 'library_albums_page.dart';
import 'library_artists_page.dart';
import '../widgets/scan_progress_bar.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final LibraryBloc _libraryBloc = GetIt.instance<LibraryBloc>();
  final ScanBloc _scanBloc = GetIt.instance<ScanBloc>();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _libraryBloc.add(LoadTracks());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: const Text('Library', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF1DB954)),
            onPressed: () => _scanBloc.add(StartScan()),
          ),
        ],
      ),
      body: Column(
        children: [
          BlocBuilder<ScanBloc, dynamic>(
            bloc: _scanBloc,
            builder: (context, state) {
              if (state is Map && state['isScanning'] == true) {
                return ScanProgressBar(
                  progress: state['progress'],
                  onCancel: () => _scanBloc.add(CancelScan()),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search library...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF282828),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (q) => _libraryBloc.add(SearchLibrary(q)),
            ),
          ),
          BlocBuilder<LibraryBloc, LibraryState>(
            bloc: _libraryBloc,
            builder: (context, state) {
              return SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'tracks', label: Text('Tracks', style: TextStyle(color: Colors.white))),
                  ButtonSegment(value: 'albums', label: Text('Albums', style: TextStyle(color: Colors.white))),
                  ButtonSegment(value: 'artists', label: Text('Artists', style: TextStyle(color: Colors.white))),
                ],
                selected: {state.currentView},
                onSelectionChanged: (v) => _libraryBloc.add(SwitchView(v.first)),
                style: SegmentedButton.styleFrom(
                  backgroundColor: const Color(0xFF282828),
                  selectedBackgroundColor: const Color(0xFF1DB954),
                ),
              );
            },
          ),
          Expanded(
            child: BlocBuilder<LibraryBloc, LibraryState>(
              bloc: _libraryBloc,
              builder: (context, state) {
                if (state.isLoading) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF1DB954)));
                }
                if (state.error != null) {
                  return Center(child: Text(state.error!, style: const TextStyle(color: Colors.red)));
                }
                switch (state.currentView) {
                  case 'albums':
                    return LibraryAlbumsPage(albums: state.albums);
                  case 'artists':
                    return LibraryArtistsPage(artists: state.artists);
                  default:
                    return LibraryTracksPage(tracks: state.tracks);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
