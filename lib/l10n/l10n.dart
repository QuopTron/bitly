import 'package:flutter/material.dart';
import 'package:bitly/l10n/app_localizations.dart';

export 'package:bitly/l10n/app_localizations.dart';

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
