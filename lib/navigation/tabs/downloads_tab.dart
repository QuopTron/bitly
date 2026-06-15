import 'package:flutter/material.dart';

class DownloadsTab extends StatelessWidget {
  const DownloadsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Descargas'),
        backgroundColor: const Color(0xFF121212),
      ),
      body: const Center(
        child: Text(
          'Descargas',
          style: TextStyle(color: Colors.white54, fontSize: 18),
        ),
      ),
    );
  }
}
