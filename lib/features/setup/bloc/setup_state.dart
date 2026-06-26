import 'package:equatable/equatable.dart';

enum SetupStep {
  checkingExisting,
  returningPrompt,
  language,
  username,
  mode,
  feedTutorial,
  searchTutorial,
  profileTutorial,
  storageFolder,
  notifications,
  thankYou,
}

class SetupState extends Equatable {
  final SetupStep step;
  final String selectedLocale;
  final String username;
  final String? selectedMode;
  final String premiumCode;
  final bool saving;
  final bool codeValidating;
  final bool codeValid;
  final String? codeError;
  final bool? hasExistingData;
  final bool? continueWithExisting;
  final String? existingMode;
  final String? existingLocale;
  final String? existingUsername;
  final bool existingTrialExpired;

  const SetupState({
    this.step = SetupStep.checkingExisting,
    this.selectedLocale = 'es',
    this.username = '',
    this.selectedMode,
    this.premiumCode = '',
    this.saving = false,
    this.codeValidating = false,
    this.codeValid = false,
    this.codeError,
    this.hasExistingData,
    this.continueWithExisting,
    this.existingMode,
    this.existingLocale,
    this.existingUsername,
    this.existingTrialExpired = false,
  });

  SetupState copyWith({
    SetupStep? step,
    String? selectedLocale,
    String? username,
    String? selectedMode,
    String? premiumCode,
    bool? saving,
    bool? codeValidating,
    bool? codeValid,
    String? codeError,
    bool? hasExistingData,
    bool? continueWithExisting,
    String? existingMode,
    String? existingLocale,
    String? existingUsername,
    bool? existingTrialExpired,
  }) =>
      SetupState(
        step: step ?? this.step,
        selectedLocale: selectedLocale ?? this.selectedLocale,
        username: username ?? this.username,
        selectedMode: selectedMode ?? this.selectedMode,
        premiumCode: premiumCode ?? this.premiumCode,
        saving: saving ?? this.saving,
        codeValidating: codeValidating ?? this.codeValidating,
        codeValid: codeValid ?? this.codeValid,
        codeError: codeError,
        hasExistingData: hasExistingData ?? this.hasExistingData,
        continueWithExisting: continueWithExisting ?? this.continueWithExisting,
        existingMode: existingMode ?? this.existingMode,
        existingLocale: existingLocale ?? this.existingLocale,
        existingUsername: existingUsername ?? this.existingUsername,
        existingTrialExpired:
            existingTrialExpired ?? this.existingTrialExpired,
      );

  @override
  List<Object?> get props => [
        step,
        selectedLocale,
        username,
        selectedMode,
        premiumCode,
        saving,
        codeValidating,
        codeValid,
        codeError,
        hasExistingData,
        continueWithExisting,
        existingMode,
        existingLocale,
        existingUsername,
        existingTrialExpired,
      ];
}
