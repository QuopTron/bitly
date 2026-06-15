import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/onboarding_bloc.dart';
import '../bloc/onboarding_event.dart';

class DirectoriesStep extends StatelessWidget {
  const DirectoriesStep({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.folder, size: 48, color: Color(0xFF1DB954)),
          const SizedBox(height: 16),
          const Text(
            'Directorio de Descargas',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Selecciona la carpeta donde se guardarán tus descargas.',
            style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 24),
          Card(
            color: const Color(0xFF1E1E1E),
            child: ListTile(
              leading: const Icon(Icons.folder_open, color: Color(0xFF1DB954)),
              title: const Text(
                'Descargas/Música',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                'Ruta por defecto',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
              ),
              trailing: const Icon(Icons.edit, color: Colors.white54),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Selector de directorio')),
                );
              },
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => context.read<OnboardingBloc>().add(PreviousStep()),
                child: const Text('Atrás', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1DB954),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: () => context.read<OnboardingBloc>().add(NextStep()),
                child: const Text('Siguiente', style: TextStyle(color: Colors.black)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
