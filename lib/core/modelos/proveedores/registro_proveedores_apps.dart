// ─────────────────────────────────────────────────────────────
// registro_proveedores_apps.dart — PART de registro_proveedores.dart:
// proveedores "de app" — Amazon, SoundCloud, Spotify (cookies),
// Soulseek (nombre + contraseña generada) y Pandora.
// Se conecta con: registro_proveedores.dart (spread en `proveedoresTodos`).
// Parte del flujo: arranque de la app (credenciales → extensiones).
// ─────────────────────────────────────────────────────────────

part of 'registro_proveedores.dart';

/// Proveedores de app con credenciales simples.
const List<ConfigProveedor> proveedoresApps = [
  ConfigProveedor(id: 'amazon', nombreMostrado: 'Amazon', claves: []),
  ConfigProveedor(id: 'soundcloud', nombreMostrado: 'SoundCloud', claves: []),
  ConfigProveedor(
    id: 'spotify-web',
    nombreMostrado: 'Spotify',
    claves: ['sp_dc', 'sp_key'],
  ),
  ConfigProveedor(
    id: 'soulseek',
    nombreMostrado: 'Soulseek',
    // La contraseña la genera la app y NO tiene campo visible, pero tiene
    // que sobrevivir a los reinicios: por eso viaja igual (clave `password`).
    claves: ['usuario', 'password'],
  ),
  ConfigProveedor(id: 'pandora', nombreMostrado: 'Pandora', claves: []),
  ConfigProveedor(
    id: 'youtube',
    nombreMostrado: 'YouTube',
    // La instancia propia de cobalt es el respaldo de descarga cuando yt-dlp
    // falla (ver cobalt.go en el backend). Sin URL queda apagado y no abre
    // ninguna conexión; la clave es opcional y solo la piden algunas
    // instancias.
    claves: ['cobalt', 'cobalt_token'],
  ),
];
