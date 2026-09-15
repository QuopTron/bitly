// ─────────────────────────────────────────────────────────────
// settings_sheet_release_info.dart — Modelo con los datos de una release de GitHub (tag, notas, fecha y URL de
// descarga) que muestra el sheet de actualización.
//
// Se conecta con: settings_sheet_new.dart (misma library) + update_service.
// Parte del flujo: Ajustes → actualizaciones.
// ─────────────────────────────────────────────────────────────

part of 'settings_sheet_new.dart';

class _ReleaseInfo {
  final String tag;
  final String body;
  final String date;
  final String downloadUrl;
  const _ReleaseInfo({
    required this.tag,
    required this.body,
    required this.date,
    this.downloadUrl = '',
  });
}
