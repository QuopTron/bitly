// ─────────────────────────────────────────────────────────────
// hoja_fiesta.dart — Hoja del MODO FIESTA, la que se abre desde el icono de
// bola disco del reproductor.
//
// Tiene una sola idea en pantalla: armar el parlante grande acá, o sumarse al
// que ya armó otro aparato vinculado. Cuando la fiesta está andando muestra
// cuántos están sonando y si el tiempo está siguiendo bien al que manda.
//
// El acceso lo decide el plan (prueba de 9 horas o Premium), igual que el
// vínculo de aparatos: con el plan free el modo fiesta no entra.
//
// Parts: _aparatos (la lista de los que pueden sumarse y los que ya suenan).
// Se conecta con: servicio_fiesta + servicio_conexion + servicio_lan.
// Parte del flujo: reproductor → modo fiesta.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../app/inyeccion/inyeccion.dart';
import '../../../core/modelos/fiesta/fiesta_estado.dart';
import '../../../core/servicios/conexion/base/base/servicio_conexion.dart';
import '../../../core/servicios/fiesta/base/servicio_fiesta.dart';
import '../../../core/servicios/lan/modelos/lan_modelos.dart';
import '../../../core/servicios/lan/servicio/base/servicio_lan.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/tema/colores_app.dart';
import '../../../shared/utilidades/interaccion/haptico.dart';
import '../../../shared/utilidades/modales/mostrar_modal.dart';
import '../../../shared/utilidades/plataforma/responsive.dart';

part 'hoja_fiesta_panel.dart';
part 'hoja_fiesta_piezas.dart';
part 'hoja_fiesta_acciones.dart';
part 'hoja_fiesta_cuerpos.dart';

/// Abre la hoja del modo fiesta.
void mostrarHojaFiesta(BuildContext context) {
  mostrarHoja<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _HojaFiesta(),
  );
}

class _HojaFiesta extends StatefulWidget {
  const _HojaFiesta();

  @override
  State<_HojaFiesta> createState() => _HojaFiestaState();
}

class _HojaFiestaState extends State<_HojaFiesta> {
  ServicioFiesta? _fiesta;
  ServicioLan? _lan;
  ServicioConexion? _conexion;
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    try {
      _fiesta = sl<ServicioFiesta>();
      _lan = sl<ServicioLan>();
      _conexion = sl<ServicioConexion>();
    } catch (e) {
      debugPrint('[Fiesta] servicios no disponibles: $e');
    }
    _cargarPlan();
  }

  /// El plan se lee al abrir (pudo activarse Premium con la hoja ya abierta).
  Future<void> _cargarPlan() async {
    final conexion = _conexion;
    if (conexion == null) return;
    await conexion.refrescarPlan();
    if (!conexion.cargado) await conexion.cargar();
    if (mounted) setState(() {});
  }

  /// ¿El plan habilita el modo fiesta? (prueba de 9 h o Premium)
  bool get _habilitado {
    final conexion = _conexion;
    return conexion != null &&
        conexion.cargado &&
        (conexion.esPremium || conexion.trialSirve);
  }

  /// Corre [accion] mostrando que está en curso y, si falla, deja el aviso.
  Future<void> _correr(Future<void> Function() accion) async {
    if (_ocupado) return;
    Haptico.tap();
    setState(() => _ocupado = true);
    await accion();
    if (mounted) setState(() => _ocupado = false);
  }

  Future<void> _armar() => _correr(() async {
    final fiesta = _fiesta;
    if (fiesta == null) return;
    final armado = await fiesta.armar();
    if (!armado) fiesta.fallo.value = 'sinAudio';
  });

  Future<void> _unirse(ParLan host) => _correr(() => _fiesta!.unirse(host));

  @override
  Widget build(BuildContext context) => panelFiesta(
    fiesta: _fiesta,
    lan: _lan,
    habilitado: _habilitado,
    ocupado: _ocupado,
    onArmar: _armar,
    onUnirse: _unirse,
    onCortar: () => _correr(_fiesta!.cortar),
    onSalir: () => _correr(_fiesta!.salir),
  );
}
