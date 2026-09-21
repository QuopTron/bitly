// ─────────────────────────────────────────────────────────────
// registro_proveedores_rescate.dart — Configuración del proveedor
// NATIVO de rescate de audio (flac-rescue), separada del registro
// principal para mantener cada archivo dentro del límite de líneas.
//
// Qué es: un proveedor sin catálogo propio que convierte un ISRC en
// la URL de audio (FLAC o MP3) consultando una lista de espejos
// públicos configurables. Es el "último recurso exacto" cuando la
// fuente original no puede entregar audio.
//
// Por qué los espejos son configurables: todos los servicios públicos
// gratuitos dependen de cuentas ajenas que se banean (DAB, squid.wtf).
// Teniéndolos en Ajustes, cuando uno cae el usuario pega otro y todo
// sigue funcionando SIN actualizar la app.
//
// Se conecta con: registro_proveedores.dart (spread en `proveedoresTodos`)
// → config_proveedor.dart → ServicioCredencialesProveedor →
// setExtensionSettings("flac-rescue").
// Parte del flujo: arranque de la app (credenciales → extensiones).
// ─────────────────────────────────────────────────────────────

import '../base/config_proveedor.dart';

/// Proveedores de rescate de audio (nativos, no extensiones JS).
const List<ConfigProveedor> proveedoresRescate = [
  ConfigProveedor(
    id: 'flac-rescue',
    nombreMostrado: 'Rescate de audio (FLAC/MP3)',
    claves: [
      'mirrors', // Espejos que convierten un ISRC en audio.
      'format', // FLAC / MP3_320 / MP3_128 (baja solo si no está).
      'origin', // Origen permitido que exigen algunos espejos.
      'qobuz_keys_url', // Origen de claves app_id/app_secret de Qobuz.
      'sitios', // Sitios raspables de FLAC (superflac, arcod, etc.).
      'arcod', // URL propia del canal sin pérdida (o 'off').
      'arcod_token', // Sesión de una instancia arcod con cuenta.
    ],
  ),
];
