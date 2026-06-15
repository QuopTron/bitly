import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/onboarding_repository.dart';
import 'onboarding_event.dart';
import 'onboarding_state.dart';

class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  final OnboardingRepository _repository;

  OnboardingBloc(this._repository) : super(const OnboardingState()) {
    on<NextStep>(_onNextStep);
    on<PreviousStep>(_onPreviousStep);
    on<GoToStep>(_onGoToStep);
    on<ValidatePremiumCode>(_onValidatePremiumCode);
    on<SaveUsername>(_onSaveUsername);
    on<CompleteSetup>(_onCompleteSetup);
    on<SkipTutorial>(_onSkipTutorial);
  }

  void _onNextStep(NextStep event, Emitter<OnboardingState> emit) {
    if (state.showTutorial) {
      if (state.tutorialPageIndex < 4) {
        emit(state.copyWith(tutorialPageIndex: state.tutorialPageIndex + 1));
      } else {
        emit(state.copyWith(showTutorial: false));
      }
    } else {
      if (state.currentStep < 4) {
        emit(state.copyWith(currentStep: state.currentStep + 1));
      }
    }
  }

  void _onPreviousStep(PreviousStep event, Emitter<OnboardingState> emit) {
    if (state.showTutorial) {
      if (state.tutorialPageIndex > 0) {
        emit(state.copyWith(tutorialPageIndex: state.tutorialPageIndex - 1));
      }
    } else {
      if (state.currentStep > 0) {
        emit(state.copyWith(currentStep: state.currentStep - 1));
      }
    }
  }

  void _onGoToStep(GoToStep event, Emitter<OnboardingState> emit) {
    emit(state.copyWith(currentStep: event.step, showTutorial: false));
  }

  Future<void> _onValidatePremiumCode(
    ValidatePremiumCode event,
    Emitter<OnboardingState> emit,
  ) async {
    emit(state.copyWith(isCompleting: true, error: null));
    try {
      final valid = await _repository.validatePremiumCode(event.code);
      if (valid) {
        await _repository.savePremiumCode(event.code);
        emit(state.copyWith(isPremiumValid: true, isCompleting: false));
      } else {
        emit(state.copyWith(
          error: 'Código premium inválido',
          isCompleting: false,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        error: 'Error al validar código',
        isCompleting: false,
      ));
    }
  }

  Future<void> _onSaveUsername(
    SaveUsername event,
    Emitter<OnboardingState> emit,
  ) async {
    await _repository.saveUsername(event.username);
  }

  Future<void> _onCompleteSetup(
    CompleteSetup event,
    Emitter<OnboardingState> emit,
  ) async {
    emit(state.copyWith(isCompleting: true));
    await _repository.completeSetup();
    emit(state.copyWith(isCompleting: false, currentStep: 4));
  }

  void _onSkipTutorial(SkipTutorial event, Emitter<OnboardingState> emit) {
    emit(state.copyWith(showTutorial: false));
  }
}
