import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../bloc/store_bloc/store_bloc.dart';
import '../bloc/store_bloc/store_event.dart';
import '../bloc/store_bloc/store_state.dart';
import '../widgets/store_extension_card.dart';
import '../../../../shared/widgets/atoms/empty_state.dart';

class StorePage extends StatelessWidget {
  const StorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<StoreBloc>(
      create: (_) => GetIt.instance<StoreBloc>()..add(const LoadStoreExtensions()),
      child: const _StoreView(),
    );
  }
}

class _StoreView extends StatefulWidget {
  const _StoreView();

  @override
  State<_StoreView> createState() => _StoreViewState();
}

class _StoreViewState extends State<_StoreView> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tienda de extensiones'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar extensiones...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          context.read<StoreBloc>().add(
                            const LoadStoreExtensions(),
                          );
                        },
                      )
                    : null,
              ),
              onSubmitted: (query) {
                if (query.isNotEmpty) {
                  context.read<StoreBloc>().add(SearchStore(query));
                }
              },
            ),
          ),
          Expanded(
            child: BlocBuilder<StoreBloc, StoreState>(
              builder: (context, state) {
                if (state.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.error != null) {
                  return Center(child: Text('Error: ${state.error}'));
                }
                if (state.extensions.isEmpty) {
                  return const EmptyState(
                    icon: Icons.store,
                    title: 'No hay extensiones disponibles',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: state.extensions.length,
                  itemBuilder: (context, index) {
                    final ext = state.extensions[index];
                    return StoreExtensionCard(
                      extension: ext,
                      onInstall: () {
                        context.read<StoreBloc>().add(
                          InstallFromStore(ext.id),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
