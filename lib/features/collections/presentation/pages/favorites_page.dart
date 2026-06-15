import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../bloc/collections_bloc.dart';
import '../bloc/collections_event.dart';
import '../bloc/collections_state.dart';
import '../../../../core/theme/color_scheme.dart';
import '../../../../shared/widgets/atoms/empty_state.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CollectionsBloc>(
      create: (_) => GetIt.instance<CollectionsBloc>()..add(LoadCollections()),
      child: const _FavoritesView(),
    );
  }
}

class _FavoritesView extends StatelessWidget {
  const _FavoritesView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favoritos'),
        centerTitle: true,
      ),
      body: BlocBuilder<CollectionsBloc, CollectionsState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.favoriteAlbums.isEmpty) {
            return const EmptyState(
              icon: Icons.favorite_border,
              title: 'No tienes favoritos aún',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: state.favoriteAlbums.length,
            itemBuilder: (context, index) {
              final album = state.favoriteAlbums[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.surfaceHigh,
                  child: Icon(Icons.album, color: theme.colorScheme.primary),
                ),
                title: Text(album.title),
                subtitle: Text(album.artist),
                trailing: IconButton(
                  icon: Icon(Icons.favorite, color: theme.colorScheme.error),
                  onPressed: () {},
                ),
              );
            },
          );
        },
      ),
    );
  }
}
