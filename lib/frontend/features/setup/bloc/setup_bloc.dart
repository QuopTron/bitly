import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'setup_event.dart';
import 'setup_state.dart';
import 'setup_handlers.dart';

class SetupBloc extends Bloc<SetupEvent, SetupState> with SetupHandlers {
  final ValueNotifier<Locale> _localeNotifier;

  SetupBloc(this._localeNotifier) : super(const SetupState()) {
    on<SelectLanguage>(onSelectLanguage$);
    on<NextSlide>(onNextSlide$);
    on<PreviousSlide>(onPreviousSlide$);
    on<UsernameChanged>(onUsernameChanged$);
    on<GenerateRandomName>(onGenerateRandomName$);
    on<SelectMode>(onSelectMode$);
    on<GoogleSignInStatusChanged>(onGoogleSignInStatusChanged$);
    on<PremiumCodeChanged>(onPremiumCodeChanged$);
    on<ValidatePremiumCode>(onValidatePremiumCode$);
    on<CompleteSetup>(onCompleteSetup$);
    on<CheckExistingData>(onCheckExistingData$);
    on<AcceptExistingData>(onAcceptExistingData$);
    on<VerificationCompleted>(onVerificationCompleted$);
  }

  @override
  ValueNotifier<Locale> get localeNotifier => _localeNotifier;
}


