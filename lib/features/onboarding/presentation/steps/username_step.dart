import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/onboarding_bloc.dart';
import '../bloc/onboarding_event.dart';
import '../widgets/setup_input_field.dart';

class UsernameStep extends StatelessWidget {
  const UsernameStep({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.person, size: 48, color: Color(0xFF1DB954)),
          const SizedBox(height: 16),
          const Text(
            'Tu Nombre de Usuario',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Elige un nombre para personalizar tu perfil.',
            style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 24),
          SetupInputField(
            icon: Icons.person_outline,
            hint: 'Usuario',
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                context.read<OnboardingBloc>().add(SaveUsername(value));
                context.read<OnboardingBloc>().add(NextStep());
              }
            },
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
