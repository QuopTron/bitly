// strings_tutorial_interactivo.dart — Textos del tutorial interactivo
// en español e inglés: los botones, el aviso de "otra vista" y el texto de
// cada paso (título + descripción).
//
// Los pasos van en una LISTA y en el mismo orden que `crearPasosTutorial`:
// agregar un paso nuevo es agregar un elemento acá, sin tocar 26 parámetros.
// Un test verifica que la lista tenga el mismo largo que los pasos.
//
// Se conecta con app_localizations.dart y tutorial_pasos.dart.
// Parte del flujo: tutorial interactivo (post-setup).

/// Texto de un paso: título corto y explicación de para qué sirve.
class TextoTutorial {
  final String titulo;
  final String descripcion;

  const TextoTutorial(this.titulo, this.descripcion);
}

/// Textos del tutorial interactivo.
class StringsTutorialInteractivo {
  /// Salir de todo el tutorial.
  final String skipAll;

  /// Saltear solo este paso.
  final String skipStep;

  /// Volver al paso anterior.
  final String back;

  /// Paso siguiente.
  final String next;

  /// Cerrar el tutorial en el último paso.
  final String gotIt;

  /// Aviso para los pasos que explican algo que vive en otra vista.
  final String verEnOtraVista;

  /// Textos de cada paso, en el MISMO orden que `crearPasosTutorial`.
  final List<TextoTutorial> pasos;

  const StringsTutorialInteractivo({
    required this.skipAll,
    required this.skipStep,
    required this.back,
    required this.next,
    required this.gotIt,
    required this.verEnOtraVista,
    required this.pasos,
  });

  static const en = StringsTutorialInteractivo(
    skipAll: 'Skip tutorial',
    skipStep: 'Skip step',
    back: 'Back',
    next: 'Next',
    gotIt: 'Got it!',
    verEnOtraVista: 'You will see it when you open it',
    pasos: [
      TextoTutorial(
        'Discover music',
        'Recommendations, new releases and curated playlists live here. Swipe or scroll to explore every section.',
      ),
      TextoTutorial(
        'Choose your source',
        'Tap here to switch between Tidal, Qobuz, Deezer and the rest. Each source has its own catalog and audio quality.',
      ),
      TextoTutorial(
        'Search anything',
        'Type a song, an artist or paste a Spotify, Deezer or Tidal link: we find it for you.',
      ),
      TextoTutorial(
        'Play instantly',
        'Tap any card to start listening. Music streams in the best quality the source can give.',
      ),
      TextoTutorial(
        'Save your favorites',
        'The heart keeps the song in My Space so you can find it again in one tap.',
      ),
      TextoTutorial(
        'Download for offline',
        'The arrow downloads the album or playlist with the quality you picked in Settings.',
      ),
      TextoTutorial(
        'Always within reach',
        'The miniplayer shows what is playing (same song as the notifications). Tap it for the full player.',
      ),
      TextoTutorial(
        'Full control',
        'In the full player: shuffle, repeat, synced lyrics, video and your play queue.',
      ),
      TextoTutorial(
        'Your settings',
        'Settings open from your profile: look, downloads, performance and your account. I will show you each one.',
      ),
      TextoTutorial(
        'Look and feel',
        'Light or dark theme, visual style and the app language. Changes apply instantly.',
      ),
      TextoTutorial(
        'Downloads',
        'Audio quality (FLAC or MP3), the folder where files are saved and how much space they take.',
      ),
      TextoTutorial(
        'Performance',
        'Performance profiles so the app runs smooth on your device, using less memory and battery.',
      ),
      TextoTutorial(
        'Account and Premium',
        'Your account, the free trial hours, reports and app updates live here.',
      ),
    ],
  );

  static const es = StringsTutorialInteractivo(
    skipAll: 'Saltar tutorial',
    skipStep: 'Saltar paso',
    back: 'Atrás',
    next: 'Siguiente',
    gotIt: '¡Entendido!',
    verEnOtraVista: 'Lo verás al abrirlo',
    pasos: [
      TextoTutorial(
        'Descubrí música',
        'Acá están las recomendaciones, las novedades y las playlists curadas. Deslizá para recorrer cada sección.',
      ),
      TextoTutorial(
        'Elegí tu fuente',
        'Tocá acá para cambiar entre Tidal, Qobuz, Deezer y las demás. Cada fuente tiene su catálogo y su calidad.',
      ),
      TextoTutorial(
        'Buscá lo que quieras',
        'Escribí el nombre, el artista o pegá un enlace de Spotify, Deezer o Tidal: lo encontramos por vos.',
      ),
      TextoTutorial(
        'Reproducí al instante',
        'Tocá cualquier tarjeta para escuchar. Suena en la mejor calidad que dé la fuente elegida.',
      ),
      TextoTutorial(
        'Guardá tus favoritos',
        'El corazón deja la canción en Mi Espacio para volver a encontrarla en un toque.',
      ),
      TextoTutorial(
        'Descargá para el offline',
        'La flecha baja el álbum o la playlist con la calidad que elijas en Ajustes.',
      ),
      TextoTutorial(
        'Siempre a mano',
        'El miniplayer muestra lo que está sonando (la misma canción que la notificación). Tocalo para abrir el reproductor completo.',
      ),
      TextoTutorial(
        'Control total',
        'En el reproductor completo: aleatorio, repetir, letra sincronizada, video y la cola de reproducción.',
      ),
      TextoTutorial(
        'Tus ajustes',
        'Los ajustes se abren desde tu perfil: apariencia, descargas, rendimiento y tu cuenta. Te los muestro uno por uno.',
      ),
      TextoTutorial(
        'Apariencia',
        'Tema claro u oscuro, estilo visual e idioma de la app. Los cambios se aplican al instante.',
      ),
      TextoTutorial(
        'Descargas',
        'Calidad de audio (FLAC o MP3), la carpeta donde se guardan y cuánto espacio ocupan.',
      ),
      TextoTutorial(
        'Rendimiento',
        'Perfiles de rendimiento para que la app vaya fluida en tu equipo, gastando menos memoria y batería.',
      ),
      TextoTutorial(
        'Cuenta y Premium',
        'Tu cuenta, las horas de prueba gratis, los reportes y las actualizaciones de la app.',
      ),
    ],
  );
}
