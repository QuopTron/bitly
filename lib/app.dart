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
import 'app_helpers.dart';
import 'core/modelos/resultado_enlace.dart';
import './core/plataforma/sistema/servicio_deep_link.dart';
import './core/servicios/oauth/servicio_callback_oauth.dart';
import './core/servicios/proveedores/servicio_enlaces.dart';
import './core/servicios/verificacion/servicio_verificacion.dart';
import 'features/setup/bloc/setup_bloc.dart';
import 'features/splash/bloc/splash_bloc.dart';
import 'l10n/app_localizations.dart';
import 'app_contenido.dart';

import 'router/app_router.dart';
import 'shared/tema/envoltorio_color_dinamico.dart';

/// App raíz: tema dinámico + blocs globales + router + deep links.
class BitlyApp extends StatefulWidget {
  const BitlyApp({super.key});

  @override
  State<BitlyApp> createState() => _BitlyAppState();
}

class _BitlyAppState extends State<BitlyApp> {
  late final NotificadoresAjustesApp _ajustes = NotificadoresAjustesApp();
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final GoRouter _router =
      AppRouter(navigatorKey: _navigatorKey).router;

  DatosDeepLink? _linkCompartido;
  StreamSubscription<ResultadoEnlace>? _subEnlaces;

  @override
  void initState() {
    super.initState();
    _ajustes.suscribir(_onAjusteCambiado);
    cargarAjustesGuardadosApp(ajustes: _ajustes, estaMontado: () => mounted);
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

  void _onAjusteCambiado() {
    setState(() {});
  }

  void _descartarCompartido() {
    setState(() => _linkCompartido = null);
  }

  /// Reproduce un enlace ya resuelto delegando en el helper global.
  void _reproducirEnlace(ResultadoEnlace resuelto) {
    if (!mounted) return;
    reproducirEnlaceApp(
      resuelto: resuelto,
      router: _router,
      limpiarLink: _descartarCompartido,
    );
  }

  /// Botón "Reproducir" del overlay: resuelve el enlace y lo reproduce.
  Future<void> _reproducirCompartido() async {
    await reproducirCompartidoApp(
      link: _linkCompartido,
      router: _router,
      limpiarLink: _descartarCompartido,
      onResuelto: _reproducirEnlace,
    );
  }

  @override
  void dispose() {
    _subEnlaces?.cancel();
    _ajustes.liberar(_onAjusteCambiado);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EnvoltorioColorDinamico(
      themeModeOverride: _ajustes.themeMode.value,
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
            locale: _ajustes.locale.value,
            supportedLocales: const [Locale('es'), Locale('en')],
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            routerConfig: _router,
            builder: (context, hijo) => construirContenidoApp(
              context: context,
              hijo: hijo,
              linkCompartido: _linkCompartido,
              onDismiss: _descartarCompartido,
              onPlay: _reproducirCompartido,
            ),
          ),
        );
      },
    );
  }
}