// ─────────────────────────────────────────────────────────────
// app.dart — Raíz de la app (BitlyApp): envuelve el router con el
// tema dinámico (EnvoltorioColorDinamico), provee los blocs globales
// (splash + setup), configura l10n ES/EN y muestra el overlay
// "compartido contigo" cuando llega un deep link. También inicializa
// los servicios de verificación y callback OAuth.
// Se conecta con: inyeccion (sl) + app_router + l10n + tema +
// overlay_compartido + servicios (deep link, verificación, oauth).
// Parte del flujo: arranque (main → BitlyApp → router → splash).
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'app/inyeccion.dart' as di;
import 'core/cache/cache_ajustes.dart';
import 'core/plataforma/servicio_deep_link.dart';
import 'core/servicios/servicio_callback_oauth.dart';
import 'core/servicios/servicio_verificacion.dart';
import 'features/setup/bloc/setup_bloc.dart';
import 'features/splash/bloc/splash_bloc.dart';
import 'l10n/app_localizations.dart';
import 'router/app_router.dart';
import 'shared/tema/envoltorio_color_dinamico.dart';
import 'shared/widgets/overlay_compartido.dart';

/// App raíz: tema dinámico + blocs globales + router + deep links.
class BitlyApp extends StatefulWidget {
  const BitlyApp({super.key});

  @override
  State<BitlyApp> createState() => _BitlyAppState();
}

class _BitlyAppState extends State<BitlyApp> {
  late final ValueNotifier<Locale> _locale = di.sl<ValueNotifier<Locale>>();
  late final ValueNotifier<ThemeMode> _themeMode =
      di.sl<ValueNotifier<ThemeMode>>();
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final GoRouter _router =
      AppRouter(navigatorKey: _navigatorKey).router;

  DatosDeepLink? _linkCompartido;

  @override
  void initState() {
    super.initState();
    _locale.addListener(_onAjusteCambiado);
    _themeMode.addListener(_onAjusteCambiado);
    _cargarAjustesGuardados();
    ServicioVerificacion().init(_navigatorKey);
    ServicioCallbackOAuth().init();
    // Deep link inicial (app abierta vía link de WhatsApp, etc.).
    final inicial = ServicioDeepLink.instance.consumirPendiente();
    if (inicial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _linkCompartido = inicial);
      });
    }
    // Deep links que llegan con la app en primer plano.
    ServicioDeepLink.instance.onDeepLink.listen((link) {
      if (mounted) setState(() => _linkCompartido = link);
    });
  }

  Future<void> _cargarAjustesGuardados() async {
    try {
      final cache = di.sl<CacheAjustes>();
      final temaGuardado = await cache.getAjuste('theme_mode');
      if (temaGuardado != null && mounted) {
        _themeMode.value = temaGuardado == 'dark'
            ? ThemeMode.dark
            : ThemeMode.light;
      }
      final localeGuardado = await cache.getAjuste('locale');
      if (localeGuardado != null && mounted) {
        _locale.value = Locale(localeGuardado);
      }
    } catch (_) {}
  }

  void _onAjusteCambiado() {
    setState(() {});
  }

  void _descartarCompartido() {
    setState(() => _linkCompartido = null);
  }

  void _reproducirCompartido() {
    setState(() => _linkCompartido = null);
    // Navega a la home; el ítem queda buscable desde ahí.
  }

  @override
  void dispose() {
    _locale.removeListener(_onAjusteCambiado);
    _themeMode.removeListener(_onAjusteCambiado);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EnvoltorioColorDinamico(
      themeModeOverride: _themeMode.value,
      builder: (temaClaro, temaOscuro, modoTema) {
        return MultiBlocProvider(
          providers: [
            BlocProvider<SplashBloc>(create: (_) => di.sl<SplashBloc>()),
            BlocProvider<SetupBloc>(create: (_) => di.sl<SetupBloc>()),
          ],
          child: MaterialApp.router(
            title: 'Bitly',
            debugShowCheckedModeBanner: false,
            theme: temaClaro,
            darkTheme: temaOscuro,
            themeMode: modoTema,
            locale: _locale.value,
            supportedLocales: const [Locale('es'), Locale('en')],
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            routerConfig: _router,
            builder: (context, hijo) => Stack(
              textDirection: TextDirection.ltr,
              children: [
                if (hijo != null) hijo,
                if (_linkCompartido != null)
                  Positioned.fill(
                    child: OverlayCompartido(
                      type: _linkCompartido!.type,
                      id: _linkCompartido!.id,
                      query: _linkCompartido!.query,
                      onDismiss: _descartarCompartido,
                      onPlay: _reproducirCompartido,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}