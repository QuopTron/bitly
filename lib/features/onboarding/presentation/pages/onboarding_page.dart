import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/onboarding_bloc.dart';
import '../bloc/onboarding_event.dart';
import '../bloc/onboarding_state.dart';
import '../views/splash_view.dart';
import '../views/tutorial_view.dart';
import '../views/setup_view.dart';

enum OnboardingPhase { splash, tutorial, setup, home }

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  OnboardingPhase _phase = OnboardingPhase.splash;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<OnboardingBloc, OnboardingState>(
      listener: (context, state) {
        if (state.showTutorial && _phase == OnboardingPhase.splash) {
          setState(() => _phase = OnboardingPhase.tutorial);
        } else if (!state.showTutorial && _phase == OnboardingPhase.tutorial) {
          setState(() => _phase = OnboardingPhase.setup);
        } else if (state.currentStep == 4 && _phase == OnboardingPhase.setup) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              setState(() => _phase = OnboardingPhase.home);
            }
          });
        }
      },
      builder: (context, state) {
        switch (_phase) {
          case OnboardingPhase.splash:
            return SplashView(
              onTutorial: () {
                context.read<OnboardingBloc>().add(NextStep());
              },
              onSetup: () {
                context.read<OnboardingBloc>().add(const GoToStep(0));
              },
              onHome: () {
                context.read<OnboardingBloc>().add(const StartApp());
              },
            );
          case OnboardingPhase.tutorial:
            return const TutorialView();
          case OnboardingPhase.setup:
            return const SetupView();
          case OnboardingPhase.home:
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pushReplacementNamed('/home');
            });
            return const SizedBox.shrink();
        }
      },
    );
  }
}
