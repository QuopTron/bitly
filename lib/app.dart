import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/router/guards/auth_guard.dart';
import 'core/router/guards/setup_guard.dart';
import 'l10n/localization.dart';

class BitlyApp extends StatelessWidget {
  const BitlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isSetupCompleted(),
      builder: (context, snapshot) {
        final isSetupCompleted = snapshot.data ?? false;
        final router = AppRouter(
          authGuard: AuthGuard(isSetupCompleted: ValueNotifier(isSetupCompleted)),
          setupGuard: SetupGuard(isSetupCompleted: ValueNotifier(isSetupCompleted)),
        );
        return MaterialApp.router(
          title: 'Bitly',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          locale: const Locale('es'),
          supportedLocales: const [Locale('es'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: router.router,
        );
      },
    );
  }

  Future<bool> _isSetupCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('setup_completed') ?? false;
    } catch (_) {
      return false;
    }
  }
}
