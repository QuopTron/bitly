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

/// Describes a provider that accepts user-entered credentials.
class ProviderConfig {
  final String id; // extension ID, e.g. 'tidal-web'
  final String displayName;
  final IconData icon;
  final List<ProviderField> fields;

  const ProviderConfig({
    required this.id,
    required this.displayName,
    required this.icon,
    required this.fields,
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
