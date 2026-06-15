import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class AppLocalizations {
  final Locale locale;
  final Map<String, String> _strings = {};
  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  Future<void> load() async {
    final path = '${locale.languageCode}_${locale.countryCode ?? locale.languageCode}';
    final file = File('l10n/arb/app_$path.arb');
    if (await file.exists()) {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      json.forEach((key, value) {
        if (!key.startsWith('@')) _strings[key] = value.toString();
      });
    }
  }

  String translate(String key, {String? locale}) => _strings[key] ?? key;

  String get appName => translate('appName');
  String get appTitle => translate('appTitle');
  String get buttonAccept => translate('buttonAccept');
  String get buttonCancel => translate('buttonCancel');
  String get buttonSave => translate('buttonSave');
  String get buttonDelete => translate('buttonDelete');
  String get buttonConfirm => translate('buttonConfirm');
  String get buttonContinue => translate('buttonContinue');
  String get buttonBack => translate('buttonBack');
  String get buttonNext => translate('buttonNext');
  String get buttonSkip => translate('buttonSkip');
  String get buttonStart => translate('buttonStart');
  String get buttonRetry => translate('buttonRetry');
  String get buttonClose => translate('buttonClose');
  String get onboardingWelcomeTitle => translate('onboardingWelcomeTitle');
  String get onboardingWelcomeDesc => translate('onboardingWelcomeDesc');
  String get onboardingTutorial1Title => translate('onboardingTutorial1Title');
  String get onboardingTutorial1Desc => translate('onboardingTutorial1Desc');
  String get onboardingTutorial2Title => translate('onboardingTutorial2Title');
  String get onboardingTutorial2Desc => translate('onboardingTutorial2Desc');
  String get onboardingTutorial3Title => translate('onboardingTutorial3Title');
  String get onboardingTutorial3Desc => translate('onboardingTutorial3Desc');
  String get onboardingPremiumTitle => translate('onboardingPremiumTitle');
  String get onboardingPremiumHint => translate('onboardingPremiumHint');
  String get onboardingPremiumDesc => translate('onboardingPremiumDesc');
  String get onboardingUsernameTitle => translate('onboardingUsernameTitle');
  String get onboardingUsernameHint => translate('onboardingUsernameHint');
  String get onboardingUsernameDesc => translate('onboardingUsernameDesc');
  String get onboardingDirectoriesTitle => translate('onboardingDirectoriesTitle');
  String get onboardingDirectoriesDesc => translate('onboardingDirectoriesDesc');
  String get onboardingComplete => translate('onboardingComplete');
  String get onboardingCompleteDesc => translate('onboardingCompleteDesc');
  String get searchTitle => translate('searchTitle');
  String get searchHint => translate('searchHint');
  String get searchByUrl => translate('searchByUrl');
  String get searchFilters => translate('searchFilters');
  String get searchResults => translate('searchResults');
  String get searchNoResults => translate('searchNoResults');
  String get searchRecent => translate('searchRecent');
  String get downloadTitle => translate('downloadTitle');
  String get downloadQueue => translate('downloadQueue');
  String get downloadHistory => translate('downloadHistory');
  String get downloadStart => translate('downloadStart');
  String get downloadCancel => translate('downloadCancel');
  String get downloadPause => translate('downloadPause');
  String get downloadResume => translate('downloadResume');
  String get downloadRetry => translate('downloadRetry');
  String get downloadComplete => translate('downloadComplete');
  String get downloadFailed => translate('downloadFailed');
  String get downloadPending => translate('downloadPending');
  String get downloadInProgress => translate('downloadInProgress');
  String get downloadQuality => translate('downloadQuality');
  String get downloadClearAll => translate('downloadClearAll');
  String get libraryTitle => translate('libraryTitle');
  String get libraryTracks => translate('libraryTracks');
  String get libraryAlbums => translate('libraryAlbums');
  String get libraryArtists => translate('libraryArtists');
  String get libraryEmpty => translate('libraryEmpty');
  String get libraryScan => translate('libraryScan');
  String get libraryScanning => translate('libraryScanning');
  String get libraryDelete => translate('libraryDelete');
  String get playerNowPlaying => translate('playerNowPlaying');
  String get playerPause => translate('playerPause');
  String get playerPlay => translate('playerPlay');
  String get playerNext => translate('playerNext');
  String get playerPrevious => translate('playerPrevious');
  String get playerShuffle => translate('playerShuffle');
  String get playerRepeat => translate('playerRepeat');
  String get playerQueue => translate('playerQueue');
  String get playerLyrics => translate('playerLyrics');
  String get playerSleepTimer => translate('playerSleepTimer');
  String get playerNoTrack => translate('playerNoTrack');
  String get settingsTitle => translate('settingsTitle');
  String get settingsGeneral => translate('settingsGeneral');
  String get settingsDownloads => translate('settingsDownloads');
  String get settingsAppearance => translate('settingsAppearance');
  String get settingsLyrics => translate('settingsLyrics');
  String get settingsScrobbling => translate('settingsScrobbling');
  String get settingsAdvanced => translate('settingsAdvanced');
  String get settingsLanguage => translate('settingsLanguage');
  String get settingsDownloadDir => translate('settingsDownloadDir');
  String get settingsThemeMode => translate('settingsThemeMode');
  String get settingsVersion => translate('settingsVersion');
  String get settingsAbout => translate('settingsAbout');
  String get settingsReset => translate('settingsReset');
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();
  @override
  bool isSupported(Locale locale) => ['en', 'es'].contains(locale.languageCode);
  @override
  Future<AppLocalizations> load(Locale locale) async {
    final localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }
  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
