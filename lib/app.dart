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
import 'estado/cola/cubit_cola.dart';
import 'features/setup/bloc/setup_bloc.dart';
import 'features/splash/bloc/splash_bloc.dart';
import 'l10n/app_localizations.dart';
import 'app_contenido.dart';

import 'router/app_router.dart';
import 'router/route_names.dart';
import 'shared/tema/envoltorio_color_dinamico.dart';

part 'app_compartido.dart';
part 'app_vista.dart';

/// App raíz: tema dinámico + blocs globales + router + deep links.
class BitlyApp extends StatefulWidget {
  const BitlyApp({super.key});

  @override
  State<BitlyApp> createState() => _BitlyAppState();
}

class _BitlyAppState extends State<BitlyApp> with ManejadoresCompartidos {
  late final NotificadoresAjustesApp _ajustes = NotificadoresAjustesApp();
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final GoRouter _router =
      AppRouter(navigatorKey: _navigatorKey).router;

  DatosDeepLink? _linkCompartido;
  StreamSubscription<ResultadoEnlace>? _subEnlaces;
  StreamSubscription<DatosDeepLink>? _subDeepLinks;

  /// true recién cuando la app pasó el splash (y el setup si era la primera
  /// vez). La carta compartida espera a esto: primero carga todo, después se
  /// muestra, porque sus botones necesitan el backend andando.
  bool _appLista = false;

  @override
  void initState() {
    super.initState();
    _ajustes.suscribir(_onAjusteCambiado);
    cargarAjustesGuardadosApp(ajustes: _ajustes, estaMontado: () => mounted);
    ServicioVerificacion().init(_navigatorKey);
    ServicioCallbackOAuth().init();
    // El enlace compartido queda GUARDADO hasta que la app esté lista: en el
    // splash no se muestra nada, y apenas se entra al contenido aparece la
    // carta (nunca se pierde el enlace por llegar temprano).
    _appLista = _pasoElArranque();
    _router.routerDelegate.addListener(_onRutaCambiada);
    // Enlaces de música (compartidos a la app o resueltos por la UI): en
    // cuanto Go devuelve el ítem, se encola y se reproduce.
    _subEnlaces =
        ServicioEnlaces.instance.resultados.listen(reproducirResueltoCompartido);
    // Deep link inicial (app abierta vía link de WhatsApp, etc.).
    final inicial = ServicioDeepLink.instance.consumirPendiente();
    if (inicial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _linkCompartido = inicial);
      });
    }
    // Deep links que llegan con la app en primer plano. La suscripción se
    // guarda para poder cerrarla: sin cancelar, cada reconstrucción de la raíz
    // dejaba un listener vivo apuntando a un estado muerto (y ese setState
    // sobre un State desmontado es lo que dejaba la app sin responder hasta
    // reiniciarla).
    _subDeepLinks = ServicioDeepLink.instance.onDeepLink.listen((link) {
      if (!mounted) return;
      // El MISMO enlace puede llegar dos veces (re-entrega del intent inicial
      // al reanudar, o "compartir a Bitly" + deep link del mismo texto).
      // Apilar una segunda carta reanimaba el overlay encima de lo que el
      // usuario estaba haciendo; con la firma se ignora el duplicado.
      if (_firmaLink(link) == _firmaLink(_linkCompartido)) return;
      setState(() => _linkCompartido = link);
    });
  }

  /// Identidad de un enlace compartido: sirve para descartar la re-entrega
  /// del mismo intent sin comparar por referencia.
  String _firmaLink(DatosDeepLink? link) {
    if (link == null) return '';
    final c = link.compartido;
    return [c?.tipo ?? link.type, c?.isrc ?? link.id, c?.nombre ?? link.query]
        .join('|');
  }

  void _onAjusteCambiado() {
    setState(() {});
  }

  /// ¿La app ya salió del splash (y del setup)?
  bool _pasoElArranque() => pasoElArranque(_rutaActual());

  /// Ruta actual del router ('' mientras todavía no hay ninguna).
  String _rutaActual() {
    try {
      return _router.routerDelegate.currentConfiguration.uri.path;
    } catch (_) {
      return '';
    }
  }

  /// Al cambiar de ruta revisa si ya terminó el arranque; es lo que hace
  /// aparecer la carta compartida justo después del splash.
  void _onRutaCambiada() {
    if (!mounted) return;
    final lista = _pasoElArranque();
    if (lista == _appLista) return;
    setState(() => _appLista = lista);
    // Arranque terminado: si un "Compartir a Bitly" llegó en frío antes de que
    // el motor estuviera listo, se resuelve y suena ahora (antes se perdía).
    if (lista) ServicioEnlaces.instance.reintentarPendientes();
  }

  void _descartarCompartido() {
    setState(() => _linkCompartido = null);
  }

  @override
  GoRouter get routerCompartido => _router;

  @override
  DatosDeepLink? get linkCompartidoPendiente => _linkCompartido;

  @override
  void limpiarCompartido() => _descartarCompartido();

  @override
  void dispose() {
    _router.routerDelegate.removeListener(_onRutaCambiada);
    _subEnlaces?.cancel();
    _subDeepLinks?.cancel();
    _ajustes.liberar(_onAjusteCambiado);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _construirRaizApp(this);
}