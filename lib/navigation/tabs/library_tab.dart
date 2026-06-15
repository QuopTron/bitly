import 'package:flutter/material.dart';

class LibraryTab extends StatelessWidget {
  const LibraryTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca'),
        backgroundColor: const Color(0xFF121212),
      ),
      body: const Center(
        child: Text(
          'Biblioteca',
          style: TextStyle(color: Colors.white54, fontSize: 18),
        ),
      ),
    );
  }
}
