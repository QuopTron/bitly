// ─────────────────────────────────────────────────────────────
// cache_feed.dart — Snapshot local del feed de inicio. Guarda las
// últimas secciones (más la fuente activa y timestamp) como JSON en
// la tabla de ajustes, para que la UI muestre contenido al instante
// al arrancar, incluso antes (o sin) una respuesta fresca del backend.
// Se conecta con: base_datos (SettingsDao) + feature Inicio.
// Parte del flujo: Inicio (feed del home).
// ─────────────────────────────────────────────────────────────

import 'dart:convert';

import '../base_datos/app_database.dart';
import '../base_datos/daos/settings_dao.dart';
import '../modelos/seccion_feed.dart';

/// Snapshot de un feed ya obtenido, restaurado al arrancar.
class DatosCacheFeed {
  final List<SeccionFeed> secciones;
  final String fuenteSeleccionada;
  final DateTime? ultimaObtencion;

  const DatosCacheFeed({
    required this.secciones,
    this.fuenteSeleccionada = '',
    this.ultimaObtencion,
  });

  bool get tieneContenido => secciones.any((s) => s.items.isNotEmpty);
}

/// Persistencia local del feed de inicio.
class CacheFeed {
  static const _claveSecciones = 'home_feed_sections';
  static const _claveFuente = 'home_feed_source';
  static const _claveTs = 'home_feed_ts';

  final SettingsDao _dao;
  CacheFeed(AppDatabase db) : _dao = SettingsDao(db);

  Future<DatosCacheFeed?> cargar() async {
    try {
      final raw = await _dao.get(_claveSecciones);
      if (raw == null || raw.isEmpty) return null;
      final lista = (jsonDecode(raw) as List)
          .map((e) => SeccionFeed.desdeJson(e as Map<String, dynamic>))
          .toList();
      final fuente = await _dao.get(_claveFuente) ?? '';
      final tsRaw = await _dao.get(_claveTs);
      final ts = tsRaw != null ? DateTime.tryParse(tsRaw) : null;
      final datos = DatosCacheFeed(secciones: lista, fuenteSeleccionada: fuente, ultimaObtencion: ts);
      return datos.tieneContenido ? datos : null;
    } catch (_) {
      await _limpiar();
      return null;
    }
  }

  Future<void> guardar(List<SeccionFeed> secciones, String fuenteSeleccionada) async {
    try {
      await _dao.set(
        _claveSecciones,
        jsonEncode(secciones.map((e) => e.aJson()).toList()),
      );
      await _dao.set(_claveFuente, fuenteSeleccionada);
      await _dao.set(_claveTs, DateTime.now().toIso8601String());
    } catch (_) {
      // Cachear es best-effort; nunca dejar que un fallo de escritura rompa el feed.
    }
  }

  Future<void> _limpiar() async {
    try {
      await _dao.remove(_claveSecciones);
      await _dao.remove(_claveFuente);
      await _dao.remove(_claveTs);
    } catch (_) {}
  }
}