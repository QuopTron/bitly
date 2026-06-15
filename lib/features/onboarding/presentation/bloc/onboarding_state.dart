import 'package:equatable/equatable.dart';

class OnboardingState extends Equatable {
  final int currentStep;
  final int tutorialPageIndex;
  final bool isPremiumValid;
  final String? error;
  final bool isCompleting;
  final bool showTutorial;

  const OnboardingState({
    this.currentStep = 0,
    this.tutorialPageIndex = 0,
    this.isPremiumValid = false,
    this.error,
    this.isCompleting = false,
    this.showTutorial = true,
  });

  OnboardingState copyWith({
    int? currentStep,
    int? tutorialPageIndex,
    bool? isPremiumValid,
    String? error,
    bool? isCompleting,
    bool? showTutorial,
  }) {
    return OnboardingState(
      currentStep: currentStep ?? this.currentStep,
      tutorialPageIndex: tutorialPageIndex ?? this.tutorialPageIndex,
      isPremiumValid: isPremiumValid ?? this.isPremiumValid,
      error: error,
      isCompleting: isCompleting ?? this.isCompleting,
      showTutorial: showTutorial ?? this.showTutorial,
    );
  }

  @override
  List<Object?> get props => [
    currentStep,
    tutorialPageIndex,
    isPremiumValid,
    error,
    isCompleting,
    showTutorial,
  ];
}
