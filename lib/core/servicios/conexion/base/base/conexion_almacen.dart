// ─────────────────────────────────────────────────────────────
// conexion_almacen.dart — Dónde vive la conexión: guarda y lee la lista de
// aparatos, la prueba de 9 horas y la identidad de ESTE aparato.
//
// Se guarda TODO como preferencias (clave/valor en JSON), así que no hace
// falta tocar el esquema de la base ni migrar nada.
//
// Acá también viven la creación del aparato propio y la reparación de la
// lista: si al guardado le falta el aparato que está mirando la pantalla (o
// se quedó sin dueño), se arregla al leer. Sin eso, la lista podría arrancar
// vacía o con un dueño fantasma.
//
// Se conecta con: servicio_conexion.dart (el estado) + cache_ajustes +
// dispositivo_conectado + tipo_aparato.
// Parte del flujo: Ajustes → Conexión (persistencia).
// ─────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../../cache/almacenes/sistema/cache_ajustes.dart';
import '../../../../modelos/usuario/dispositivos/dispositivo_conectado.dart';
import '../../../../modelos/usuario/dispositivos/trial_conexion.dart';
import 'tipo_aparato.dart';

/// Lee y escribe el estado de la conexión en los ajustes locales.
class AlmacenConexion {
  final CacheAjustes _cache;

  static const _claveDispositivos = 'conexion_dispositivos';
  static const _claveTrial = 'conexion_trial';
  static const _claveIdPropio = 'conexion_id_propio';

  AlmacenConexion(this._cache);

  /// Dispositivos guardados (lista vacía si no hay o si el JSON está roto).
  Future<List<DispositivoConectado>> leerDispositivos() async =>
      _parsearDispositivos(await _cache.getAjuste(_claveDispositivos));

  Future<void> guardarDispositivos(List<DispositivoConectado> lista) =>
      _cache.guardarAjuste(
        _claveDispositivos,
        jsonEncode([for (final d in lista) d.aJson()]),
      );

  /// La prueba de 9 horas (sin arrancar si no hay nada guardado).
  Future<TrialConexion> leerTrial() async =>
      _parsearTrial(await _cache.getAjuste(_claveTrial));

  Future<void> guardarTrial(TrialConexion trial) =>
      _cache.guardarAjuste(_claveTrial, jsonEncode(trial.aJson()));

  /// Id estable de este aparato: se genera una vez y se guarda.
  Future<String> asegurarIdPropio() async {
    final guardado = await _cache.getAjuste(_claveIdPropio);
    if (guardado != null && guardado.isNotEmpty) return guardado;
    final rnd = Random();
    final id =
        'dev_${DateTime.now().millisecondsSinceEpoch}_'
        '${rnd.nextInt(1 << 32).toRadixString(16)}';
    await _cache.guardarAjuste(_claveIdPropio, id);
    return id;
  }

  List<DispositivoConectado> _parsearDispositivos(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final parsed = jsonDecode(raw);
      if (parsed is! List) return const [];
      return [
        for (final e in parsed)
          if (e is Map<String, dynamic> &&
              (e['id'] as String? ?? '').isNotEmpty)
            DispositivoConectado.desdeJson(e),
      ];
    } catch (e) {
      debugPrint('[Conexion] dispositivos ilegibles: $e');
      return const [];
    }
  }

  TrialConexion _parsearTrial(String? raw) {
    if (raw == null || raw.isEmpty) return const TrialConexion();
    try {
      final parsed = jsonDecode(raw);
      if (parsed is Map<String, dynamic>) {
        return TrialConexion.desdeJson(parsed);
      }
    } catch (e) {
      debugPrint('[Conexion] prueba ilegible: $e');
    }
    return const TrialConexion();
  }
}

/// El aparato propio, recién creado. El nombre arranca vacío: lo pone el
/// usuario (o la UI con el tipo) para no inventar nombres ajenos.
DispositivoConectado conexionNuevoPropio(String id) => DispositivoConectado(
  id: id,
  nombre: '',
  tipo: tipoDeEsteAparato(),
  esDueno: true,
  vinculado: true,
  ultimaVezMs: DateTime.now().millisecondsSinceEpoch,
);

/// Si al guardado le falta [idPropio] (o se quedó sin dueño), lo arregla: la
/// lista siempre tiene que incluir a quien está mirando la pantalla, y
/// alguien tiene que mandar.
List<DispositivoConectado> conexionRepararPropio(
  List<DispositivoConectado> lista,
  String idPropio,
) {
  final hayPropio = lista.any((d) => d.id == idPropio);
  final hayDueno = lista.any((d) => d.esDueno);
  if (hayPropio && hayDueno) return lista;
  if (!hayPropio) {
    final propio = conexionNuevoPropio(idPropio);
    // Si ya hay dueño, el que se suma entra sin mandar.
    return [...lista, hayDueno ? propio.copiarCon(esDueno: false) : propio];
  }
  // Hay propio pero nadie manda: manda él.
  return [
    for (final d in lista)
      d.id == idPropio && !hayDueno ? d.copiarCon(esDueno: true) : d,
  ];
}
