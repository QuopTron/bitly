import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/queue_bloc/queue_bloc.dart';
import '../bloc/queue_bloc/queue_event.dart';
import '../bloc/queue_bloc/queue_state.dart';
import '../widgets/queue_item_card.dart';
import '../widgets/queue_controls.dart';

class QueuePage extends StatelessWidget {
  const QueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: const Text('Download Queue',
            style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep,
                color: Color(0xFF1DB954)),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: const Color(0xFF282828),
                  title: const Text('Clear Queue?',
                      style: TextStyle(color: Colors.white)),
                  content: const Text(
                      'Remove all items from the queue?',
                      style: TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        context
                            .read<QueueBloc>()
                            .add(const ClearQueue());
                        Navigator.pop(context);
                      },
                      child: const Text('Clear',
                          style: TextStyle(
                              color: Color(0xFF1DB954))),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<QueueBloc, QueueState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF1DB954)));
          }
          if (state.items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.download_outlined,
                      size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Queue is empty',
                      style: TextStyle(
                          color: Colors.grey, fontSize: 18)),
                ],
              ),
            );
          }
          return Column(
            children: [
              const QueueControls(),
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: state.items.length,
                  onReorder: (old, new_) => context
                      .read<QueueBloc>()
                      .add(ReorderQueue(old, new_)),
                  itemBuilder: (context, index) {
                    final item = state.items[index];
                    return QueueItemCard(
                      key: ValueKey(item.id),
                      item: item,
                      onCancel: () => context
                          .read<QueueBloc>()
                          .add(RemoveFromQueue(item.id)),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
