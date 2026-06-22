class StringsSetup {
  final String selectLanguage;
  final String chooseLanguage;
  final String continueText;
  final String espanol;
  final String english;

  const StringsSetup({
    required this.selectLanguage,
    required this.chooseLanguage,
    required this.continueText,
    required this.espanol,
    required this.english,
  });

  static const es = StringsSetup(
    selectLanguage: 'Selecciona tu idioma',
    chooseLanguage: 'Elige el idioma de la aplicación',
    continueText: 'Continuar',
    espanol: 'Español',
    english: 'English',
  );

  static const en = StringsSetup(
    selectLanguage: 'Select your language',
    chooseLanguage: 'Choose the app language',
    continueText: 'Continue',
    espanol: 'Español',
    english: 'English',
  );
}
