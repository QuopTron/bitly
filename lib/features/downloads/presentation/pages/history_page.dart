import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/history_bloc/history_bloc.dart';
import '../bloc/history_bloc/history_event.dart';
import '../bloc/history_bloc/history_state.dart';
import '../widgets/history_item_card.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: const Text('Download History',
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
                  title: const Text('Clear History?',
                      style: TextStyle(color: Colors.white)),
                  content: const Text(
                      'Delete all download history?',
                      style: TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        context
                            .read<HistoryBloc>()
                            .add(const ClearHistory());
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
      body: BlocBuilder<HistoryBloc, HistoryState>(
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
                  Icon(Icons.history, size: 64,
                      color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No downloads yet',
                      style: TextStyle(
                          color: Colors.grey, fontSize: 18)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: state.items.length,
            itemBuilder: (context, index) {
              final item = state.items[index];
              return HistoryItemCard(
                item: item,
                onRetry: () => context
                    .read<HistoryBloc>()
                    .add(RetryDownloadEvent(item.id)),
                onDelete: () => context
                    .read<HistoryBloc>()
                    .add(DeleteFromHistory(item.id)),
              );
            },
          );
        },
      ),
    );
  }
}
