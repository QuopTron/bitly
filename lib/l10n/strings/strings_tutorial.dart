// ─────────────────────────────────────────────────────────────
// strings_tutorial.dart — Textos del tutorial de bienvenida en
// español e inglés: los 4 pasos (icono, título y descripción) y
// los botones Siguiente/Empezar. Se conecta con app_localizations.
// Parte del flujo: tutorial (bienvenida tras el primer arranque).
// ─────────────────────────────────────────────────────────────

/// Textos del tutorial de bienvenida.
class StringsTutorial {
  final String paso1Titulo;
  final String paso1Desc;
  final String paso2Titulo;
  final String paso2Desc;
  final String paso3Titulo;
  final String paso3Desc;
  final String paso4Titulo;
  final String paso4Desc;
  final String siguiente;
  final String empezar;

  const StringsTutorial({
    required this.paso1Titulo,
    required this.paso1Desc,
    required this.paso2Titulo,
    required this.paso2Desc,
    required this.paso3Titulo,
    required this.paso3Desc,
    required this.paso4Titulo,
    required this.paso4Desc,
    required this.siguiente,
    required this.empezar,
  });

  /// Textos en inglés.
  static const en = StringsTutorial(
    paso1Titulo: 'Welcome to Bitly',
    paso1Desc: 'Download music in FLAC quality from multiple sources.',
    paso2Titulo: 'Search your music',
    paso2Desc:
        'Search by name, artist or paste a Spotify, Deezer, Tidal link and more.',
    paso3Titulo: 'Download offline',
    paso3Desc:
        'Download tracks or whole albums with one tap. Choose the quality you prefer.',
    paso4Titulo: 'Extensions',
    paso4Desc:
        'Install extensions from the store to add new music sources.',
    siguiente: 'Next',
    empezar: 'Get started',
  );

  /// Textos en español.
  static const es = StringsTutorial(
    paso1Titulo: 'Bienvenido a Bitly',
    paso1Desc: 'Descarga música en calidad FLAC desde múltiples fuentes.',
    paso2Titulo: 'Busca tu música',
    paso2Desc:
        'Busca por nombre, artista o pega un enlace de Spotify, Deezer, Tidal y más.',
    paso3Titulo: 'Descarga offline',
    paso3Desc:
        'Descarga tracks o discos enteros con un toque. Elige la calidad que prefieras.',
    paso4Titulo: 'Extensiones',
    paso4Desc:
        'Instala extensiones desde la tienda para agregar nuevas fuentes de música.',
    siguiente: 'Siguiente',
    empezar: 'Empezar',
  );
}