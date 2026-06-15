import 'package:flutter/material.dart';

class MoreTab extends StatelessWidget {
  const MoreTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Más'),
        backgroundColor: const Color(0xFF121212),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _menuItem(Icons.settings, 'Ajustes', () {}),
          _menuItem(Icons.extension, 'Extensiones', () {}),
          _menuItem(Icons.info_outline, 'Acerca de', () {}),
        ],
      ),
    );
  }

  Widget _menuItem(IconData icon, String label, VoidCallback onTap) {
    return Card(
      color: const Color(0xFF1E1E1E),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF1DB954)),
        title: Text(label, style: const TextStyle(color: Colors.white)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white54),
        onTap: onTap,
      ),
    );
  }
}
