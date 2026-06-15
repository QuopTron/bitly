import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/repositories/onboarding_repository.dart';

class SplashView extends StatefulWidget {
  final VoidCallback onTutorial;
  final VoidCallback onSetup;
  final VoidCallback onHome;

  const SplashView({
    super.key,
    required this.onTutorial,
    required this.onSetup,
    required this.onHome,
  });

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    final repo = OnboardingRepository();
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;
    final firstLaunch = await repo.isFirstLaunch();
    final tutShown = await repo.isTutorialShown();
    final completed = await repo.isSetupCompleted();
    if (!mounted) return;
    if (firstLaunch || !tutShown) {
      widget.onTutorial();
    } else if (!completed) {
      widget.onSetup();
    } else {
      widget.onHome();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1DB954)
                        .withValues(alpha: _glowAnimation.value * 0.5),
                    blurRadius: 60 * _glowAnimation.value,
                    spreadRadius: 10 * _glowAnimation.value,
                  ),
                ],
              ),
              child: const Icon(
                Icons.music_note,
                size: 80,
                color: Color(0xFF1DB954),
              ),
            );
          },
        ),
      ),
    );
  }
}
