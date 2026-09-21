// ─────────────────────────────────────────────────────────────
// registro_proveedores.dart — Registro estático de TODOS los
// proveedores cuyas credenciales guardadas se empujan a Go al
// arrancar, con la lista de claves de cada uno.
//
// Está partido en tres archivos para mantener cada uno dentro del
// límite de líneas; acá queda el índice:
//   - registro_proveedores_sesiones.dart → TIDAL y Qobuz (con pool)
//   - registro_proveedores_rescate.dart  → proveedores nativos (rescate)
//   - este archivo                       → el resto
//
// Cada `claves` se guarda en la caché como `<id>_<clave>` y se manda a
// la extensión en `setExtensionSettings` (ver ServicioCredencialesProveedor).
// Se conecta con: config_proveedor.dart (lista `todos`).
// Parte del flujo: arranque de la app (credenciales → extensiones).
// ─────────────────────────────────────────────────────────────

import 'config_proveedor.dart';
import 'registro_proveedores_rescate.dart';
import 'registro_proveedores_sesiones.dart';
part 'registro_proveedores_apps.dart';

/// Lista completa de proveedores con credenciales.
const List<ConfigProveedor> proveedoresTodos = [
  // Proveedores nativos (no extensiones JS), p. ej. el rescate de audio.
  ...proveedoresRescate,
  // Proveedores con pool de credenciales (TIDAL, Qobuz).
  ...proveedoresSesiones,
  // Proveedores de app (Amazon, SoundCloud, Spotify, Soulseek, Pandora).
  ...proveedoresApps,
  ConfigProveedor(
    id: 'apple-music',
    nombreMostrado: 'Apple',
    claves: ['mediaUserToken'],
  ),
  ConfigProveedor(
    id: 'ytmusic-spotiflac',
    nombreMostrado: 'YouTube',
    // Los tokens del flujo OAuth no tienen campo visible, pero deben
    // enviarse a la extensión al arrancar para que la sesión sobreviva.
    claves: [
      'poTokenProviderUrl',
      'manualGvsPoToken',
      'oauthClientId',
      'oauthClientSecret',
      'oauthAccessToken',
      'oauthRefreshToken',
    ],
  ),
  ConfigProveedor(
    id: 'deezer',
    nombreMostrado: 'Deezer',
    claves: ['arl', 'arlPoolUrls'],
  ),
];
