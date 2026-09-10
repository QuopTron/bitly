// ─────────────────────────────────────────────────────────────
// registro_proveedores.dart — Registro estático de TODOS los
// proveedores que aceptan credenciales, con sus campos y acciones.
// Separado de config_proveedor.dart para mantener cada archivo
// dentro del límite de líneas.
// Se conecta con: config_proveedor.dart (lista `todos`).
// Parte del flujo: Ajustes → Credenciales → Proveedores.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import 'config_proveedor.dart';

/// Lista completa de proveedores con campos de credencial y acciones.
const List<ConfigProveedor> proveedoresTodos = [
  ConfigProveedor(
    id: 'tidal-web',
    nombreMostrado: 'TIDAL',
    icon: Icons.water_drop,
    campos: [
      CampoProveedor(
        key: 'tidalAccessToken',
        label: 'Access Token',
        hint: 'Pega el access token de Tidal...',
      ),
      CampoProveedor(
        key: 'tidalCookie',
        label: 'Session Cookie',
        hint: 'Pega la cookie de sesión completa de Tidal...',
        multiline: true,
      ),
    ],
  ),
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
    id: 'qobuz-web',
    nombreMostrado: 'Qobuz',
    icon: Icons.album,
    campos: [
      CampoProveedor(
        key: 'email',
        label: 'Correo electrónico',
        hint: 'tu@email.com',
      ),
      CampoProveedor(
        key: 'password',
        label: 'Contraseña',
        hint: 'Contraseña de tu cuenta Qobuz',
      ),
    ],
  ),
  ConfigProveedor(
    id: 'deezer',
    nombreMostrado: 'Deezer',
    icon: Icons.headphones,
    campos: [],
  ),
  ConfigProveedor(
    id: 'amazon',
    nombreMostrado: 'Amazon',
    icon: Icons.shopping_cart,
    campos: [],
  ),
  ConfigProveedor(
    id: 'soundcloud',
    nombreMostrado: 'SoundCloud',
    icon: Icons.cloud,
    campos: [],
  ),
  ConfigProveedor(
    id: 'spotify-web',
    nombreMostrado: 'Spotify',
    icon: Icons.music_note,
    campos: [
      CampoProveedor(
        key: 'sp_dc',
        label: 'Cookie sp_dc',
        hint: 'Pega la cookie sp_dc de tu sesión de Spotify...',
      ),
      CampoProveedor(
        key: 'sp_key',
        label: 'Cookie sp_key',
        hint: 'Pega la cookie sp_key de tu sesión de Spotify...',
      ),
    ],
  ),
  ConfigProveedor(
    id: 'pandora',
    nombreMostrado: 'Pandora',
    icon: Icons.radio,
    campos: [],
  ),
];