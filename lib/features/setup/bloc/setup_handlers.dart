import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/backend/backend_service.dart';
import '../../../core/utils/random_names.dart';
import 'setup_event.dart';
import 'setup_state.dart';

mixin SetupHandlers on Bloc<SetupEvent, SetupState> {
  BackendService get backend;
  ValueNotifier<Locale> get localeNotifier;

  void onSelectLanguage$(SelectLanguage event, Emitter<SetupState> emit) {
    localeNotifier.value = Locale(event.locale);
    emit(state.copyWith(selectedLocale: event.locale));
  }

  void onNextSlide$(NextSlide event, Emitter<SetupState> emit) {
    switch (state.step) {
      case SetupStep.language:
        emit(state.copyWith(step: SetupStep.username));
      case SetupStep.username:
        emit(state.copyWith(step: SetupStep.mode));
      case SetupStep.mode:
        emit(state.copyWith(step: SetupStep.feedTutorial));
      case SetupStep.feedTutorial:
        emit(state.copyWith(step: SetupStep.searchTutorial));
      case SetupStep.searchTutorial:
        emit(state.copyWith(step: SetupStep.profileTutorial));
      case SetupStep.profileTutorial:
        emit(state.copyWith(step: SetupStep.storageFolder));
      case SetupStep.storageFolder:
        emit(state.copyWith(step: SetupStep.notifications));
      default:
    }
  }

  void onPreviousSlide$(PreviousSlide event, Emitter<SetupState> emit) {
    switch (state.step) {
      case SetupStep.notifications:
        emit(state.copyWith(step: SetupStep.storageFolder));
      case SetupStep.storageFolder:
        emit(state.copyWith(step: SetupStep.profileTutorial));
      case SetupStep.profileTutorial:
        emit(state.copyWith(step: SetupStep.searchTutorial));
      case SetupStep.searchTutorial:
        emit(state.copyWith(step: SetupStep.feedTutorial));
      case SetupStep.feedTutorial:
        emit(state.copyWith(step: SetupStep.mode));
      case SetupStep.mode:
        emit(state.copyWith(step: SetupStep.username));
      case SetupStep.username:
        emit(state.copyWith(step: SetupStep.language));
      default:
    }
  }

  void onUsernameChanged$(UsernameChanged event, Emitter<SetupState> emit) {
    emit(state.copyWith(username: event.username));
  }

  void onGenerateRandomName$(GenerateRandomName event, Emitter<SetupState> emit) {
    final name = randomNames[DateTime.now().millisecondsSinceEpoch % randomNames.length];
    emit(state.copyWith(username: name));
  }

  void onSelectMode$(SelectMode event, Emitter<SetupState> emit) {
    emit(state.copyWith(
      selectedMode: event.mode,
      codeValid: false,
      codeError: null,
      premiumCode: '',
    ));
  }

  void onPremiumCodeChanged$(PremiumCodeChanged event, Emitter<SetupState> emit) {
    emit(state.copyWith(premiumCode: event.code, codeValid: false, codeError: null));
  }

  Future<void> onValidatePremiumCode$(ValidatePremiumCode event, Emitter<SetupState> emit) async {
    if (state.premiumCode.trim().isEmpty) return;
    emit(state.copyWith(codeValidating: true, codeValid: false, codeError: null));
    final error = await backend.validatePremiumCode(state.premiumCode.trim());
    if (error == null) {
      emit(state.copyWith(codeValidating: false, codeValid: true, codeError: null));
    } else {
      emit(state.copyWith(codeValidating: false, codeValid: false, codeError: error));
    }
  }

  Future<void> onCompleteSetup$(CompleteSetup event, Emitter<SetupState> emit) async {
    if (state.selectedMode == null || state.username.trim().isEmpty) return;
    if (state.selectedMode == 'premium' && !state.codeValid) return;
    emit(state.copyWith(saving: true, step: SetupStep.thankYou));
    final code = state.codeValid ? state.premiumCode.trim() : null;
    await backend.completeSetup(
      locale: state.selectedLocale,
      mode: state.selectedMode!,
      username: state.username.trim(),
      premiumCode: code,
    );
    if (code != null) await backend.activatePremium(code);
    emit(state.copyWith(saving: false));
  }

  Future<void> onCheckExistingData$(CheckExistingData event, Emitter<SetupState> emit) async {
    try {
      final data = await backend.loadSetupData();
      if (data != null && data.setupCompleted) {
        localeNotifier.value = Locale(data.locale);
        emit(state.copyWith(
          step: SetupStep.returningPrompt,
          hasExistingData: true,
          existingLocale: data.locale,
          existingMode: data.mode,
          existingUsername: data.username,
          existingTrialExpired: data.isTrialExpired,
        ));
      } else {
        emit(state.copyWith(step: SetupStep.language, hasExistingData: false));
      }
    } catch (_) {
      emit(state.copyWith(step: SetupStep.language, hasExistingData: false));
    }
  }

  void onAcceptExistingData$(AcceptExistingData event, Emitter<SetupState> emit) {
    if (event.accept) {
      if (state.existingLocale != null) localeNotifier.value = Locale(state.existingLocale!);
      emit(state.copyWith(continueWithExisting: true, step: SetupStep.thankYou));
    } else {
      emit(state.copyWith(
        continueWithExisting: false,
        selectedLocale: state.existingLocale ?? state.selectedLocale,
        username: state.existingUsername ?? '',
        step: SetupStep.language,
      ));
    }
  }
}
