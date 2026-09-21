// ─────────────────────────────────────────────────────────────
// servicio_conexion.dart — El estado de la burbuja Conexión: qué
// dispositivos tiene la cuenta, cuál manda, y la prueba de 9 horas.
//
// Este archivo tiene el ESTADO y lo que lo cambia (cargar, agregar, sacar,
// renombrar, arrancar y consumir la prueba). Lo partido en otros archivos:
//   · conexion_almacen   → leer y escribir en los ajustes locales
//   · servicio_conexion_consultas → los getters (cupo, dueño, este aparato)
//   · servicio_conexion_reglas    → quién puede meter y sacar, y por qué
//
// Qué NO hace todavía: hablar con el otro aparato. El emparejamiento real
// (descubrimiento en la LAN + saludo) es el paso siguiente.
//
// Se conecta con: conexion_almacen + la burbuja Conexión de Ajustes.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';

import '../../../../cache/almacenes/sistema/cache_ajustes.dart';
import '../../../../modelos/usuario/dispositivos/dispositivo_conectado.dart';
import '../../../../modelos/usuario/dispositivos/trial_conexion.dart';
import 'conexion_almacen.dart';
import '../../novedades/conexion_novedades.dart';
import '../../novedades/conexion_novedades_almacen.dart';

part '../reglas/servicio_conexion_consultas.dart';
part '../reglas/servicio_conexion_vinculos.dart';

/// Cuántos aparatos admite cada plan. El free tiene 1 (el suyo) y puede
/// probar el cupo completo durante la prueba de 9 horas.
const int cupoPremium = 4;
const int cupoFree = 1;

class ServicioConexion {
  final CacheAjustes _cache;
  final AlmacenConexion _almacen;

  /// De dónde sale si el usuario es premium (inyectado para poder testear).
  final Future<bool> Function() _esPremium;

  List<DispositivoConectado> _dispositivos = const [];
  TrialConexion _trial = const TrialConexion();

  /// Ids de las novedades que el usuario ya vio (apaga el mininumerito).
  Set<String> _vistas = <String>{};

  bool _premium = false;
  String _idPropio = '';
  bool _cargado = false;

  ServicioConexion(
    CacheAjustes cache, {
    required Future<bool> Function() esPremium,
  }) : _cache = cache,
       _almacen = AlmacenConexion(cache),
       _esPremium = esPremium;

  /// Carga (o crea) todo: identidad, dispositivos y prueba.
  Future<void> cargar() async {
    try {
      _premium = await _esPremium();
      _trial = await _almacen.leerTrial();
      _idPropio = await _almacen.asegurarIdPropio();
      _vistas = await leerNovedadesVistas(_cache);
      final lista = await _almacen.leerDispositivos();
      // Primera vez: este aparato se registra solo como dueño. Así la
      // burbuja nunca arranca vacía ni con un dueño fantasma.
      _dispositivos =
          lista.isEmpty
              ? [conexionNuevoPropio(_idPropio)]
              : conexionRepararPropio(lista, _idPropio);
      if (lista.isEmpty) await _almacen.guardarDispositivos(_dispositivos);
    } catch (e) {
      debugPrint('[Conexion] no se pudo cargar: $e');
    }
    _cargado = true;
  }

  /// Vuelve a leer si el plan cambió (se llama al abrir Ajustes).
  Future<void> refrescarPlan() async {
    try {
      _premium = await _esPremium();
    } catch (e) {
      debugPrint('[Conexion] no se pudo leer el plan: $e');
    }
  }

  /// Arranca la prueba de 9 horas. El tiempo corre solo desde acá, así que
  /// el "ahora" se fija en el momento de activarla.
  Future<void> iniciarTrial() async {
    _trial = _trial.iniciar(DateTime.now().millisecondsSinceEpoch);
    await _almacen.guardarTrial(_trial);
  }

  /// Marca que el aparato [id] está en línea ahora mismo (lo va a llamar
  /// el emparejamiento cuando exista; hoy solo lo usa el dueño).
  Future<void> marcarVisto(String id, int ahoraMs) async {
    _dispositivos = [
      for (final d in _dispositivos)
        d.id == id ? d.copiarCon(vinculado: true, ultimaVezMs: ahoraMs) : d,
    ];
    await _almacen.guardarDispositivos(_dispositivos);
  }

  /// Declara un aparato nuevo (queda SIN vincular hasta que se empareje).
  Future<void> agregar({
    required String nombre,
    required TipoDispositivo tipo,
    required String id,
  }) async {
    _dispositivos = [
      ..._dispositivos,
      DispositivoConectado(
        id: id,
        nombre: nombre.trim(),
        tipo: tipo,
        vinculado: false,
      ),
    ];
    await _almacen.guardarDispositivos(_dispositivos);
  }

  /// Saca un aparato de la lista.
  Future<void> quitar(String id) async {
    _dispositivos = [
      for (final d in _dispositivos)
        if (d.id != id) d,
    ];
    await _almacen.guardarDispositivos(_dispositivos);
  }

  /// Marca las novedades actuales como vistas. Lo llama la pestaña al
  /// abrirse: son avisos, no reclamos, así que no pueden quedar encendidos
  /// para siempre por algo que hoy no se puede resolver.
  Future<void> marcarNovedadesVistas() async {
    final actuales = {for (final n in novedades) n.id};
    if (actuales.isEmpty) return;
    _vistas = {..._vistas, ...actuales};
    await guardarNovedadesVistas(_cache, _vistas);
  }

  /// Renombra un aparato.
  Future<void> renombrar(String id, String nombre) async {
    _dispositivos = [
      for (final d in _dispositivos)
        d.id == id ? d.copiarCon(nombre: nombre.trim()) : d,
    ];
    await _almacen.guardarDispositivos(_dispositivos);
  }
}
