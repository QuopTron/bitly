import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'frontend/shared/theme/app_theme.dart';
import 'router/app_router.dart';
import 'frontend/l10n/app_localizations.dart';
import 'frontend/features/splash/bloc/splash_bloc.dart';
import 'frontend/features/setup/bloc/setup_bloc.dart';
import 'injection.dart';

class BitlyApp extends StatefulWidget {
  const BitlyApp({super.key});

  @override
  State<BitlyApp> createState() => _BitlyAppState();
}

class _BitlyAppState extends State<BitlyApp> {
  late final ValueNotifier<Locale> _locale = sl<ValueNotifier<Locale>>();

  @override
  void initState() {
    super.initState();
    _locale.addListener(_onLocaleChanged);
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
        routerConfig: AppRouter().router,
      ),
    );
  }
}
