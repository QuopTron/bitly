import 'package:equatable/equatable.dart';

abstract class SetupEvent extends Equatable {
  const SetupEvent();

  @override
  List<Object?> get props => [];
}

class SelectLanguage extends SetupEvent {
  final String locale;

  const SelectLanguage(this.locale);

  @override
  List<Object?> get props => [locale];
}

class CompleteSetup extends SetupEvent {
  const CompleteSetup();
}
