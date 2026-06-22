import 'package:equatable/equatable.dart';

class SetupState extends Equatable {
  final String selectedLocale;
  final bool saving;

  const SetupState({
    this.selectedLocale = 'es',
    this.saving = false,
  });

  SetupState copyWith({String? selectedLocale, bool? saving}) =>
      SetupState(
        selectedLocale: selectedLocale ?? this.selectedLocale,
        saving: saving ?? this.saving,
      );

  @override
  List<Object?> get props => [selectedLocale, saving];
}
