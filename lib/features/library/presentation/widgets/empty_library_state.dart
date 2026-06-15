import 'package:flutter/material.dart';

class EmptyLibraryState extends StatelessWidget {
  const EmptyLibraryState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.library_music, size: 80, color: Colors.grey[700]),
          const SizedBox(height: 16),
          Text(
            'Your library is empty',
            style: TextStyle(color: Colors.grey[400], fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the refresh button to scan your music',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }
}
