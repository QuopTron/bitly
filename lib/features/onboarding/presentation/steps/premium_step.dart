import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/onboarding_bloc.dart';
import '../bloc/onboarding_event.dart';
import '../bloc/onboarding_state.dart';
import '../widgets/setup_input_field.dart';

class PremiumStep extends StatelessWidget {
  const PremiumStep({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.workspace_premium, size: 48, color: Color(0xFF1DB954)),
          const SizedBox(height: 16),
          const Text(
            'Código Premium',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Si tienes un código premium, ingrésalo aquí. Puedes saltar este paso.',
            style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 24),
          SetupInputField(
            icon: Icons.vpn_key,
            hint: 'Código premium',
            obscureText: true,
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                context.read<OnboardingBloc>().add(ValidatePremiumCode(value));
              }
            },
          ),
          const SizedBox(height: 16),
          BlocBuilder<OnboardingBloc, OnboardingState>(
            builder: (context, state) {
              if (state.error != null) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    state.error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => context.read<OnboardingBloc>().add(NextStep()),
                child: const Text('Saltar', style: TextStyle(color: Colors.white54)),
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
