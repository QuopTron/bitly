// ─────────────────────────────────────────────────────────────
// registro_proveedores_sesiones.dart — Proveedores cuya credencial se
// puede apilar en un POOL (TIDAL y Qobuz), separados del registro
// principal para mantener cada archivo dentro del límite de líneas.
//
// Por qué tienen pool: una credencial sola se muere (se revoca, se
// banea), y el usuario tenía que volver a pegarla. Con un pool:
//   - se pegan VARIAS (una por línea),
//   - opcionalmente se agregan URLs de fuentes que se descargan solas,
//   - el backend descarta las muertas y la extensión rota a la viva.
//
// Se conecta con: registro_proveedores.dart (spread en `proveedoresTodos`)
// → config_proveedor.dart → ServicioCredencialesProveedor →
// setExtensionSettings("tidal-web" / "qobuz-web").
// Parte del flujo: arranque de la app (credenciales → extensiones).
// ─────────────────────────────────────────────────────────────

import 'config_proveedor.dart';

/// Proveedores con pool de credenciales (tokens/cuentas apilables).
const List<ConfigProveedor> proveedoresSesiones = [
  ConfigProveedor(
    id: 'tidal-web',
    nombreMostrado: 'TIDAL',
    claves: ['tidalAccessToken', 'tidalPoolUrls', 'tidalCookie'],
  ),
  ConfigProveedor(
    id: 'qobuz-web',
    nombreMostrado: 'Qobuz',
    claves: ['email', 'password', 'qobuzPool', 'qobuzPoolUrls'],
  ),
];
