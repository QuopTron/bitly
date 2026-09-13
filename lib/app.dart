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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'app/inyeccion.dart' as di;
import './core/cache/almacenes/cache_ajustes.dart';
import './core/modelos/usuario/estilo_visual.dart';
import './core/modelos/usuario/preferencias_estilo.dart';
import 'core/modelos/resultado_enlace.dart';
import './core/plataforma/sistema/servicio_deep_link.dart';
import './core/servicios/oauth/servicio_callback_oauth.dart';
import './core/servicios/proveedores/servicio_enlaces.dart';
import './core/servicios/verificacion/servicio_verificacion.dart';
import './estado/cola/cubit_cola.dart';
import 'features/setup/bloc/setup_bloc.dart';
import 'features/splash/bloc/splash_bloc.dart';
import 'l10n/app_localizations.dart';
import 'router/app_router.dart';
import 'router/route_names.dart';
import 'shared/tema/envoltorio_color_dinamico.dart';
import './shared/widgets/base/overlay_compartido.dart';

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
  late final ValueNotifier<EstiloVisual> _estiloVisual =
      di.sl<ValueNotifier<EstiloVisual>>();
  late final ValueNotifier<PreferenciasEstilo> _preferenciasEstilo =
      di.sl<ValueNotifier<PreferenciasEstilo>>();
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final GoRouter _router =
      AppRouter(navigatorKey: _navigatorKey).router;

  DatosDeepLink? _linkCompartido;
  StreamSubscription<ResultadoEnlace>? _subEnlaces;

  @override
  void initState() {
    super.initState();
    _locale.addListener(_onAjusteCambiado);
    _themeMode.addListener(_onAjusteCambiado);
    _estiloVisual.addListener(_onAjusteCambiado);
    _preferenciasEstilo.addListener(_onAjusteCambiado);
    _cargarAjustesGuardados();
    ServicioVerificacion().init(_navigatorKey);
    ServicioCallbackOAuth().init();
    // Enlaces de música (compartidos a la app o resueltos por la UI): en
    // cuanto Go devuelve el ítem, se encola y se reproduce.
    _subEnlaces = ServicioEnlaces.instance.resultados.listen(_reproducirEnlace);
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
      final estiloGuardado = await cache.getEstiloVisual();
      if (estiloGuardado != null && mounted) {
        _estiloVisual.value = EstiloVisualExt.desdeClave(estiloGuardado);
      }
      final prefsGuardadas = await cache.getPreferenciasEstilo();
      if (mounted) {
        _preferenciasEstilo.value = prefsGuardadas;
      }
    } catch (_) {}
  }

  void _onAjusteCambiado() {
    setState(() {});
  }

  void _descartarCompartido() {
    setState(() => _linkCompartido = null);
  }

  /// Reproduce un enlace ya resuelto: encola sus tracks y, si el usuario no
  /// está en una pantalla de arranque, lo lleva al home para que vea el
  /// miniplayer con lo que suena.
  void _reproducirEnlace(ResultadoEnlace resuelto) {
    if (!mounted) return;
    setState(() => _linkCompartido = null);
    di.sl<CubitCola>().reproducirConContexto(
      resuelto.paraReproducir,
      resuelto.item,
    );
    final ruta = _router.routerDelegate.currentConfiguration.uri.path;
    if (ruta != RouteNames.setup.path && ruta != RouteNames.splash.path) {
      _router.go(RouteNames.home.path);
    }
  }

  /// Botón "Reproducir" del overlay de enlaces: resuelve el enlace contra Go
  /// y, si no se puede, deja al usuario en la búsqueda para encontrarlo.
  Future<void> _reproducirCompartido() async {
    final link = _linkCompartido;
    setState(() => _linkCompartido = null);
    if (link == null) return;
    if (link.url.isNotEmpty) {
      final resuelto = await ServicioEnlaces.instance.resolver(link.url);
      if (resuelto != null) {
        _reproducirEnlace(resuelto);
        return;
      }
    }
    _router.go(RouteNames.home.path);
  }

  @override
  void dispose() {
    _subEnlaces?.cancel();
    _locale.removeListener(_onAjusteCambiado);
    _themeMode.removeListener(_onAjusteCambiado);
    _estiloVisual.removeListener(_onAjusteCambiado);
    _preferenciasEstilo.removeListener(_onAjusteCambiado);
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