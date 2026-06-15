import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/onboarding_bloc.dart';
import '../bloc/onboarding_state.dart';
import '../steps/welcome_step.dart';
import '../steps/premium_step.dart';
import '../steps/username_step.dart';
import '../steps/directories_step.dart';
import '../steps/complete_step.dart';
import '../widgets/onboarding_progress.dart';

class SetupView extends StatelessWidget {
  const SetupView({super.key});

  @override
  Widget build(BuildContext context) {
    final steps = const [
      WelcomeStep(),
      PremiumStep(),
      UsernameStep(),
      DirectoriesStep(),
      CompleteStep(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            const OnboardingProgress(totalSteps: 4),
            Expanded(
              child: BlocBuilder<OnboardingBloc, OnboardingState>(
                builder: (context, state) {
                  return PageView(
                    controller: PageController(keepPage: true),
                    physics: const NeverScrollableScrollPhysics(),
                    children: steps,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
