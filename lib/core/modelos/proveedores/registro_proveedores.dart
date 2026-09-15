// ─────────────────────────────────────────────────────────────
// registro_proveedores.dart — Registro estático de TODOS los
// proveedores que aceptan credenciales, con sus campos y acciones.
//
// Está partido en tres archivos para mantener cada uno dentro del
// límite de líneas; acá queda el índice:
//   - registro_proveedores_sesiones.dart → TIDAL y Qobuz (con pool)
//   - registro_proveedores_rescate.dart  → proveedores nativos (rescate)
//   - este archivo                       → el resto
//
// Se conecta con: config_proveedor.dart (lista `todos`).
// Parte del flujo: Ajustes → Credenciales → Proveedores.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import 'config_proveedor.dart';
import 'registro_proveedores_rescate.dart';
import 'registro_proveedores_sesiones.dart';
part 'registro_proveedores_apps.dart';

/// Lista completa de proveedores con campos de credencial y acciones.
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
    icon: Icons.apple,
    campos: [
      CampoProveedor(
        key: 'mediaUserToken',
        label: 'Media User Token',
        hint: 'Necesario para letras. Sácalo de la consola del navegador en music.apple.com…',
      ),
    ],
  ),
  ConfigProveedor(
    id: 'ytmusic-spotiflac',
    nombreMostrado: 'YouTube',
    icon: Icons.music_video,
    campos: [
      CampoProveedor(
        key: 'poTokenProviderUrl',
        label: 'Proveedor de PO Token (URL, opcional)',
        hint: 'Base URL de un proveedor bgutil (puerto 4416 por defecto). '
            'Con esto YouTube entrega audio solo-audio y deja de pedir '
            '"inicia sesión para confirmar que no sos un bot" SIN cuenta '
            'de Google. En emulador, el server de la PC se alcanza con '
            'http://10.0.2.2:4416.',
      ),
      CampoProveedor(
        key: 'manualGvsPoToken',
        label: 'Manual GVS PO Token',
        hint: 'Token crudo opcional para bypass de 403…',
      ),
      CampoProveedor(
        key: 'oauthClientId',
        label: 'OAuth Client ID (Google Cloud)',
        hint: 'Console → Credenciales → ID de cliente OAuth (apps.googleusercontent.com)',
      ),
      CampoProveedor(
        key: 'oauthClientSecret',
        label: 'OAuth Client Secret (opcional)',
        hint: 'Solo visible al crear el cliente OAuth',
      ),
    ],
    // Los tokens del flujo OAuth no tienen campo visible, pero deben
    // enviarse a la extensión al arrancar para que la sesión sobreviva.
    clavesAjusteExtra: ['oauthAccessToken', 'oauthRefreshToken'],
    acciones: [
      AccionProveedor(
        action: 'youtubeOauthConnect',
        label: 'Iniciar sesión con YouTube',
        icon: Icons.login,
      ),
      AccionProveedor(
        action: 'youtubeOauthLogout',
        label: 'Cerrar sesión de YouTube',
        icon: Icons.logout,
        mensajeConfirmacion: '¿Cerrar la sesión de YouTube? Se eliminarán los tokens '
            'de tu cuenta de este dispositivo.',
      ),
      AccionProveedor(
        action: 'clearCachedTokens',
        label: 'Limpiar caché de tokens (PO/visitor)',
        icon: Icons.cleaning_services_outlined,
        mensajeConfirmacion: '¿Limpiar la caché de tokens de YouTube? Se forzará a '
            're-resolver todo (PO token, visitor data, client) en la próxima '
            'búsqueda/reproducción. Útil si ves errores 403.',
      ),
    ],
  ),
  ConfigProveedor(
    id: 'deezer',
    nombreMostrado: 'Deezer',
    icon: Icons.headphones,
    campos: [
      CampoProveedor(
        key: 'arl',
        label: 'ARL (una por línea, opcional)',
        hint: 'Con tu ARL las descargas salen DIRECTO del CDN de Deezer y ya no se '
            'pide verificación de humano. Cuenta gratis: MP3 128 completo. '
            'Cuenta paga: MP3 320 y FLAC. Se obtiene en la web de Deezer: '
            'DevTools > Application > Cookies > arl.\n'
            'Podés pegar VARIAS (una por línea): si una se banea, se rota sola a '
            'la siguiente sin que vuelvas a pegar nada.',
        multiline: true,
      ),
      CampoProveedor(
        key: 'arlPoolUrls',
        label: 'Fuentes del pool (una URL por línea, opcional)',
        hint: 'URLs públicas que publiquen ARLs, para refrescar el pool sin '
            'actualizar la app. La app las descarga, se queda solo con las que '
            'siguen sirviendo y descarta las muertas. Tu ARL de arriba siempre '
            'tiene prioridad sobre estas.',
        multiline: true,
      ),
    ],
  ),
];
