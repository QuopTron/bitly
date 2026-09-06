import 'package:flutter/material.dart';

/// A single credential/text field for a provider.
class ProviderField {
  final String key;
  final String label;
  final String hint;
  final bool multiline;

  const ProviderField({
    required this.key,
    required this.label,
    required this.hint,
    this.multiline = false,
  });
}

/// A side-effect action (SpotiFLAC "button" setting) shown under a provider's
/// fields. Tapping it invokes the JS method named [action] on the extension.
class ProviderAction {
  final String action; // JS export name, e.g. 'clearCachedTokens'
  final String label;
  final IconData icon;

  /// Optional confirmation message shown before running (null = no confirm).
  final String? confirmMessage;

  const ProviderAction({
    required this.action,
    required this.label,
    this.icon = Icons.tune,
    this.confirmMessage,
  });
}

/// Describes a provider that accepts user-entered credentials.
class ProviderConfig {
  final String id; // extension ID, e.g. 'tidal-web'
  final String displayName;
  final IconData icon;
  final List<ProviderField> fields;
  final List<ProviderAction> actions;

  /// Additional setting keys (beyond [fields]) to push to the extension on
  /// startup — e.g. OAuth tokens that the app stores but that have no visible
  /// text field. Keys are stored with the same `<id>_<key>` prefix as fields.
  final List<String> extraSettingKeys;

  const ProviderConfig({
    required this.id,
    required this.displayName,
    required this.icon,
    required this.fields,
    this.actions = const [],
    this.extraSettingKeys = const [],
  });

  /// All credential-requiring providers.
  static const List<ProviderConfig> all = [
    ProviderConfig(
      id: 'tidal-web',
      displayName: 'TIDAL',
      icon: Icons.water_drop,
      fields: [
        ProviderField(
          key: 'tidalAccessToken',
          label: 'Access Token',
          hint: 'Paste Tidal access token...',
        ),
        ProviderField(
          key: 'tidalCookie',
          label: 'Session Cookie',
          hint: 'Paste full Tidal session cookie string...',
          multiline: true,
        ),
      ],
    ),
    ProviderConfig(
      id: 'apple-music',
      displayName: 'Apple',
      icon: Icons.apple,
      fields: [
        ProviderField(
          key: 'mediaUserToken',
          label: 'Media User Token',
          hint: 'Required for lyrics. Get from music.apple.com browser console…',
        ),
      ],
    ),
    ProviderConfig(
      id: 'ytmusic-spotiflac',
      displayName: 'YouTube',
      icon: Icons.music_video,
      fields: [
        ProviderField(
          key: 'manualGvsPoToken',
          label: 'Manual GVS PO Token',
          hint: 'Optional raw token for 403 bypass…',
        ),
        ProviderField(
          key: 'oauthClientId',
          label: 'OAuth Client ID (Google Cloud)',
          hint: 'Console → Credenciales → ID de cliente OAuth (apps.googleusercontent.com)',
        ),
        ProviderField(
          key: 'oauthClientSecret',
          label: 'OAuth Client Secret (opcional)',
          hint: 'Solo visible al crear el cliente OAuth',
        ),
      ],
      // Tokens produced by the OAuth flow have no visible field, but must be
      // pushed to the extension on startup so the session survives restarts.
      extraSettingKeys: ['oauthAccessToken', 'oauthRefreshToken'],
      actions: [
        ProviderAction(
          action: 'youtubeOauthConnect',
          label: 'Iniciar sesión con YouTube',
          icon: Icons.login,
        ),
        ProviderAction(
          action: 'youtubeOauthLogout',
          label: 'Cerrar sesión de YouTube',
          icon: Icons.logout,
          confirmMessage: '¿Cerrar la sesión de YouTube? Se eliminarán los tokens '
              'de tu cuenta de este dispositivo.',
        ),
        ProviderAction(
          action: 'clearCachedTokens',
          label: 'Limpiar caché de tokens (PO/visitor)',
          icon: Icons.cleaning_services_outlined,
          confirmMessage: '¿Limpiar la caché de tokens de YouTube? Se forzará a '
              're-resolver todo (PO token, visitor data, client) en la próxima '
              'búsqueda/reproducción. Útil si ves errores 403.',
        ),
      ],
    ),
    ProviderConfig(
      id: 'qobuz-web',
      displayName: 'Qobuz',
      icon: Icons.album,
      fields: [
        ProviderField(
          key: 'email',
          label: 'Correo electrónico',
          hint: 'tu@email.com',
        ),
        ProviderField(
          key: 'password',
          label: 'Contraseña',
          hint: 'Contraseña de tu cuenta Qobuz',
        ),
      ],
    ),
    ProviderConfig(
      id: 'deezer',
      displayName: 'Deezer',
      icon: Icons.headphones,
      fields: [],
    ),
    ProviderConfig(
      id: 'amazon',
      displayName: 'Amazon',
      icon: Icons.shopping_cart,
      fields: [],
    ),
    ProviderConfig(
      id: 'soundcloud',
      displayName: 'SoundCloud',
      icon: Icons.cloud,
      fields: [],
    ),
    ProviderConfig(
      id: 'spotify-web',
      displayName: 'Spotify',
      icon: Icons.music_note,
      fields: [
        ProviderField(
          key: 'sp_dc',
          label: 'Cookie sp_dc',
          hint: 'Pega la cookie sp_dc de tu sesión de Spotify...',
        ),
        ProviderField(
          key: 'sp_key',
          label: 'Cookie sp_key',
          hint: 'Pega la cookie sp_key de tu sesión de Spotify...',
        ),
      ],
    ),
    ProviderConfig(
      id: 'pandora',
      displayName: 'Pandora',
      icon: Icons.radio,
      fields: [],
    ),
  ];

  /// Whether this provider has credential fields the user can fill in.
  bool get hasCredentialFields => fields.isNotEmpty;

}
