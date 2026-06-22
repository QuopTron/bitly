import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/backend/backend_service.dart';
import 'setup_event.dart';
import 'setup_state.dart';

class SetupBloc extends Bloc<SetupEvent, SetupState> {
  final BackendService _backend;
  final ValueNotifier<Locale> _localeNotifier;

  SetupBloc(this._backend, this._localeNotifier) : super(const SetupState()) {
    on<SelectLanguage>(_onSelectLanguage);
    on<CompleteSetup>(_onCompleteSetup);
  }

  void _onSelectLanguage(SelectLanguage event, Emitter<SetupState> emit) {
    _localeNotifier.value = Locale(event.locale);
    emit(state.copyWith(selectedLocale: event.locale));
  }

  Future<void> _onCompleteSetup(
    CompleteSetup event,
    Emitter<SetupState> emit,
  ) async {
    emit(state.copyWith(saving: true));
    await _backend.saveLanguage(state.selectedLocale);
    emit(state.copyWith(saving: false));
  }
}
