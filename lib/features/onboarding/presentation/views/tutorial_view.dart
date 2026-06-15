import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/onboarding_bloc.dart';
import '../bloc/onboarding_event.dart';
import '../bloc/onboarding_state.dart';
import '../widgets/tutorial_card.dart';
import '../../domain/entities/tutorial_page.dart';

class TutorialView extends StatelessWidget {
  const TutorialView({super.key});

  @override
  Widget build(BuildContext context) {
    final pages = TutorialPage.defaultPages;
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: BlocBuilder<OnboardingBloc, OnboardingState>(
                builder: (context, state) {
                  return PageView.builder(
                    onPageChanged: (index) {
                      context.read<OnboardingBloc>().add(GoToStep(index));
                    },
                    itemCount: pages.length,
                    itemBuilder: (context, index) {
                      return TutorialCard(
                        icon: pages[index].icon,
                        title: pages[index].title,
                        description: pages[index].description,
                      );
                    },
                  );
                },
              ),
            ),
            _buildDots(context, pages.length),
            Padding(
              padding: const EdgeInsets.all(24),
              child: BlocBuilder<OnboardingBloc, OnboardingState>(
                builder: (context, state) {
                  final isLast = state.tutorialPageIndex == pages.length - 1;
                  return Column(
                    children: [
                      if (isLast)
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1DB954),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            onPressed: () {
                              context.read<OnboardingBloc>().add(NextStep());
                            },
                            child: const Text(
                              'Comenzar',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          context.read<OnboardingBloc>().add(SkipTutorial());
                        },
                        child: const Text(
                          'Saltar tutorial',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDots(BuildContext context, int count) {
    return BlocBuilder<OnboardingBloc, OnboardingState>(
      builder: (context, state) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(count, (index) {
            final isActive = index == state.tutorialPageIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF1DB954)
                    : Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        );
      },
    );
  }
}
