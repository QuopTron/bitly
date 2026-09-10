// ─────────────────────────────────────────────────────────────
// cache_ajustes.dart — Caché local de ajustes de la app (wrapper
// sobre SettingsDao): idioma, tema, ruta de descargas, ajustes de
// descarga, datos de setup, perfil de rendimiento y prioridad de
// proveedores de descarga.
// Se conecta con: base_datos (SettingsDao) + backend Go (sync).
// Parte del flujo: arranque, setup, Ajustes, descargas.
// ─────────────────────────────────────────────────────────────

import 'dart:convert';

import '../base_datos/app_database.dart';
import '../base_datos/daos/settings_dao.dart';
import '../backend_go/ayudantes_backend.dart';
import '../modelos/ajustes_descarga.dart';
import '../modelos/datos_setup.dart';
import '../modelos/perfil_rendimiento.dart';

/// Caché local de ajustes — wrappers sobre [SettingsDao].
class CacheAjustes {
  final SettingsDao _dao;
  CacheAjustes(AppDatabase db) : _dao = SettingsDao(db);

  Future<void> guardarIdioma(String locale) => _dao.set('locale', locale);
  Future<void> guardarTema(String mode) => _dao.set('theme_mode', mode);
  Future<void> guardarRutaDescargas(String path) => _dao.set('download_path', path);
  Future<String?> getRutaDescargas() => _dao.get('download_path');

  Future<AjustesDescarga> getAjustesDescarga() async {
    final todo = await _dao.getAll();
    final json = todo.map((k, v) => MapEntry(k, _parsearValor(v)));
    return AjustesDescarga.desdeJson(json);
  }

  Future<void> guardarAjustesDescarga(AjustesDescarga ajustes) async {
    for (final e in ajustes.aJson().entries) {
      await _dao.set(e.key, e.value.toString());
    }
  }

  Future<DatosSetup?> cargarDatosSetup() async {
    final todo = await _dao.getAll();
    if (todo.isEmpty) return null;
    final parseado = todo.map((k, v) => MapEntry(k, _parsearValor(v)));
    return AyudantesBackend.parsearDatosSetup(jsonEncode(parseado));
  }

  Future<void> completarSetup({
    required String locale,
    required String mode,
    required String username,
    String? codigoPremium,
    String? trialIniciadoEnExistente,
    String? trialExpiraEnExistente,
  }) async {
    final datos = AyudantesBackend.construirDatosSetup(
      locale: locale,
      mode: mode,
      username: username,
      codigoPremium: codigoPremium,
      trialIniciadoEnExistente: trialIniciadoEnExistente,
      trialExpiraEnExistente: trialExpiraEnExistente,
    );
    for (final e in datos.entries) {
      await _dao.set(e.key, e.value.toString());
    }
  }

  Future<String?> getAjuste(String key) => _dao.get(key);
  Future<void> guardarAjuste(String key, String value) => _dao.set(key, value);

  static const _clavePerf = 'perf_profile';

  Future<NivelRendimiento> getNivelRendimiento() async {
    final raw = await _dao.get(_clavePerf);
    return NivelRendimientoExt.desdeClave(raw);
  }

  Future<void> guardarNivelRendimiento(NivelRendimiento nivel) =>
      _dao.set(_clavePerf, nivel.clave);

  static const _clavePrioridadDescarga = 'download_provider_priority';

  /// Lista ordenada persistida de proveedores de descarga (mejor-primero).
  /// Lista vacía = se usa el orden por defecto del backend.
  Future<List<String>> getPrioridadProveedoresDescarga() async {
    final raw = await _dao.get(_clavePrioridadDescarga);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final lista = jsonDecode(raw);
      if (lista is List) return lista.whereType<String>().toList();
    } catch (_) {}
    return const [];
  }

  Future<void> guardarPrioridadProveedoresDescarga(List<String> orden) =>
      _dao.set(_clavePrioridadDescarga, jsonEncode(orden));

  static dynamic _parsearValor(String v) {
    if (v == 'true') return true;
    if (v == 'false') return false;
    final n = num.tryParse(v);
    if (n != null) return n;
    return v;
  }
}