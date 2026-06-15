import 'package:flutter/material.dart';

class SearchTab extends StatelessWidget {
  const SearchTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar'),
        backgroundColor: const Color(0xFF121212),
      ),
      body: const Center(
        child: Text(
          'Búsqueda',
          style: TextStyle(color: Colors.white54, fontSize: 18),
        ),
      ),
    );
  }
}
