class StringsSetup {
  final String selectLanguage, chooseLanguage, continueText, espanol, english;
  final String chooseMode, free, premium, freeInfo, premiumInfo, activateCode, enterCode, codePlaceholder, activate, back, next;
  final String invalidCode, codeActivated, returningUser, yes, no, trialExpired, existingAccount, startFresh;
  final String chooseUsername, usernameHint, usernameSubtitle, randomUsername, usernameKept, usernameChanged;
  final String completingSetup, freeDetailedInfo, premiumDetailedInfo, previousNameWas;
  final String homePreviewTitle, homePreviewDesc;
  final String searchTutorialTitle, searchTutorialDesc, searchHint, searchPasteHint;
  final String searchTracks, searchArtists, searchAlbums, searchPlaylists;
  final String feedTutorialTitle, feedTutorialDesc, feedError, retry, feedEmpty, refresh, hifi;
  final String feedSubtitleTrack, feedSubtitleAlbum, trackDuration, trackType;
  final String addToTitle, addToPlaylist, addToWishlist, playNext;
  final String storageTitle, storageDesc, storageChoose, storageChooseDesc;
  final String storageDefault, storageDefaultDesc, storageSelected, storageDefaultPath;
  final String notificationTitle, notificationDesc, notificationActivate, notificationSkip, notificationGranted;
  final String thankYouTitle, thankYouDesc, thankYouMessage, thankYouSkip, thankYouStarting;
  final String trialActive;
  const StringsSetup({
    required this.selectLanguage, required this.chooseLanguage, required this.continueText, required this.espanol, required this.english,
    required this.chooseMode, required this.free, required this.premium, required this.freeInfo, required this.premiumInfo,
    required this.activateCode, required this.enterCode, required this.codePlaceholder, required this.activate, required this.back,
    required this.next, required this.invalidCode, required this.codeActivated, required this.returningUser, required this.yes,
    required this.no, required this.trialExpired, required this.existingAccount, required this.startFresh,
    required this.chooseUsername, required this.usernameHint, required this.usernameSubtitle, required this.randomUsername,
    required this.usernameKept, required this.usernameChanged, required this.completingSetup, required this.freeDetailedInfo,
    required this.premiumDetailedInfo, required this.previousNameWas,
    required this.homePreviewTitle, required this.homePreviewDesc,
    required this.feedTutorialTitle, required this.feedTutorialDesc, required this.feedError, required this.retry,
    required this.feedEmpty, required this.refresh, required this.hifi,
    required this.searchTutorialTitle, required this.searchTutorialDesc, required this.searchHint, required this.searchPasteHint,
    required this.searchTracks, required this.searchArtists, required this.searchAlbums, required this.searchPlaylists,
    required this.feedSubtitleTrack, required this.feedSubtitleAlbum, required this.trackDuration, required this.trackType,
    required this.addToTitle, required this.addToPlaylist, required this.addToWishlist, required this.playNext,
    required this.storageTitle, required this.storageDesc, required this.storageChoose, required this.storageDefault,
    required this.storageSelected, required this.storageDefaultPath, required this.storageChooseDesc, required this.storageDefaultDesc,
    required this.notificationTitle, required this.notificationDesc, required this.notificationActivate, required this.notificationSkip,
    required this.notificationGranted, required this.thankYouTitle, required this.thankYouDesc,
    required this.thankYouMessage, required this.thankYouSkip, required this.thankYouStarting,
    required this.trialActive,
  });

  static const es = StringsSetup(
    selectLanguage: 'Selecciona tu idioma', chooseLanguage: 'Elige el idioma de la aplicación', continueText: 'Continuar',
    espanol: 'Español', english: 'English', chooseMode: 'Escoge tu modo de uso', free: 'Gratis', premium: 'Premium',
    freeInfo: 'Acceso a descargas gratis por 6 horas', premiumInfo: 'Descargas ilimitadas para siempre',
    activateCode: 'Activar código premium', enterCode: 'Ingresa tu código premium para activar', codePlaceholder: 'Código premium',
    activate: 'Activar', back: 'Anterior', next: 'Siguiente', invalidCode: 'Código inválido', codeActivated: '¡Premium activado!',
    returningUser: 'Esta es tu cuenta, ¿deseas continuar con ella?', yes: 'Sí', no: 'No',
    trialExpired: 'Tu prueba gratis de 6 horas terminó. Puedes seguir usando la app gratis pero las descargas están desactivadas. Activa Premium para descargar.',
    existingAccount: 'Cuenta existente detectada',
    startFresh: 'Si seleccionas No, tendrás que configurar la aplicación desde cero. Si ya usaste tu prueba gratis, el sistema lo detectará.',
    chooseUsername: '¿Cómo quieres que te llamen?', usernameHint: 'Escribe tu nombre',
    usernameSubtitle: 'Puedes escribir tu nombre o usar el generador aleatorio',
    randomUsername: 'Aleatorio', usernameKept: 'Mantener nombre', usernameChanged: 'Cambiar nombre',
    completingSetup: 'Completando configuración...',
    freeDetailedInfo: 'Con el modo Gratis obtienes acceso a descargas por 6 horas desde tu primera activación. Una vez pasadas las 6 horas, necesitarás activar Premium para seguir descargando.',
    premiumDetailedInfo: 'Con el modo Premium obtienes descargas ilimitadas para siempre. Activa tu cuenta ingresando un código premium válido que puedes obtener a través de nuestros canales oficiales.',
    previousNameWas: 'Tu nombre anterior era',
    feedTutorialTitle: 'Tu Feed de Música', feedTutorialDesc: 'Descubre música nueva cada día. Explora canciones, álbumes y artistas recomendados para ti desde todas tus fuentes favoritas.',
    feedError: 'No se pudo cargar el feed', retry: 'Reintentar',
    feedEmpty: 'No hay datos disponibles.', refresh: 'Refrescar', hifi: 'HiFi',
    feedSubtitleTrack: 'Canción', feedSubtitleAlbum: 'Álbum', trackDuration: 'Duración', trackType: 'Tipo',
    addToTitle: 'Agregar a', addToPlaylist: 'Playlist', addToWishlist: 'Lista de deseos', playNext: 'Reproducir después',
    storageTitle: 'Carpeta de descargas',
    storageDesc: 'Elige dónde quieres guardar tus canciones descargadas. Puedes seleccionar una carpeta o usar la ubicación por defecto.',
    storageChoose: 'Elegir carpeta',
    storageChooseDesc: 'Abre el explorador para elegir una carpeta en tu dispositivo',
    storageDefault: 'Usar carpeta por defecto',
    storageDefaultDesc: 'Guarda automáticamente en la carpeta de documentos de la app',
    storageSelected: 'Carpeta seleccionada',
    storageDefaultPath: 'Documentos / Bitly',
    searchTutorialTitle: 'Buscador', searchTutorialDesc: 'Busca cualquier canción, artista, álbum o playlist. Elige entre múltiples fuentes como Spotify, Deezer y más, o pega un enlace directo.',
    searchHint: 'Buscar...', searchPasteHint: 'O pega un enlace de Spotify o YouTube',
    searchTracks: 'Canciones', searchArtists: 'Artistas', searchAlbums: 'Álbumes', searchPlaylists: 'Playlists',
    homePreviewTitle: 'Listo para empezar',
    homePreviewDesc: 'Tu música te espera. Explora, descubre y disfruta de tus canciones favoritas desde un solo lugar.',
    notificationTitle: 'Notificaciones',
    notificationDesc: 'Recibe notificaciones cuando tus canciones estén listas para descargar',
    notificationActivate: 'Activar notificaciones',
    notificationSkip: 'Omitir',
    notificationGranted: 'Notificaciones activadas',
    thankYouTitle: '¡Todo listo!',
    thankYouDesc: 'Preparando tu experiencia musical...',
    thankYouMessage: 'Antes de empezar quiero decirte algo. Esta app me costó mucho tiempo, muchas horas frente a la pantalla, días enteros resolviendo problemas, noches sin dormir, errores tras errores, y momentos en los que quise tirar todo a la basura. Pero aquí está, funcionando, gracias a que tú decidiste quedarte y confiar. Eso para mí significa mucho, más de lo que te imaginas. A partir de ahora Bitly va a recibir soporte y actualizaciones constantes, porque esto recién empieza y quiero que sea cada vez mejor. Pero nada de esto importa realmente. Solo te lo digo para que te des cuenta de que todo se puede, sin importar lo difícil que parezca. Tú también puedes lograr lo que te propongas. Bienvenido a Bitly, que disfrutes.',
    thankYouSkip: 'Comenzar ahora',
    thankYouStarting: 'Comenzando en',
    trialActive: 'Prueba gratis activa — descargas habilitadas',

  );

  static const en = StringsSetup(
    selectLanguage: 'Select your language', chooseLanguage: 'Choose the app language', continueText: 'Continue',
    espanol: 'Español', english: 'English', chooseMode: 'Choose your usage mode', free: 'Free', premium: 'Premium',
    freeInfo: 'Free download access for 6 hours', premiumInfo: 'Unlimited downloads forever',
    activateCode: 'Activate premium code', enterCode: 'Enter your premium code to activate', codePlaceholder: 'Premium code',
    activate: 'Activate', back: 'Back', next: 'Next', invalidCode: 'Invalid code', codeActivated: 'Premium activated!',
    returningUser: 'Is this your account? Do you want to continue with it?', yes: 'Yes', no: 'No',
    trialExpired: 'Your 6-hour free trial has ended. You can continue using the app for free but downloads are disabled. Activate Premium to download.',
    existingAccount: 'Existing account detected',
    startFresh: 'If you select No, you will have to set up the application from scratch. If you already used your free trial, the system will detect it.',
    chooseUsername: 'What should we call you?', usernameHint: 'Enter your name',
    usernameSubtitle: 'Type your name or use the random generator',
    randomUsername: 'Random', usernameKept: 'Keep name', usernameChanged: 'Change name',
    completingSetup: 'Completing setup...',
    freeDetailedInfo: 'With Free mode you get download access for 6 hours from your first activation. After the 6 hours, you will need to activate Premium to continue downloading.',
    premiumDetailedInfo: 'With Premium mode you get unlimited downloads forever. Activate your account by entering a valid premium code available through our official channels.',
    previousNameWas: 'Your previous name was',
    feedTutorialTitle: 'Your Music Feed', feedTutorialDesc: 'Discover new music every day. Browse songs, albums, and artists recommended for you from all your favorite sources.',
    feedError: 'Could not load feed', retry: 'Retry',
    feedEmpty: 'No feed data available.', refresh: 'Refresh', hifi: 'HiFi',
    feedSubtitleTrack: 'Track', feedSubtitleAlbum: 'Album', trackDuration: 'Duration', trackType: 'Type',
    addToTitle: 'Add to', addToPlaylist: 'Playlist', addToWishlist: 'Wishlist', playNext: 'Play next',
    storageTitle: 'Download folder',
    storageDesc: 'Choose where to save your downloaded songs. You can pick a custom folder or use the default location.',
    storageChoose: 'Choose folder',
    storageChooseDesc: 'Open the file explorer to pick a folder on your device',
    storageDefault: 'Use default folder',
    storageDefaultDesc: 'Automatically saves in the app\'s documents folder',
    storageSelected: 'Selected folder',
    storageDefaultPath: 'Documents / Bitly',
    searchTutorialTitle: 'Search', searchTutorialDesc: 'Search any song, artist, album or playlist. Pick from multiple sources like Spotify, Deezer and more, or paste a direct link.',
    searchHint: 'Search...', searchPasteHint: 'Or paste a Spotify or YouTube link',
    searchTracks: 'Tracks', searchArtists: 'Artists', searchAlbums: 'Albums', searchPlaylists: 'Playlists',
    homePreviewTitle: 'Ready to go',
    homePreviewDesc: 'Your music awaits. Explore, discover, and enjoy your favorite tracks all in one place.',
    notificationTitle: 'Notifications',
    notificationDesc: 'Get notified when your songs are ready to download',
    notificationActivate: 'Enable notifications',
    notificationSkip: 'Skip',
    notificationGranted: 'Notifications enabled',
    thankYouTitle: 'All set!',
    thankYouDesc: 'Preparing your music experience...',
    thankYouMessage: 'Before we start, I want to tell you something. This app took a lot of my time — countless hours in front of the screen, whole days solving problems, sleepless nights, error after error, and moments where I wanted to throw it all away. But here it is, working, because you decided to stay and trust me. That means more to me than you can imagine. From now on Bitly will receive regular support and updates, because this is just the beginning and I want it to keep getting better. But none of this really matters. I am just telling you this so you realize that anything is possible, no matter how hard it seems. You can achieve whatever you set your mind to. Welcome to Bitly, enjoy.',
    thankYouSkip: 'Start now',
    thankYouStarting: 'Starting in',
    trialActive: 'Free trial active — downloads enabled',

  );
}
