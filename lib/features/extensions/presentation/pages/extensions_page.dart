import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import '../bloc/extensions_bloc/extensions_bloc.dart';
import '../bloc/extensions_bloc/extensions_event.dart';
import '../bloc/extensions_bloc/extensions_state.dart';
import '../widgets/extension_card.dart';
import '../../../../shared/widgets/atoms/empty_state.dart';
import '../../../../core/router/route_names.dart';

class ExtensionsPage extends StatelessWidget {
  const ExtensionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ExtensionsBloc>(
      create: (_) => GetIt.instance<ExtensionsBloc>()..add(LoadExtensions()),
      child: const _ExtensionsView(),
    );
  }
}

class _ExtensionsView extends StatelessWidget {
  const _ExtensionsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Extensiones'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.store),
            onPressed: () {
              context.go(RouteNames.extensionsStore.path);
            },
          ),
        ],
      ),
      body: BlocBuilder<ExtensionsBloc, ExtensionsState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.error != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 8),
                  Text(state.error!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.read<ExtensionsBloc>().add(LoadExtensions()),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }
          if (state.extensions.isEmpty) {
            return const EmptyState(
              icon: Icons.extension_off,
              title: 'No hay extensiones instaladas',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: state.extensions.length,
            itemBuilder: (context, index) {
              final ext = state.extensions[index];
              return ExtensionCard(
                extension: ext,
                onToggle: () {
                  context.read<ExtensionsBloc>().add(
                    ToggleExtensionEvent(ext.id, !ext.isEnabled),
                  );
                },
                onTap: () {
                  // Show extension details
                },
              );
            },
          );
        },
      ),
    );
  }
}
