import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../bloc/collections_bloc.dart';
import '../bloc/collections_event.dart';
import '../bloc/collections_state.dart';
import '../widgets/collection_card.dart';
import '../../../../shared/widgets/atoms/empty_state.dart';

class CollectionsPage extends StatelessWidget {
  const CollectionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CollectionsBloc>(
      create: (_) => GetIt.instance<CollectionsBloc>()..add(LoadCollections()),
      child: const _CollectionsView(),
    );
  }
}

class _CollectionsView extends StatelessWidget {
  const _CollectionsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Colecciones'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateDialog(context),
          ),
        ],
      ),
      body: BlocBuilder<CollectionsBloc, CollectionsState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.collections.isEmpty) {
            return const EmptyState(
              icon: Icons.playlist_play,
              title: 'No hay colecciones aún',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: state.collections.length,
            itemBuilder: (context, index) {
              final collection = state.collections[index];
              return CollectionCard(
                collection: collection,
                onTap: () {
                  // Navigate to collection detail
                },
                onDelete: () {
                  context.read<CollectionsBloc>().add(
                    DeleteCollectionEvent(collection.id),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva colección'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                hintText: 'Mi playlist',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                hintText: 'Opcional',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                context.read<CollectionsBloc>().add(
                  CreateCollectionEvent(
                    nameController.text,
                    descController.text.isNotEmpty ? descController.text : null,
                  ),
                );
                Navigator.pop(ctx);
              }
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }
}
