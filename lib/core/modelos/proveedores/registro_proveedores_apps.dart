// ─────────────────────────────────────────────────────────────
// registro_proveedores_apps.dart — PART de registro_proveedores.dart:
// proveedores "de app" con credenciales simples — Amazon, SoundCloud,
// Spotify (cookies), Soulseek (nombre + contraseña generada) y Pandora.
// Se conecta con: registro_proveedores.dart (spread en `proveedoresTodos`).
// Parte del flujo: Ajustes → Credenciales → Proveedores.
// ─────────────────────────────────────────────────────────────

part of 'registro_proveedores.dart';

/// Proveedores de app con credenciales simples.
const List<ConfigProveedor> proveedoresApps = [
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
    id: 'soulseek',
    nombreMostrado: 'Soulseek',
    icon: Icons.hub_rounded,
    campos: [
      CampoProveedor(
        key: 'usuario',
        label: 'Tu nombre en Soulseek',
        hint: 'Elegí el nombre que querés tener en la red: sin mail, sin captcha '
            'y gratis. Al tocar "Siguiente" se crea tu cuenta con ese nombre y '
            'queda conectada (en Soulseek conectar es registrarse).\n'
            'Máximo 30 caracteres, solo ASCII imprimible (sin acentos ni '
            'emojis) y sin espacios al principio ni al final.',
      ),
    ],
    // La contraseña la genera la app y NO tiene campo visible, pero tiene que
    // sobrevivir a los reinicios: por eso se envía a Go igual, vía
    // clavesAjusteExtra (se guarda como `soulseek_password`).
    clavesAjusteExtra: ['password'],
    acciones: [
      AccionProveedor(
        action: 'soulseekConectar',
        label: 'Siguiente (crear y conectar mi cuenta)',
        icon: Icons.login,
        mensajeConfirmacion: 'Se va a crear (o conectar) tu cuenta de Soulseek '
            'con ese nombre. La contraseña la genera la app y queda guardada: '
            'Soulseek no tiene recuperación, así que vas a poder verla y '
            'exportarla cuando quieras.',
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
