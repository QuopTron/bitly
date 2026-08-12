import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'frontend/shared/theme/app_theme.dart';
import 'router/app_router.dart';
import 'frontend/l10n/app_localizations.dart';
import 'frontend/features/splash/bloc/splash_bloc.dart';
import 'frontend/features/setup/bloc/setup_bloc.dart';
import 'backend/services/oauth_callback_service.dart';
import 'backend/services/verification_service.dart';
import 'injection.dart';

class BitlyApp extends StatefulWidget {
  const BitlyApp({super.key});

  @override
  State<BitlyApp> createState() => _BitlyAppState();
}

class _BitlyAppState extends State<BitlyApp> {
  late final ValueNotifier<Locale> _locale = sl<ValueNotifier<Locale>>();
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _locale.addListener(_onLocaleChanged);
    // Initialize the shared verification service with the root navigator key
    // so the Cloudflare WebView flow works from setup, search AND downloads.
    VerificationService().init(_navigatorKey);
    // NOTE: signed-session provisioning is intentionally NOT launched from here.
    // If it runs on the first frame the verification modal appears over the
    // splash, and go_router's splash→home navigation (same root Navigator)
    // disrupts/reconfigures that imperatively-pushed dialog — so the user can't
    // complete it, it times out, and taps keep returning VERIFY_REQUIRED. The
    // provisioning is instead triggered by the destination page (HomePage) once
    // it is actually mounted. See lib/frontend/features/home/home_page.dart.
    // Initialize the OAuth (PKCE) callback listener so the spotiflac://callback
    // deep link is delivered to the pending flow (e.g. future Spotify login).
    OAuthCallbackService().init();
  }

  void _onLocaleChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _locale.removeListener(_onLocaleChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);

    return MultiBlocProvider(
      providers: [
        BlocProvider<SplashBloc>(create: (_) => sl<SplashBloc>()),
        BlocProvider<SetupBloc>(create: (_) => sl<SetupBloc>()),
      ],
      child: MaterialApp.router(
        title: 'Bitly',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
        locale: _locale.value,
        supportedLocales: const [Locale('es'), Locale('en')],
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: AppRouter(navigatorKey: _navigatorKey).router,
      ),
    );
  }
}
