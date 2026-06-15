import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/queue_bloc/queue_bloc.dart';
import '../bloc/queue_bloc/queue_event.dart';

class QueueControls extends StatelessWidget {
  const QueueControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {/* play all */},
              icon: const Icon(Icons.play_arrow,
                  color: Color(0xFF1DB954)),
              label: const Text('Play All',
                  style: TextStyle(color: Color(0xFF1DB954))),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF1DB954)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {/* pause all */},
              icon: const Icon(Icons.pause,
                  color: Colors.orange),
              label: const Text('Pause All',
                  style: TextStyle(color: Colors.orange)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.orange),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => context
                  .read<QueueBloc>()
                  .add(const ClearQueue()),
              icon: const Icon(Icons.stop,
                  color: Colors.red),
              label: const Text('Cancel All',
                  style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
