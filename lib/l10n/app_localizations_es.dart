// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'package:bitly/constants/app_info.dart';
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => AppInfo.appName;

  @override
  String get navHome => 'Inicio';

  @override
  String get navLibrary => 'Biblioteca';

  @override
  String get navSettings => 'Ajustes';

  @override
  String get navStore => 'Repositorio';

  @override
  String get homeTitle => 'Inicio';

  @override
  String get homeSubtitle => 'Pega una URL compatible o busca por nombre';

  @override
  String get homeEmptyTitle => 'Aún no hay proveedores de búsqueda';

  bool _freeTrialSelected = false;
  String get homeEmptySubtitle => 'Instala una extensión para continuar.';

  @override
  String get homeSupports => 'Soportes: Pista, Álbum, Lista de reproducción, URLs de Artistas';

  @override
  String get homeRecent => 'Recientes';

  @override
  String get historyFilterAll => 'Todo';

  @override
  String get historyFilterAlbums => 'Álbumes';

  @override
  String get historyFilterSingles => 'Pistas';

  @override
  String get historySearchHint => 'Buscar en historial...';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsDownload => 'Descargar';

  @override
  String get settingsAppearance => 'Apariencia';

  @override
  String get settingsOptions => 'Opciones';

  @override
  String get settingsExtensions => 'Extensiones';

  @override
  String get settingsAbout => 'Acerca de';

  @override
  String get downloadTitle => 'Descargar';

  @override
  String get downloadAskQualitySubtitle => 'Mostrar selector de calidad para cada descarga';

  @override
  String get downloadFilenameFormat => 'Formato del nombre del archivo';

  @override
  String get downloadSingleFilenameFormat => 'Formato de título único';

  @override
  String get downloadSingleFilenameFormatDescription => 'Patrón de título para sencillos y mini-álbumes. Usa las mismas etiquetas que un álbum completo.';

  @override
  String get downloadFolderOrganization => 'Organización de carpetas';

  @override
  String get appearanceTitle => 'Apariencia';

  @override
  String get appearanceThemeSystem => 'Sistema';

  @override
  String get appearanceThemeLight => 'Claro';

  @override
  String get appearanceThemeDark => 'Oscuro';

  @override
  String get appearanceDynamicColor => 'Color dinámico';

  @override
  String get appearanceDynamicColorSubtitle => 'Usar colores de tu fondo de pantalla';

  @override
  String get appearanceHistoryView => 'Vista de Historial';

  @override
  String get appearanceHistoryViewList => 'Lista';

  @override
  String get appearanceHistoryViewGrid => 'Cuadrícula';

  @override
  String get optionsTitle => 'Opciones';

  @override
  String get optionsPrimaryProvider => 'Proveedor Principal';

  @override
  String get optionsPrimaryProviderSubtitle => 'Servicio usado al buscar por nombre de la pista.';

  @override
  String optionsUsingExtension(String extensionName) {
    return 'Usando la extensión: $extensionName';
  }
  
  @override
  String get optionsDefaultSearchTab => 'Pestaña de búsqueda predeterminada';

  @override
  String get optionsDefaultSearchTabSubtitle => 'Elige qué pestaña se abre primero para los nuevos resultados de búsqueda.';

  @override
  String get optionsSwitchBack => 'Toque Deezer o Spotify para volver desde la extensión';

  @override
  String get optionsAutoFallback => 'Alternativa automática';

  @override
  String get optionsAutoFallbackSubtitle => 'Pruebe otros servicios si falla la descarga';

  @override
  String get optionsUseExtensionProviders => 'Usar proveedores de extensiones';

  @override
  String get optionsUseExtensionProvidersOn => 'Las extensiones serán probadas primero';

  @override
  String get optionsUseExtensionProvidersOff => 'Utilizando sólo proveedores integrados';

  @override
  String get optionsEmbedLyrics => 'Incrustar Letras';

  @override
  String get optionsEmbedLyricsSubtitle => 'Insertar letras sincronizadas en archivos FLAC';

  @override
  String get optionsMaxQualityCover => 'Carátula de calidad máxima';

  @override
  String get optionsMaxQualityCoverSubtitle => 'Descargar carátula de resolución máxima';

  @override
  String get optionsReplayGain => 'Nivelación de Ganancia';

  @override
  String get optionsReplayGainSubtitleOn => 'Analizar volumen e incrustar etiquetas de RG (EBU-R128)';

  @override
  String get optionsReplayGainSubtitleOff => 'Desactivado: sin etiquetas de normalización de volumen';

  @override
  String get optionsArtistTagMode => 'Modo de Etiqueta de Artista';

  @override
  String get optionsArtistTagModeDescription => 'Elija cómo se ingresan múltiples artistas en etiquetas incrustadas.';

  @override
  String get optionsArtistTagModeJoined => 'Valor único ingresado';

  @override
  String get optionsArtistTagModeJoinedSubtitle => 'Escribe un valor ARTIST, como \"Artista A, Artista B\" para mejor compatibilidad en reproductores.';

  @override
  String get optionsArtistTagModeSplitVorbis => 'Dividir (recortar) etiquetar para FLAC/OPUS';

  @override
  String get optionsArtistTagModeSplitVorbisSubtitle => 'Escribe una etiqueta de artista por artista para FLAC y OPUS; MP3 y M4A se mantienen agrupados.';

  @override
  String get optionsConcurrentDownloads => 'Descargas Simultáneas';

  @override
  String get optionsConcurrentSequential => 'Secuencial (1 a la vez)';

  @override
  String optionsConcurrentParallel(int count) {
    return '$count descargas paralelas';
  }

  @override
  String get optionsConcurrentWarning => 'Las descargas paralelas pueden activar la limitación de velocidad';

  @override
  String get optionsExtensionStore => 'Extensión .Repo (repositorio)';

  @override
  String get optionsExtensionStoreSubtitle => 'Mostar barra de navegación repo';

  @override
  String get optionsCheckUpdates => 'Comprobar actualizaciones';

  @override
  String get optionsCheckUpdatesSubtitle => 'Notificar cuando una nueva versión esté disponible';

  @override
  String get optionsUpdateChannel => 'Tipo de actualizaciones';

  @override
  String get optionsUpdateChannelStable => 'Sólo versiones estables';

  @override
  String get optionsUpdateChannelPreview => 'Versión preliminar';

  @override
  String get optionsUpdateChannelWarning => 'La Versión preliminar puede contener errores o características incompletas';

  @override
  String get optionsClearHistory => 'Borrar el historial de descargas';

  @override
  String get optionsClearHistorySubtitle => 'Eliminar todas las pistas descargadas del historial';

  @override
  String get optionsDetailedLogging => 'Registro detallado';

  @override
  String get optionsDetailedLoggingOn => 'Registros detallados están siendo registrados';

  @override
  String get optionsDetailedLoggingOff => 'Habilitar para informes de errores';

  @override
  String get optionsSpotifyCredentials => 'Credenciales de Spotify';

  @override
  String optionsSpotifyCredentialsConfigured(String clientId) {
    return 'ID de cliente: $clientId...';
  }

  @override
  String get optionsSpotifyCredentialsRequired => 'Requerido - toque para configurar';

  @override
  String get optionsSpotifyWarning => 'Spotify requiere tus propias credenciales API. Obténgalas gratis de developer.spotify.com';

  @override
  String get optionsSpotifyDeprecationWarning => 'La función de búsqueda de Spotify dejará de estar disponible el 3 de marzo de 2026 debido a cambios en la API de Spotify. Te recomendamos que te pases a Deezer.';

  @override
  String get extensionsTitle => 'Extensiones';

  @override
  String get extensionsDisabled => 'Deshabilitado';

  @override
  String extensionsVersion(String version) {
    return 'Versión $version';
  }

  @override
  String extensionsAuthor(String author) {
    return 'por $author';
  }

  @override
  String get extensionsUninstall => 'Desinstalar';

  @override
  String get storeTitle => 'Extensión .Repo';

  @override
  String get storeSearch => 'Buscar extensiones...';

  @override
  String get storeInstall => 'Instalar';

  @override
  String get storeInstalled => 'Instalada';

  @override
  String get storeUpdate => 'Actualizar';

  @override
  String get aboutTitle => 'Acerca de';

  @override
  String get aboutContributors => 'Colaboradores';

  @override
  String get aboutMobileDeveloper => 'Desarrollador de versiones móviles';

  @override
  String get aboutOriginalCreator => 'Creador original de Bitly';

  @override
  String get aboutLogoArtist => '¡El talentoso artista que creó nuestro hermoso logo!';

  @override
  String get aboutTranslators => 'Traductores';

  @override
  String get aboutSpecialThanks => 'Agradecimientos especiales';

  @override
  String get aboutLinks => 'Enlaces';

  @override
  String get aboutMobileSource => 'Código fuente móvil';

  @override
  String get aboutPCSource => 'Código fuente de PC';

  @override
  String get aboutKeepAndroidOpen => 'Keep Android Open';

  @override
  String get aboutReportIssue => 'Reportar un problema';

  @override
  String get aboutReportIssueSubtitle => 'Reporta cualquier problema que encuentres';

  @override
  String get aboutFeatureRequest => 'Sugerir una función';

  @override
  String get aboutFeatureRequestSubtitle => 'Sugerir nuevas funciones para la aplicación';

  @override
  String get aboutTelegramChannel => 'Canal de Telegram';

  @override
  String get aboutTelegramChannelSubtitle => 'Anuncios y actualizaciones';

  @override
  String get aboutTelegramChat => 'Comunidad de Telegram';

  @override
  String get aboutTelegramChatSubtitle => 'Chatear con otros usuarios';

  @override
  String get aboutSocial => 'Redes sociales';

  @override
  String get aboutApp => 'Aplicación';

  @override
  String get aboutVersion => 'Versión';

  @override
  String get aboutBinimumDesc => 'El creador de la API QQDL & Hi-Fi. ¡Sin esta API, las descargas de Tidal no existiría!';

  @override
  String get aboutSachinsenalDesc => 'El creador original del proyecto Hi-Fi. ¡La base de la integración de Tidal!';

  @override
  String get aboutSjdonadoDesc => 'Creador de I No tengo Spotify (IDHS). ¡La solución de enlace de reserva que salva el día!';

  @override
  String get aboutAppDescription => 'Descargar pistas de Spotify en alta calidad (sin pérdida) de Tidal y Qobuz.';

  @override
  String get artistAlbums => 'Álbumes';

  @override
  String get artistSingles => 'Pistas y EPs';

  @override
  String get artistCompilations => 'Compilaciones';

  @override
  String get artistPopular => 'Populares';

  @override
  String artistMonthlyListeners(String count) {
    return '$count oyentes mensuales';
  }

  @override
  String get trackMetadataService => 'Servicio';

  @override
  String get trackMetadataPlay => 'Reproducir';

  @override
  String get trackMetadataShare => 'Compartir';

  @override
  String get trackMetadataDelete => 'Eliminar';

  @override
  String get setupGrantPermission => 'Conceder permiso';

  @override
  String get setupSkip => 'Omitir por ahora';

  @override
  String get setupStorageAccessRequired => 'Acceso al almacenamiento requerido';

  @override
  String get setupStorageAccessMessageAndroid11 => 'Android 11+ requiere permiso \"Todos los archivos de acceso\" para guardar los archivos en la carpeta de descargas elegida.';

  @override
  String get setupOpenSettings => 'Abrir ajustes';

  @override
  String get setupPermissionDeniedMessage => 'Permiso denegado. Por favor, conceda todos los permisos para continuar.';

  @override
  String setupPermissionRequired(String permissionType) {
    return 'Permiso de $permissionType requerido';
  }

  @override
  String setupPermissionRequiredMessage(String permissionType) {
    return 'Se requiere un permiso $permissionType para la mejor experiencia. Puedes cambiar esto más tarde en ajustes.';
  }

  @override
  String get setupUseDefaultFolder => '¿Usar carpeta por defecto?';

  @override
  String get setupNoFolderSelected => 'No se ha seleccionado ninguna carpeta. ¿Desea utilizar la carpeta por defecto?';

  @override
  String get setupUseDefault => 'Usar por defecto';

  @override
  String get setupDownloadLocationTitle => 'Ubicación de descarga';

  @override
  String get setupDownloadLocationIosMessage => 'En iOS, las descargas se guardan en la carpeta de documentos de la aplicación. Puede acceder a ellas desde la aplicación Archivos.';

  @override
  String get setupAppDocumentsFolder => 'Carpeta de documentos de App';

  @override
  String get setupAppDocumentsFolderSubtitle => 'Recomendado - accesible desde la aplicación Archivos';

  @override
  String get setupChooseFromFiles => 'Elegir de archivos';

  @override
  String get setupChooseFromFilesSubtitle => 'Seleccione iCloud u otra ubicación';

  @override
  String get setupIosEmptyFolderWarning => 'Limitación de iOS: No se pueden seleccionar carpetas vacías. Elige una carpeta con al menos un archivo.';

  @override
  String get setupIcloudNotSupported => 'iCloud Drive no es compatible. Utilice la carpeta Documentos de la aplicación.';

  @override
  String get setupDownloadInFlac => 'Descargar pistas de Spotify en FLAC';

  @override
  String get setupStorageGranted => '¡Permiso de almacenamiento concedido!';

  @override
  String get setupStorageRequired => 'Permiso de almacenamiento requerido';

  @override
  String get setupStorageDescription => 'Bitly necesita permiso de almacenamiento para guardar sus archivos de música descargados.';

  @override
  String get setupNotificationGranted => '¡Acceso a las notificaciones permitido!';

  @override
  String get setupNotificationEnable => 'Activar notificaciones';

  @override
  String get setupFolderChoose => 'Cambiar carpeta de descargas';

  @override
  String get setupFolderDescription => 'Seleccione una carpeta donde se guardará la música descargada.';

  @override
  String get setupSelectFolder => 'Seleccionar Carpeta';

  @override
  String get setupEnableNotifications => 'Activar notificaciones';

  @override
  String get setupNotificationBackgroundDescription => 'Recibe notificaciones sobre el progreso de la descarga y la finalización. Esto te ayuda a rastrear las descargas cuando la aplicación está en segundo plano.';

  @override
  String get setupSkipForNow => 'Omitir por ahora';

  @override
  String get setupNext => 'Siguiente';

  @override
  String get setupGetStarted => 'Empezar';

  @override
  String get setupAllowAccessToManageFiles => 'Por favor, activa \"Permitir el acceso para gestionar todos los archivos\" en la siguiente pantalla.';

  @override
  String get setupLanguageTitle => 'Elegir idioma';

  @override
  String get setupLanguageDescription => 'Selecciona tu idioma preferido para la aplicación. Puedes cambiarlo después en Ajustes.';

  @override
  String get setupLanguageSystemDefault => 'Predeterminado del sistema';

  @override
  String get dialogCancel => 'Cancelar';

  @override
  String get dialogSave => 'Guardar';

  @override
  String get dialogDelete => 'Eliminar';

  @override
  String get dialogRetry => 'Volver a intentar';

  @override
  String get dialogClear => 'Borrar';

  @override
  String get dialogDone => 'Hecho';

  @override
  String get dialogImport => 'Importar';

  @override
  String get dialogDownload => 'Descargar';

  @override
  String get dialogDiscard => 'Descartar';

  @override
  String get dialogRemove => 'Eliminar';

  @override
  String get dialogUninstall => 'Desinstalar';

  @override
  String get dialogDiscardChanges => '¿Descartar cambios?';

  @override
  String get dialogUnsavedChanges => 'Tienes cambios sin guardar. ¿Quieres descartarlos?';

  @override
  String get dialogClearAll => 'Eliminar todo';

  @override
  String get dialogRemoveExtension => 'Eliminar extensión';

  @override
  String get dialogRemoveExtensionMessage => '¿Estás seguro de que quieres eliminar esta extensión? Esto no se puede deshacer.';

  @override
  String get dialogUninstallExtension => '¿Desinstalar extensión?';

  @override
  String dialogUninstallExtensionMessage(String extensionName) {
    return '¿Estás seguro de que quieres eliminar $extensionName?';
  }

  @override
  String get dialogClearHistoryTitle => 'Borrar historial';

  @override
  String get dialogClearHistoryMessage => '¿Estás seguro de que quieres borrar todo el historial de descargas? Esta acción no se puede deshacer.';

  @override
  String get dialogDeleteSelectedTitle => 'Borrar Seleccionados';

  @override
  String dialogDeleteSelectedMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'pistas',
      one: 'pista',
    );
    return '¿Eliminar $count $_temp0 del historial?\n\nEsto también eliminará los archivos del almacenamiento.';
  }

  @override
  String get dialogImportPlaylistTitle => 'Importar lista de reproducción';

  @override
  String dialogImportPlaylistMessage(int count) {
    return 'Se han encontrado pistas $count en CSV. ¿Añadirlas para descargar la cola?';
  }

  @override
  String csvImportTracks(int count) {
    return '$count pistas de CSV';
  }

  @override
  String snackbarAddedToQueue(String trackName) {
    return 'Añadido \"$trackName\" a la cola';
  }

  @override
  String snackbarAddedTracksToQueue(int count) {
    return 'Añadidas pistas $count a la cola';
  }

  @override
  String snackbarAlreadyDownloaded(String trackName) {
    return '\"$trackName\" ya descargado';
  }

  @override
  String snackbarAlreadyInLibrary(String trackName) {
    return '\"$trackName\" ya existe en tu biblioteca';
  }

  @override
  String get snackbarHistoryCleared => 'Historial borrado';

  @override
  String get snackbarCredentialsSaved => 'Credenciales guardadas';

  @override
  String get snackbarCredentialsCleared => 'Credenciales borradas';

  @override
  String snackbarDeletedTracks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'pistas',
      one: 'pista',
    );
    return 'Eliminado $count $_temp0';
  }

  @override
  String snackbarCannotOpenFile(String error) {
    return 'No se puede abrir el archivo: $error';
  }

  @override
  String snackbarFileUnavailableOffline(String title) {
    return '\"$title\" no está disponible sin conexión';
  }

  @override
  String snackbarFileUnavailableOnline(String title) {
    return 'No se pudo reproducir \"$title\"';
  }

  @override
  String get snackbarFillAllFields => 'Por favor, completa todos los campos';

  @override
  String get snackbarViewQueue => 'Ver cola';

  @override
  String snackbarUrlCopied(String platform) {
    return 'URL $platform copiada al portapapeles';
  }

  @override
  String get snackbarFileNotFound => 'Archivo no encontrado';

  @override
  String get snackbarSelectExtFile => 'Por favor, seleccione un archivo .Bitly-ext';

  @override
  String get snackbarProviderPrioritySaved => 'Prioridad de proveedor guardada';

  @override
  String get snackbarMetadataProviderSaved => 'Prioridad de proveedor de metadatos guardada';

  @override
  String snackbarExtensionInstalled(String extensionName) {
    return '$extensionName instalado.';
  }

  @override
  String snackbarExtensionUpdated(String extensionName) {
    return '$extensionName actualizada.';
  }

  @override
  String get snackbarFailedToInstall => 'Fallo al instalar la extensión';

  @override
  String get snackbarFailedToUpdate => 'Error al actualizar la extensión';

  @override
  String get errorRateLimited => 'Límite Excedido';

  @override
  String get errorRateLimitedMessage => 'Demasiadas solicitudes. Por favor, espere un momento antes de buscar de nuevo.';

  @override
  String get errorNoTracksFound => 'No se encontraron pistas';

  @override
  String get errorUrlNotRecognized => 'Enlace no reconocido';

  @override
  String get errorUrlNotRecognizedMessage => 'Este enlace no es compatible. Asegúrate de que la URL sea correcta y de tener instalada una extensión compatible.';

  @override
  String get errorUrlFetchFailed => 'No se ha podido cargar el contenido de este enlace. Inténtalo de nuevo.';

  @override
  String errorMissingExtensionSource(String item) {
    return 'No se puede cargar $item: falta una fuente de extensión';
  }

  @override
  String get actionPause => 'Pausar';

  @override
  String get actionResume => 'Reanudar';

  @override
  String get actionCancel => 'Cancelar';

  @override
  String get actionSelectAll => 'Seleccionar Todo';

  @override
  String get actionDeselect => 'Deseleccionar';

  @override
  String get actionRemoveCredentials => 'Eliminar credenciales';

  @override
  String get actionSaveCredentials => 'Guardar credenciales';

  @override
  String selectionSelected(int count) {
    return '$count seleccionado';
  }

  @override
  String get selectionAllSelected => 'Todas las pistas seleccionadas';

  @override
  String get selectionSelectToDelete => 'Seleccionar pistas a eliminar';

  @override
  String progressFetchingMetadata(int current, int total) {
    return 'Obteniendo metadatos... $current/$total';
  }

  @override
  String get progressReadingCsv => 'Leyendo CSV...';

  @override
  String get searchSongs => 'Canciones';

  @override
  String get searchArtists => 'Artistas';

  @override
  String get searchAlbums => 'Álbumes';

  @override
  String get searchPlaylists => 'Listas de reproducción';

  @override
  String get searchSortTitle => 'Ordenar resultados';

  @override
  String get searchSortDefault => 'Por defecto';

  @override
  String get searchSortTitleAZ => 'Nombre (A-Z)';

  @override
  String get searchSortTitleZA => 'Nombre (Z-A)';

  @override
  String get searchSortArtistAZ => 'Artista (A-Z)';

  @override
  String get searchSortArtistZA => 'Artista (Z-A)';

  @override
  String get searchSortDurationShort => 'Duración (más corto)';

  @override
  String get searchSortDurationLong => 'Duración (más largo)';

  @override
  String get searchSortDateOldest => 'Fecha de lanzamiento (antiguo)';

  @override
  String get searchSortDateNewest => 'Fecha de lanzamiento (reciente)';

  @override
  String get tooltipPlay => 'Reproducir';

  @override
  String get tooltipPlayOnline => 'Reproducir online';

  @override
  String get filenameFormat => 'Formato del nombre del archivo';

  @override
  String get filenameShowAdvancedTags => 'Mostrar etiquetas avanzadas';

  @override
  String get filenameShowAdvancedTagsDescription => 'Habilitar etiquetas con formato para el relleno de pistas y los formatos de fecha';

  @override
  String get folderOrganizationNone => 'Ninguna organización';

  @override
  String get folderOrganizationByPlaylist => 'Por Playlist';

  @override
  String get folderOrganizationByPlaylistSubtitle => 'Una carpeta independiente para cada Playlist';

  @override
  String get folderOrganizationByArtist => 'Por Artista';

  @override
  String get folderOrganizationByAlbum => 'Por Álbum';

  @override
  String get folderOrganizationByArtistAlbum => 'Artista/Álbum';

  @override
  String get folderOrganizationDescription => 'Organizar los archivos descargados en carpetas';

  @override
  String get folderOrganizationNoneSubtitle => 'Todos los archivos de la carpeta de descargas';

  @override
  String get folderOrganizationByArtistSubtitle => 'Carpeta separada para cada artista';

  @override
  String get folderOrganizationByAlbumSubtitle => 'Carpeta separada para cada artista';

  @override
  String get folderOrganizationByArtistAlbumSubtitle => 'Carpetas organizadas por artista y álbum';

  @override
  String get updateAvailable => 'Actualización Disponible';

  @override
  String get updateLater => 'Más tarde';

  @override
  String get updateStartingDownload => 'Iniciando descarga...';

  @override
  String get updateDownloadFailed => 'Descarga fallida';

  @override
  String get updateFailedMessage => 'Error al descargar la actualización';

  @override
  String get updateNewVersionReady => 'Una nueva versión está lista';

  @override
  String get updateCurrent => 'Actual';

  @override
  String get updateNew => 'Nuevo';

  @override
  String get updateDownloading => 'Descargando...';

  @override
  String get updateWhatsNew => 'Novedades';

  @override
  String get updateDownloadInstall => 'Descargar & Instalar';

  @override
  String get updateDontRemind => 'No recordar';

  @override
  String get providerPriorityTitle => 'Prioridad del proveedor';

  @override
  String get providerPriorityDescription => 'Arrastra para reordenar los proveedores de descarga. La aplicación intentará usar los proveedores de arriba hacia abajo al descargar las pistas.';

  @override
  String get providerPriorityInfo => 'Si una pista no está disponible en el primer proveedor, la aplicación intentará automáticamente el siguiente.';

  @override
  String get providerPriorityFallbackExtensionsTitle => 'Fallback de extensión';

  @override
  String get providerPriorityFallbackExtensionsDescription => 'Elije qué extensiones instaladas se pueden utilizar durante el cambio automático a una alternativa. Los proveedores integrados siguen el orden de prioridad indicado anteriormente.';

  @override
  String get providerPriorityFallbackExtensionsHint => 'Solo las extensiones activas con proveedor de descarga se listan aquí.';

  @override
  String get providerBuiltIn => 'Integrado';

  @override
  String get providerExtension => 'Extensión';

  @override
  String get metadataProviderPriorityTitle => 'Prioridad de los metadatos';

  @override
  String get metadataProviderPriorityDescription => 'Arrastra para reordenar los proveedores de metadatos. La aplicación probará los proveedores de arriba hacia abajo al buscar pistas y obtener los metadatos.';

  @override
  String get metadataProviderPriorityInfo => 'Deezer no tiene límites de tasa y se recomienda como principal. Spotify puede valorar el límite después de muchas solicitudes.';

  @override
  String get metadataNoRateLimits => 'Sin límites de tasa';

  @override
  String get metadataMayRateLimit => 'Sin límites de tasa';

  @override
  String get logTitle => 'Registros';

  @override
  String get logCopied => 'Registros copiados al portapapeles';

  @override
  String get logSearchHint => 'Buscar registros...';

  @override
  String get logFilterLevel => 'Nivel';

  @override
  String get logFilterSection => 'Filtrar';

  @override
  String get logShareLogs => 'Compartir registros';

  @override
  String get logClearLogs => 'Borrar registros';

  @override
  String get logClearLogsTitle => 'Limpiar registros';

  @override
  String get logClearLogsMessage => '¿Estás seguro que deseas limpiar todos los registros?';

  @override
  String get logFilterBySeverity => 'Filtrar los registros por gravedad';

  @override
  String get logNoLogsYet => 'No hay registros aún';

  @override
  String get logNoLogsYetSubtitle => 'Los registros aparecerán aquí mientras usas la aplicación';

  @override
  String logEntriesFiltered(int count) {
    return 'Entradas ($count filtradas)';
  }

  @override
  String logEntries(int count) {
    return 'Entradas ($count)';
  }

  @override
  String get credentialsTitle => 'Credenciales de Spotify';

  @override
  String get credentialsDescription => 'Introduzca su ID de cliente y secreto para utilizar su propia cuota de aplicación de Spotify.';

  @override
  String get credentialsClientId => 'ID del cliente';

  @override
  String get credentialsClientIdHint => 'Pegar ID de cliente';

  @override
  String get credentialsClientSecret => 'Client Secret';

  @override
  String get credentialsClientSecretHint => 'Pegar Client Secret';

  @override
  String get channelStable => 'Estable';

  @override
  String get channelPreview => 'Vista previa';

  @override
  String get sectionSearchSource => 'Buscar Fuente';

  @override
  String get sectionDownload => 'Descargar';

  @override
  String get sectionPerformance => 'Alto rendimiento';

  @override
  String get sectionApp => 'Aplicación';

  @override
  String get sectionData => 'Datos';

  @override
  String get sectionDebug => 'Depuración';

  @override
  String get sectionService => 'Servicio';

  @override
  String get sectionAudioQuality => 'Calidad de Sonido';

  @override
  String get sectionFileSettings => 'Ajustes del archivo';

  @override
  String get sectionLyrics => 'Letras';

  @override
  String get lyricsMode => 'Modo Letras';

  @override
  String get lyricsModeDescription => 'Elige cómo se guardan las letras de tus descargas';

  @override
  String get lyricsModeEmbed => 'Insertar en archivo';

  @override
  String get lyricsModeEmbedSubtitle => 'Letras almacenadas en los metadatos FLAC';

  @override
  String get lyricsModeExternal => 'Archivo .lrc externo';

  @override
  String get lyricsModeExternalSubtitle => 'Archivo .lrc separado para reproductores como Samsung Music';

  @override
  String get lyricsModeBoth => 'Ambos';

  @override
  String get lyricsModeBothSubtitle => 'Insertar y guardar archivo .lrc';

  @override
  String get sectionColor => 'Colores';

  @override
  String get sectionTheme => 'Tema';

  @override
  String get sectionLayout => 'Diseño';

  @override
  String get sectionLanguage => 'Idioma';

  @override
  String get appearanceLanguage => 'Idioma de la aplicación';

  @override
  String get settingsAppearanceSubtitle => 'Tema, colores, pantalla';

  @override
  String get settingsDownloadSubtitle => 'Servicio, calidad, formato del nombre del archivo';

  @override
  String get settingsOptionsSubtitle => 'Alternativa, letras, carátula, actualizaciones';

  @override
  String get settingsExtensionsSubtitle => 'Administrar proveedores de descarga';

  @override
  String get settingsLogsSubtitle => 'Ver registros de aplicaciones para depuración';

  @override
  String get loadingSharedLink => 'Cargando enlace compartido...';

  @override
  String get pressBackAgainToExit => 'Presione de nuevo para salir';

  @override
  String downloadAllCount(int count) {
    return 'Descargar Todo ($count)';
  }

  @override
  String tracksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pistas',
      one: '1 pista',
    );
    return '$_temp0';
  }

  @override
  String get trackCopyFilePath => 'Copiar ruta de archivo';

  @override
  String get trackRemoveFromDevice => 'Eliminar del dispositivo';

  @override
  String get trackLoadLyrics => 'Cargar letras';

  @override
  String get trackMetadata => 'Metadatos';

  @override
  String get trackFileInfo => 'Información de archivo';

  @override
  String get trackLyrics => 'Letras';

  @override
  String get trackFileNotFound => 'Archivo no encontrado';

  @override
  String get trackOpenInDeezer => 'Abrir en Deezer';

  @override
  String get trackOpenInSpotify => 'Abrir en Spotify';

  @override
  String get trackTrackName => 'Nombre de pista';

  @override
  String get trackArtist => 'Artista';

  @override
  String get trackAlbumArtist => 'Artista del álbum';

  @override
  String get trackAlbum => 'Álbum';

  @override
  String get trackTrackNumber => 'Número de pista';

  @override
  String get trackDiscNumber => 'Número de disco';

  @override
  String get trackDuration => 'Duración';

  @override
  String get trackAudioQuality => 'Calidad del sonido';

  @override
  String get trackReleaseDate => 'Fecha de lanzamiento';

  @override
  String get trackGenre => 'Género';

  @override
  String get trackLabel => 'Etiqueta';

  @override
  String get trackCopyright => 'Derechos de autor';

  @override
  String get trackDownloaded => 'Descargado';

  @override
  String get trackCopyLyrics => 'Copiar letras';

  @override
  String get trackLyricsNotAvailable => 'Letras no disponibles para este tema';

  @override
  String get trackLyricsNotInFile => 'No se encontraron letras';

  @override
  String get trackFetchOnlineLyrics => 'Obtener en línea';

  @override
  String get trackLyricsTimeout => 'Tiempo de espera agotado. Inténtalo de nuevo más tarde.';

  @override
  String get trackLyricsLoadFailed => 'Error al cargar la letra';

  @override
  String get trackEmbedLyrics => 'Incrustar Letras';

  @override
  String get trackLyricsEmbedded => 'Letra incrustada con éxito';

  @override
  String get trackInstrumental => 'Pista intrumental';

  @override
  String get trackCopiedToClipboard => 'Copiado al portapapeles';

  @override
  String get trackDeleteConfirmTitle => '¿Eliminar del dispositivo?';

  @override
  String get trackDeleteConfirmMessage => 'Esto eliminará permanentemente el archivo descargado y lo eliminará de tu historial.';

  @override
  String get dateToday => 'Hoy';

  @override
  String get dateYesterday => 'Ayer';

  @override
  String dateDaysAgo(int count) {
    return 'Hace $count días';
  }

  @override
  String dateWeeksAgo(int count) {
    return '$count semanas antes';
  }

  @override
  String dateMonthsAgo(int count) {
    return '$count meses atrás';
  }

  @override
  String get storeFilterAll => 'Todo';

  @override
  String get storeFilterMetadata => 'Metadatos';

  @override
  String get storeFilterDownload => 'Descargar';

  @override
  String get storeFilterUtility => 'Utilidad';

  @override
  String get storeFilterLyrics => 'Letras';

  @override
  String get storeFilterIntegration => 'Integración';

  @override
  String get storeClearFilters => 'Limpiar filtros';

  @override
  String get storeAddRepoTitle => 'Añadir repositorio de extensiones';

  @override
  String get storeAddRepoDescription => 'Introduzca una URL de repositorio de GitHub que contenga un archivo registry.json para navegar e instalar extensiones.';

  @override
  String get storeRepoUrlLabel => 'URL del repositorio';

  @override
  String get storeRepoUrlHint => 'https://github.com/user/repo';

  @override
  String get storeRepoUrlHelper => 'Ejemplo: https://github.com/user/extensions-repo';

  @override
  String get storeAddRepoButton => 'Añadir repositorio';

  @override
  String get storeChangeRepoTooltip => 'Cambiar repositorio';

  @override
  String get storeRepoDialogTitle => 'Repositorio de extensiones';

  @override
  String get storeRepoDialogCurrent => 'Repositorio actual:';

  @override
  String get storeNewRepoUrlLabel => 'Nueva URL del repositorio';

  @override
  String get storeLoadError => 'Falló al carga repositorio';

  @override
  String get storeEmptyNoExtensions => 'No hay extensiones disponibles';

  @override
  String get storeEmptyNoResults => 'No se encontraron extensiones';

  @override
  String get extensionDefaultProvider => 'Predeterminado (Deezer)';

  @override
  String get extensionDefaultProviderSubtitle => 'Usar búsqueda integrada';

  @override
  String get extensionAuthor => 'Autor/a';

  @override
  String get extensionId => 'ID';

  @override
  String get extensionError => 'Error';

  @override
  String get extensionCapabilities => 'Recursos';

  @override
  String get extensionMetadataProvider => 'Proveedor de metadatos';

  @override
  String get extensionDownloadProvider => 'Proveedor de descargas';

  @override
  String get extensionLyricsProvider => 'Proveedor de letras';

  @override
  String get extensionUrlHandler => 'Gestor de URL';

  @override
  String get extensionQualityOptions => 'Opciones de calidad';

  @override
  String get extensionPostProcessingHooks => 'Hooks post-procesamiento';

  @override
  String get extensionPermissions => 'Permisos';

  @override
  String get extensionSettings => 'Ajustes';

  @override
  String get extensionRemoveButton => 'Eliminar extensión';

  @override
  String get extensionUpdated => 'Actualizado';

  @override
  String get extensionMinAppVersion => 'Versión Mínima de la aplicación';

  @override
  String get extensionCustomTrackMatching => 'Coincidencia de pista personalizada';

  @override
  String get extensionPostProcessing => 'Post-Procesamiento';

  @override
  String extensionHooksAvailable(int count) {
    return '$count hook(s) disponibles';
  }

  @override
  String extensionPatternsCount(int count) {
    return 'Patrón(es) $count';
  }

  @override
  String extensionStrategy(String strategy) {
    return 'Estrategia: $strategy';
  }

  @override
  String get extensionsProviderPrioritySection => 'Prioridad del proveedor';

  @override
  String get extensionsInstalledSection => 'Extensiones instaladas';

  @override
  String get extensionsNoExtensions => 'No hay extensiones instaladas';

  @override
  String get extensionsNoExtensionsSubtitle => 'Instalar archivos .Bitly-ext para añadir nuevos proveedores';

  @override
  String get extensionsInstallButton => 'Instalar extensión';

  @override
  String get extensionsInfoTip => 'Las extensiones pueden añadir nuevos metadatos y proveedores de descargas. Sólo instalar extensiones desde fuentes confiables.';

  @override
  String get extensionsInstalledSuccess => 'Extensión instalada correctamente';

  @override
  String extensionsInstalledCount(int count) {
    return '$count extensiones instaladas correctamente';
  }

  @override
  String extensionsInstallPartialSuccess(int installed, int attempted) {
    return 'Instaladas $installed de $attempted extensiones';
  }

  @override
  String get extensionsDownloadPriority => 'Prioridad de descarga';

  @override
  String get extensionsDownloadPrioritySubtitle => 'Establecer orden de servicio de descarga';

  @override
  String get extensionsFallbackTitle => 'Fallback de extensiones';

  @override
  String get extensionsFallbackSubtitle => 'Elija que extensiones pueden usarse como reserva';

  @override
  String get extensionsNoDownloadProvider => 'No hay extensiones con proveedor de descargas';

  @override
  String get extensionsMetadataPriority => 'Prioridad de los metadatos';

  @override
  String get extensionsMetadataPrioritySubtitle => 'Establecer orden de búsqueda y metadatos';

  @override
  String get extensionsNoMetadataProvider => 'No hay extensiones con el proveedor de metadatos';

  @override
  String get extensionsSearchProvider => 'Proveedor de búsqueda';

  @override
  String get extensionsNoCustomSearch => 'No hay extensiones con búsqueda personalizada';

  @override
  String get extensionsSearchProviderDescription => 'Elegir qué servicio usar para buscar pistas';

  @override
  String get extensionsCustomSearch => 'Búsqueda personalizada';

  @override
  String get extensionsErrorLoading => 'Error al cargar la extensión';

  @override
  String get qualityFlacLossless => 'FLAC Lossless';

  @override
  String get qualityFlacLosslessSubtitle => '16-bit / 44.1kHz';

  @override
  String get qualityHiResFlac => 'Hi-Res FLAC';

  @override
  String get qualityHiResFlacSubtitle => '24 bits/hasta 96kHz';

  @override
  String get qualityHiResFlacMax => 'Hi-Res FLAC Max';

  @override
  String get qualityHiResFlacMaxSubtitle => '24 bits / hasta 192kHz';

  @override
  String get downloadLossy320 => 'Con pérdida, 320 kbps';

  @override
  String get downloadLossyFormat => 'Formato con pérdida';

  @override
  String get downloadLossy320Format => 'Formato con pérdida a 320 kbps';

  @override
  String get downloadLossy320FormatDesc => 'Elige el formato de salida para las descargas con pérdida de Tidal a 320kbps. La transmisión AAC original se convertirá al formato que hayas seleccionado.';

  @override
  String get downloadLossyMp3 => 'MP3 (320kbps)';

  @override
  String get downloadLossyMp3Subtitle => 'Óptima compatibilidad, ~10 MB por pista';

  @override
  String get downloadLossyOpus256 => 'OPUS (256kbps)';

  @override
  String get downloadLossyOpus256Subtitle => 'Opus de la mejor calidad, ~8 MB por pista';

  @override
  String get downloadLossyOpus128 => 'OPUS (128kbps)';

  @override
  String get downloadLossyOpus128Subtitle => 'Tamaño mínimo: ~4 MB por pista';

  @override
  String get qualityNote => 'La calidad real depende de la disponibilidad de la pista del servicio';

  @override
  String get downloadAskBeforeDownload => 'Preguntar antes de descargar';

  @override
  String get downloadDirectory => 'Carpeta de descarga';

  @override
  String get downloadSeparateSinglesFolder => 'Carpeta separada para pistas';

  @override
  String get downloadAlbumFolderStructure => 'Estructura de carpeta del álbum';

  @override
  String get downloadUseAlbumArtistForFolders => 'Usar álbum de artista cómo carpeta';

  @override
  String get downloadUsePrimaryArtistOnly => 'Artista principal solo para carpetas';

  @override
  String get downloadUsePrimaryArtistOnlyEnabled => 'Se han eliminado los nombres de los artistas destacados del nombre de la carpeta (p. ej., Justin Bieber, Quavo → Justin Bieber)';

  @override
  String get downloadUsePrimaryArtistOnlyDisabled => 'Se utiliza el nombre completo del artista como nombre de la carpeta';

  @override
  String get downloadSelectQuality => 'Seleccionar Calidad';

  @override
  String get downloadFrom => 'Descargar Desde';

  @override
  String get appearanceAmoledDark => 'AMOLED Oscuro';

  @override
  String get appearanceAmoledDarkSubtitle => 'Fondo negro puro';

  @override
  String get queueClearAll => 'Eliminar todo';

  @override
  String get queueClearAllMessage => '¿Estás seguro de que quieres borrar todas las descargas?';

  @override
  String get settingsAutoExportFailed => 'Autoexportar descargas fallidas';

  @override
  String get settingsAutoExportFailedSubtitle => 'Guardar descargas fallidas en el archivo TXT automáticamente';

  @override
  String get settingsDownloadNetwork => 'Red de descarga';

  @override
  String get settingsDownloadNetworkAny => 'WiFi + Datos móviles';

  @override
  String get settingsDownloadNetworkWifiOnly => 'Iniciar solo por Wifi';

  @override
  String get settingsDownloadNetworkSubtitle => 'Elegir qué red usar para descargas. Cuando se establece en WiFi solamente, las descargas se detendrán en los datos móviles.';

  @override
  String get albumFolderArtistAlbum => 'Artista / Álbum';

  @override
  String get albumFolderArtistAlbumSubtitle => 'Álbumes/Nombre del Artista/Nombre del Álbum/';

  @override
  String get albumFolderArtistYearAlbum => 'Artista / [Año] Álbum';

  @override
  String get albumFolderArtistYearAlbumSubtitle => 'Álbumes/Nombre del Artista /[2005] Nombre del Álbum/';

  @override
  String get albumFolderAlbumOnly => 'Sólo álbum';

  @override
  String get albumFolderAlbumOnlySubtitle => 'Álbumes/Nombre del Álbum/';

  @override
  String get albumFolderYearAlbum => 'Álbum [Año]';

  @override
  String get albumFolderYearAlbumSubtitle => 'Álbumes/[2005] Nombre del Álbum/';

  @override
  String get albumFolderArtistAlbumSingles => 'Artista / Álbum + Pistas';

  @override
  String get albumFolderArtistAlbumSinglesSubtitle => 'Artista/Álbum/ y Artista/pistas/';

  @override
  String get albumFolderArtistAlbumFlat => 'Artista / Álbum (sencillos planos)';

  @override
  String get albumFolderArtistAlbumFlatSubtitle => 'Artist/Album/ and Artist/song.flac';

  @override
  String get downloadedAlbumDeleteSelected => 'Borrar Seleccionados';

  @override
  String downloadedAlbumDeleteMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'pistas',
      one: 'pista',
    );
    return '¿Eliminar $count $_temp0 del historial?\n\nEsto también eliminará los archivos del almacenamiento.';
  }

  @override
  String downloadedAlbumSelectedCount(int count) {
    return '$count seleccionado';
  }

  @override
  String get downloadedAlbumAllSelected => 'Todas las pistas seleccionadas';

  @override
  String get downloadedAlbumTapToSelect => 'Toca las pistas para seleccionar';

  @override
  String downloadedAlbumDeleteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'pistas',
      one: 'pista',
    );
    return '¡Eliminar $count $_temp0';
  }

  @override
  String get downloadedAlbumSelectToDelete => 'Seleccionar pistas a eliminar';

  @override
  String downloadedAlbumDiscHeader(int discNumber) {
    return 'Disco $discNumber';
  }

  @override
  String get recentTypeArtist => 'Artista';

  @override
  String get recentTypeAlbum => 'Álbum';

  @override
  String get recentTypeSong => 'Canción';

  @override
  String get recentTypePlaylist => 'Lista de reproducción';

  @override
  String get recentEmpty => 'Aún no hay entradas recientes';

  @override
  String get recentShowAllDownloads => 'Mostrar todas las descargas';

  @override
  String recentPlaylistInfo(String name) {
    return 'Lista de reproducción: $name';
  }

  @override
  String get discographyDownload => 'Descargar Discografía';

  @override
  String get discographyDownloadAll => 'Descargar Todo';

  @override
  String discographyDownloadAllSubtitle(int count, int albumCount) {
    return '$count pistas de $albumCount lanzamientos';
  }

  @override
  String get discographyAlbumsOnly => 'Sólo álbumes';

  @override
  String discographyAlbumsOnlySubtitle(int count, int albumCount) {
    return '$count pistas de $albumCount álbumes';
  }

  @override
  String get discographySinglesOnly => 'Solo sencillos & EPs ';

  @override
  String discographySinglesOnlySubtitle(int count, int albumCount) {
    return '$count Pistas de $albumCount sencillos';
  }

  @override
  String get discographySelectAlbums => 'Seleccionar álbumes...';

  @override
  String get discographySelectAlbumsSubtitle => 'Elige álbumes o sencillos concretos';

  @override
  String get discographyFetchingTracks => 'Cargando canciones...';

  @override
  String discographyFetchingAlbum(int current, int total) {
    return 'Cargando $current de $total...';
  }

  @override
  String discographySelectedCount(int count) {
    return '$count seleccionados';
  }

  @override
  String get discographyDownloadSelected => 'Descargar seleccionados';

  @override
  String discographyAddedToQueue(int count) {
    return 'Added $count tracks to queue';
  }

  @override
  String discographySkippedDownloaded(int added, int skipped) {
    return '$added added, $skipped already downloaded';
  }

  @override
  String get discographyNoAlbums => 'No albums available';

  @override
  String get discographyFailedToFetch => 'Failed to fetch some albums';

  @override
  String get sectionStorageAccess => 'Storage Access';

  @override
  String get allFilesAccess => 'All Files Access';

  @override
  String get allFilesAccessEnabledSubtitle => 'Can write to any folder';

  @override
  String get allFilesAccessDisabledSubtitle => 'Limited to media folders only';

  @override
  String get allFilesAccessDescription => 'Enable this if you encounter write errors when saving to custom folders. Android 13+ restricts access to certain directories by default.';

  @override
  String get allFilesAccessDeniedMessage => 'Permission was denied. Please enable \'All files access\' manually in system settings.';

  @override
  String get allFilesAccessDisabledMessage => 'All Files Access disabled. The app will use limited storage access.';

  @override
  String get settingsLocalLibrary => 'Local Library';

  @override
  String get settingsLocalLibrarySubtitle => 'Scan music & detect duplicates';

  @override
  String get settingsCache => 'Almacenamiento & Caché';

  @override
  String get settingsCacheSubtitle => 'Ver tamaño y borrar datos en caché';

  @override
  String get libraryTitle => 'Local Library';

  @override
  String get libraryScanSettings => 'Scan Settings';

  @override
  String get libraryEnableLocalLibrary => 'Enable Local Library';

  @override
  String get libraryEnableLocalLibrarySubtitle => 'Escanea y rastrea tu música existente';

  @override
  String get libraryFolder => 'Library Folder';

  @override
  String get libraryFolderHint => 'Tap to select folder';

  @override
  String get libraryShowDuplicateIndicator => 'Show Duplicate Indicator';

  @override
  String get libraryShowDuplicateIndicatorSubtitle => 'Show when searching for existing tracks';

  @override
  String get libraryAutoScan => 'Escaneo Automático';

  @override
  String get libraryAutoScanSubtitle => 'Automatically scan your library for new files';

  @override
  String get libraryAutoScanOff => 'Apagado';

  @override
  String get libraryAutoScanOnOpen => 'Every app open';

  @override
  String get libraryAutoScanDaily => 'Daily';

  @override
  String get libraryAutoScanWeekly => 'Weekly';

  @override
  String get libraryActions => 'Actions';

  @override
  String get libraryScan => 'Scan Library';

  @override
  String get libraryScanSubtitle => 'Scan for audio files';

  @override
  String get libraryScanSelectFolderFirst => 'Select a folder first';

  @override
  String get libraryCleanupMissingFiles => 'Cleanup Missing Files';

  @override
  String get libraryCleanupMissingFilesSubtitle => 'Remove entries for files that no longer exist';

  @override
  String get libraryClear => 'Clear Library';

  @override
  String get libraryClearSubtitle => 'Remove all scanned tracks';

  @override
  String get libraryClearConfirmTitle => 'Clear Library';

  @override
  String get libraryClearConfirmMessage => 'This will remove all scanned tracks from your library. Your actual music files will not be deleted.';

  @override
  String get libraryAbout => 'About Local Library';

  @override
  String get libraryAboutDescription => 'Scans your existing music collection to detect duplicates when downloading. Supports FLAC, M4A, MP3, Opus, and OGG formats. Metadata is read from file tags when available.';

  @override
  String libraryTracksUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tracks',
      one: 'track',
    );
    return '$_temp0';
  }

  @override
  String libraryFilesUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'files',
      one: 'file',
    );
    return '$_temp0';
  }

  @override
  String libraryLastScanned(String time) {
    return 'Last scanned: $time';
  }

  @override
  String get libraryLastScannedNever => 'Never';

  @override
  String get libraryScanning => 'Scanning...';

  @override
  String get libraryScanFinalizing => 'Finalizing library...';

  @override
  String libraryScanProgress(String progress, int total) {
    return '$progress% of $total files';
  }

  @override
  String get libraryInLibrary => 'In Library';

  @override
  String libraryRemovedMissingFiles(int count) {
    return 'Removed $count missing files from library';
  }

  @override
  String get libraryCleared => 'Library cleared';

  @override
  String get libraryStorageAccessRequired => 'Storage Access Required';

  @override
  String get libraryStorageAccessMessage => 'Bitly needs storage access to scan your music library. Please grant permission in settings.';

  @override
  String get libraryFolderNotExist => 'Selected folder does not exist';

  @override
  String get librarySourceDownloaded => 'Descargado';

  @override
  String get librarySourceLocal => 'Local';

  @override
  String get libraryFilterAll => 'Todo';

  @override
  String get libraryFilterAllQuality => 'Todas las calidades';

  @override
  String get libraryFilterAllFormat => 'Todos los formatos';

  @override
  String get libraryFilterAllMetadata => 'Todos los metadatos';

  @override
  String get libraryFilterDownloaded => 'Descargado';

  @override
  String get libraryFilterLocal => 'Local';

  @override
  String get libraryFilterTitle => 'Filters';

  @override
  String get libraryFilterReset => 'Reset';

  @override
  String get libraryFilterApply => 'Apply';

  @override
  String get libraryFilterSource => 'Source';

  @override
  String get libraryFilterQuality => 'Quality';

  @override
  String get libraryFilterQualityHiRes => 'Hi-Res (24bit)';

  @override
  String get libraryFilterQualityCD => 'CD (16bit)';

  @override
  String get libraryFilterQualityLossy => 'Lossy';

  @override
  String get libraryFilterFormat => 'Format';

  @override
  String get libraryFilterMetadata => 'Metadata';

  @override
  String get libraryFilterMetadataComplete => 'Complete metadata';

  @override
  String get libraryFilterMetadataMissingAny => 'Missing any metadata';

  @override
  String get libraryFilterMetadataMissingYear => 'Missing year';

  @override
  String get libraryFilterMetadataMissingGenre => 'Missing genre';

  @override
  String get libraryFilterMetadataMissingAlbumArtist => 'Missing album artist';

  @override
  String get libraryFilterSort => 'Sort';

  @override
  String get libraryFilterSortLatest => 'Latest';

  @override
  String get libraryFilterSortOldest => 'Oldest';

  @override
  String get libraryFilterSortAlbumAsc => 'Album (A-Z)';

  @override
  String get libraryFilterSortAlbumDesc => 'Album (Z-A)';

  @override
  String get libraryFilterSortGenreAsc => 'Genre (A-Z)';

  @override
  String get libraryFilterSortGenreDesc => 'Genre (Z-A)';

  @override
  String get timeJustNow => 'Just now';

  @override
  String timeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String timeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String get tutorialWelcomeTitle => '¡Bienvenido a Bitly!';

  @override
  String get tutorialWelcomeDesc => 'Let\'s learn how to download your favorite music in lossless quality. This quick tutorial will show you the basics.';

  @override
  String get tutorialWelcomeTip1 => 'Download music from Spotify, Deezer, or paste any supported URL';

  @override
  String get tutorialWelcomeTip2 => 'Get FLAC quality audio from Tidal, Qobuz, or Deezer';

  @override
  String get tutorialWelcomeTip3 => 'Automatic metadata, cover art, and lyrics embedding';

  @override
  String get tutorialSearchTitle => 'Finding Music';

  @override
  String get tutorialSearchDesc => 'There are two easy ways to find music you want to download.';

  @override
  String get tutorialDownloadTitle => 'Downloading Music';

  @override
  String get tutorialDownloadDesc => 'Downloading music is simple and fast. Here\'s how it works.';

  @override
  String get tutorialLibraryTitle => 'Your Library';

  @override
  String get tutorialLibraryDesc => 'All your downloaded music is organized in the Library tab.';

  @override
  String get tutorialLibraryTip1 => 'View download progress and queue in the Library tab';

  @override
  String get tutorialLibraryTip2 => 'Tap any track to play it with your music player';

  @override
  String get tutorialLibraryTip3 => 'Switch between list and grid view for better browsing';

  @override
  String get tutorialExtensionsTitle => 'Extensions';

  @override
  String get tutorialExtensionsDesc => 'Extend the app\'s capabilities with community extensions.';

  @override
  String get tutorialExtensionsTip1 => 'Browse the Repo tab to discover useful extensions';

  @override
  String get tutorialExtensionsTip2 => 'Add new download providers or search sources';

  @override
  String get tutorialExtensionsTip3 => 'Get lyrics, enhanced metadata, and more features';

  @override
  String get tutorialSettingsTitle => 'Customize Your Experience';

  @override
  String get tutorialSettingsDesc => 'Personalize the app in Settings to match your preferences.';

  @override
  String get tutorialSettingsTip1 => 'Change download location and folder organization';

  @override
  String get tutorialSettingsTip2 => 'Set default audio quality and format preferences';

  @override
  String get tutorialSettingsTip3 => 'Customize app theme and appearance';

  @override
  String get tutorialReadyMessage => 'You\'re all set! Start downloading your favorite music now.';

  @override
  String get libraryForceFullScan => 'Force Full Scan';

  @override
  String get libraryForceFullScanSubtitle => 'Rescan all files, ignoring cache';

  @override
  String get cleanupOrphanedDownloads => 'Cleanup Orphaned Downloads';

  @override
  String get cleanupOrphanedDownloadsSubtitle => 'Remove history entries for files that no longer exist';

  @override
  String cleanupOrphanedDownloadsResult(int count) {
    return 'Removed $count orphaned entries from history';
  }

  @override
  String get cleanupOrphanedDownloadsNone => 'No orphaned entries found';

  @override
  String get cacheTitle => 'Storage & Cache';

  @override
  String get cacheSummaryTitle => 'Cache overview';

  @override
  String get cacheSummarySubtitle => 'Clearing cache will not remove downloaded music files.';

  @override
  String cacheEstimatedTotal(String size) {
    return 'Estimated cache usage: $size';
  }

  @override
  String get cacheSectionStorage => 'Cached Data';

  @override
  String get cacheSectionMaintenance => 'Maintenance';

  @override
  String get cacheAppDirectory => 'App cache directory';

  @override
  String get cacheAppDirectoryDesc => 'HTTP responses, WebView data, and other temporary app data.';

  @override
  String get cacheTempDirectory => 'Temporary directory';

  @override
  String get cacheTempDirectoryDesc => 'Temporary files from downloads and audio conversion.';

  @override
  String get cacheCoverImage => 'Cover image cache';

  @override
  String get cacheCoverImageDesc => 'Downloaded album and track cover art. Will re-download when viewed.';

  @override
  String get cacheLibraryCover => 'Library cover cache';

  @override
  String get cacheLibraryCoverDesc => 'Cover art extracted from local music files. Will re-extract on next scan.';

  @override
  String get cacheExploreFeed => 'Explore feed cache';

  @override
  String get cacheExploreFeedDesc => 'Explore tab content (new releases, trending). Will refresh on next visit.';

  @override
  String get cacheTrackLookup => 'Track lookup cache';

  @override
  String get cacheTrackLookupDesc => 'Spotify/Deezer track ID lookups. Clearing may slow next few searches.';

  @override
  String get cacheCleanupUnusedDesc => 'Remove orphaned download history and library entries for missing files.';

  @override
  String get cacheNoData => 'No cached data';

  @override
  String cacheSizeWithFiles(String size, int count) {
    return '$size in $count files';
  }

  @override
  String cacheSizeOnly(String size) {
    return '$size';
  }

  @override
  String cacheEntries(int count) {
    return '$count entries';
  }

  @override
  String cacheClearSuccess(String target) {
    return 'Cleared: $target';
  }

  @override
  String get cacheClearConfirmTitle => 'Clear cache?';

  @override
  String cacheClearConfirmMessage(String target) {
    return 'This will clear cached data for $target. Downloaded music files will not be deleted.';
  }

  @override
  String get cacheClearAllConfirmTitle => 'Clear all cache?';

  @override
  String get cacheClearAllConfirmMessage => 'This will clear all cache categories on this page. Downloaded music files will not be deleted.';

  @override
  String get cacheClearAll => 'Clear all cache';

  @override
  String get cacheCleanupUnused => 'Cleanup unused data';

  @override
  String get cacheCleanupUnusedSubtitle => 'Remove orphaned download history and missing library entries';

  @override
  String cacheCleanupResult(int downloadCount, int libraryCount) {
    return 'Cleanup completed: $downloadCount orphaned downloads, $libraryCount missing library entries';
  }

  @override
  String get cacheRefreshStats => 'Refresh stats';

  @override
  String get trackSaveCoverArt => 'Save Cover Art';

  @override
  String get trackSaveCoverArtSubtitle => 'Save album art as .jpg file';

  @override
  String get trackSaveLyrics => 'Save Lyrics (.lrc)';

  @override
  String get trackSaveLyricsSubtitle => 'Fetch and save lyrics as .lrc file';

  @override
  String get trackSaveLyricsProgress => 'Saving lyrics...';

  @override
  String get trackReEnrich => 'Re-enrich';

  @override
  String get trackReEnrichOnlineSubtitle => 'Search metadata online and embed into file';

  @override
  String get trackReEnrichFieldsTitle => 'Fields to update';

  @override
  String get trackReEnrichFieldCover => 'Cover Art';

  @override
  String get trackReEnrichFieldLyrics => 'Lyrics';

  @override
  String get trackReEnrichFieldBasicTags => 'Album, Album Artist';

  @override
  String get trackReEnrichFieldTrackInfo => 'Track & Disc Number';

  @override
  String get trackReEnrichFieldReleaseInfo => 'Date & ISRC';

  @override
  String get trackReEnrichFieldExtra => 'Genre, Label, Copyright';

  @override
  String get trackReEnrichSelectAll => 'Select All';

  @override
  String get trackEditMetadata => 'Edit Metadata';

  @override
  String trackCoverSaved(String fileName) {
    return 'Cover art saved to $fileName';
  }

  @override
  String get trackCoverNoSource => 'No cover art source available';

  @override
  String trackLyricsSaved(String fileName) {
    return 'Lyrics saved to $fileName';
  }

  @override
  String get trackReEnrichProgress => 'Re-enriching metadata...';

  @override
  String get trackReEnrichSearching => 'Searching metadata online...';

  @override
  String get trackReEnrichSuccess => 'Metadata re-enriched successfully';

  @override
  String get trackReEnrichFfmpegFailed => 'FFmpeg metadata embed failed';

  @override
  String get queueFlacAction => 'Queue FLAC';

  @override
  String queueFlacConfirmMessage(int count) {
    return 'Search online matches for the selected tracks and queue FLAC downloads.\n\nExisting files will not be modified or deleted.\n\nOnly high-confidence matches are queued automatically.\n\n$count selected';
  }

  @override
  String queueFlacFindingProgress(int current, int total) {
    return 'Finding FLAC matches... ($current/$total)';
  }

  @override
  String get queueFlacNoReliableMatches => 'No reliable online matches found for the selection';

  @override
  String queueFlacQueuedWithSkipped(int addedCount, int skippedCount) {
    return 'Added $addedCount tracks to queue, skipped $skippedCount';
  }

  @override
  String trackSaveFailed(String error) {
    return 'Failed: $error';
  }

  @override
  String get trackConvertFormat => 'Convert Format';

  @override
  String get trackConvertFormatSubtitle => 'Convert to MP3, Opus, ALAC, or FLAC';

  @override
  String get trackConvertTitle => 'Convert Audio';

  @override
  String get trackConvertTargetFormat => 'Target Format';

  @override
  String get trackConvertBitrate => 'Bitrate';

  @override
  String get trackConvertConfirmTitle => 'Confirm Conversion';

  @override
  String trackConvertConfirmMessage(String sourceFormat, String targetFormat, String bitrate) {
    return 'Convert from $sourceFormat to $targetFormat at $bitrate?\n\nThe original file will be deleted after conversion.';
  }

  @override
  String trackConvertConfirmMessageLossless(String sourceFormat, String targetFormat) {
    return 'Convert from $sourceFormat to $targetFormat? (Lossless — no quality loss)\n\nThe original file will be deleted after conversion.';
  }

  @override
  String get trackConvertLosslessHint => 'Lossless conversion — no quality loss';

  @override
  String get trackConvertConverting => 'Converting audio...';

  @override
  String trackConvertSuccess(String format) {
    return 'Converted to $format successfully';
  }

  @override
  String get trackConvertFailed => 'Conversion failed';

  @override
  String get cueSplitTitle => 'Split CUE Sheet';

  @override
  String get cueSplitSubtitle => 'Split CUE+FLAC into individual tracks';

  @override
  String cueSplitAlbum(String album) {
    return 'Album: $album';
  }

  @override
  String cueSplitArtist(String artist) {
    return 'Artist: $artist';
  }

  @override
  String cueSplitTrackCount(int count) {
    return '$count tracks';
  }

  @override
  String get cueSplitConfirmTitle => 'Split CUE Album';

  @override
  String cueSplitConfirmMessage(String album, int count) {
    return 'Split \"$album\" into $count individual FLAC files?\n\nFiles will be saved to the same directory.';
  }

  @override
  String cueSplitSplitting(int current, int total) {
    return 'Splitting CUE sheet... ($current/$total)';
  }

  @override
  String cueSplitSuccess(int count) {
    return 'Split into $count tracks successfully';
  }

  @override
  String get cueSplitFailed => 'CUE split failed';

  @override
  String get cueSplitNoAudioFile => 'Audio file not found for this CUE sheet';

  @override
  String get cueSplitButton => 'Split into Tracks';

  @override
  String get actionCreate => 'Create';

  @override
  String get collectionFoldersTitle => 'My folders';

  @override
  String get collectionWishlist => 'Wishlist';

  @override
  String get collectionLoved => 'Loved';

  @override
  String get collectionFavoriteArtists => 'Artistas LibraryCollectionsFavorites';

  @override
  String get collectionAll => 'Todo';

  @override
  String get collectionSongs => 'Canciones';

  @override
  String get collectionAlbums => 'Álbumes';

  @override
  String get collectionArtists => 'Artistas';

  @override
  String get collectionPlaylists => 'Listas de reproducción';

  @override
  String get collectionPlaylist => 'Playlist';

  @override
  String get collectionAddToPlaylist => 'Añadir a lista de reproducción';

  @override
  String get collectionCreatePlaylist => 'Crear playlist';

  @override
  String get collectionNoPlaylistsYet => 'No hay playlist';

  @override
  String get collectionNoPlaylistsSubtitle => 'Crea una playlist para comenzar a categorizar canciones';

  @override
  String collectionPlaylistTracks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canciones',
      one: '1 canción',
    );
    return '$_temp0';
  }

  @override
  String collectionArtistCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count artistas',
      one: '1 artista',
    );
    return '$_temp0';
  }

  @override
  String collectionAddedToPlaylist(String playlistName) {
    return 'Añadido a \"$playlistName\"';
  }

  @override
  String collectionAlreadyInPlaylist(String playlistName) {
    return 'Ya está en \"$playlistName\"';
  }

  @override
  String get collectionPlaylistCreated => 'Playlist creada';

  @override
  String get collectionPlaylistNameHint => 'Nombre de la playlist';

  @override
  String get collectionPlaylistNameRequired => 'El nombre de la playlist es obligatorio';

  @override
  String get collectionRenamePlaylist => 'Renombrar playlist';

  @override
  String get collectionDeletePlaylist => 'Eliminar playlist';

  @override
  String collectionDeletePlaylistMessage(String playlistName) {
    return 'Eliminar \"$playlistName\" y las canciones dentro de ella?';
  }

  @override
  String get collectionPlaylistDeleted => 'Playlist eliminada';

  @override
  String get collectionPlaylistRenamed => 'Playlist renombrada';

  @override
  String get collectionWishlistEmptyTitle => 'Lista de deseos es vacia';

  @override
  String get collectionWishlistEmptySubtitle => 'Presiona + en las canciones para saber que descargar luego';

  @override
  String get collectionLovedEmptyTitle => 'Me gusta esta vacio';

  @override
  String get collectionLovedEmptySubtitle => 'Preciona en el corazon para saber que te gusta la cancion';

  @override
  String get collectionFavoriteArtistsEmptyTitle => 'Aún no hay artistas LibraryCollectionsFavorites';

  @override
  String get collectionFavoriteArtistsEmptySubtitle => 'Toca el corazón en la página de un artista para mantenerlo aquí';

  @override
  String get collectionPlaylistEmptyTitle => 'Playlist esta vacia';

  @override
  String get collectionPlaylistEmptySubtitle => 'Presiona en + en las canciones para añadir a la playlist'; 

  @override
  String get collectionRemoveFromPlaylist => 'Remover de playlist';

  @override
  String get collectionRemoveFromFolder => 'Remover de carpeta';

  @override
  String collectionRemoved(String trackName) {
    return '\"$trackName\" removido';
  }

  @override
  String collectionAddedToLoved(String trackName) {
    return '\"$trackName\" añadido a LibraryCollectionsFavorites';
  }

  @override
  String collectionRemovedFromLoved(String trackName) {
    return '\"$trackName\" quitado de LibraryCollectionsFavorites';
  }

  @override
  String collectionAddedToWishlist(String trackName) {
    return '\"$trackName\" añadido a Wishlist';
  }

  @override
  String collectionRemovedFromWishlist(String trackName) {
    return '\"$trackName\" quitado de Wishlist';
  }

  @override
  String collectionAddedToFavoriteArtists(String artistName) {
    return '\"$artistName\" añadido a Artistas LibraryCollectionsFavorites';
  }

  @override
  String collectionRemovedFromFavoriteArtists(String artistName) {
    return '\"$artistName\" eliminado de Artistas LibraryCollectionsFavorites';
  }

  @override
  String get trackOptionAddToLoved => 'Añadir a LibraryCollectionsFavorites';

  @override
  String get trackOptionRemoveFromLoved => 'Quitar de LibraryCollectionsFavorites';

  @override
  String get trackOptionAddToWishlist => 'Añadir a Wishlist';

  @override
  String get trackOptionRemoveFromWishlist => 'Quitar de Wishlist';

  @override
  String get artistOptionAddToFavorites => 'Añadir a Artistas LibraryCollectionsFavorites';

  @override
  String get artistOptionRemoveFromFavorites => 'Eliminar de Artistas LibraryCollectionsFavorites';

  @override
  String get collectionPlaylistChangeCover => 'Cambiar imagen de portada';

  @override
  String get collectionPlaylistRemoveCover => 'Eliminar imagen de portada';

  @override
  String selectionShareCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'canciones',
      one: 'cancion',
    );
    return 'Compartir $count $_temp0';
  }

  @override
  String get selectionShareNoFiles => 'No se encontraron archivos compartibles';

  @override
  String selectionConvertCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'canciones',
      one: 'cancion',
    );
    return 'Convertir $count $_temp0';
  }

  @override
  String get selectionConvertNoConvertible => 'No se encontraron archivos convertibles';

  @override
  String get selectionBatchConvertConfirmTitle => ' Confirmar conversión por lotes';

  @override
  String selectionBatchConvertConfirmMessage(int count, String format, String bitrate) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'canciones',
      one: 'cancion',
    );
    return 'Convertir $count $_temp0 a $format en $bitrate?\n\nArchivos originales seran eliminados.';
  }

  @override
  String selectionBatchConvertConfirmMessageLossless(int count, String format) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'canciones',
      one: 'cancion',
    );
    return 'Convertir $count $_temp0 a $format? (Sin pérdida de calidad)\n\nLos archivos originales se eliminarán después de la conversión.';
  }

  @override
  String selectionBatchConvertProgress(int current, int total) {
    return 'Convertiendo $current de $total...';
  }

  @override
  String selectionBatchConvertSuccess(int success, int total, String format) {
    return 'Convertidas $success de $total canciones de $format';
  }

  @override
  String downloadedAlbumDownloadedCount(int count) {
    return '$count descargado';
  }

  @override
  String get downloadUseAlbumArtistForFoldersAlbumSubtitle => 'Las carpetas de artistas usan el artista del álbum cuando está disponible';

  @override
  String get downloadUseAlbumArtistForFoldersTrackSubtitle => 'Las carpetas de artistas usan solo el artista de la pista';

  @override
  String get lyricsProvidersTitle => 'Proveedores de letras';

  @override
  String get lyricsProvidersDescription => 'Habilita, deshabilita y reordena las fuentes de letras. Los proveedores se prueban de arriba a abajo hasta encontrar las letras.';

  @override
  String get lyricsProvidersInfoText => 'Los proveedores de letras de la extensión siempre se ejecutan antes que los proveedores integrados. Al menos un proveedor debe permanecer habilitado.';

  @override
  String lyricsProvidersEnabledSection(int count) {
    return 'Habilitado ($count)';
  }

  @override
  String lyricsProvidersDisabledSection(int count) {
    return 'Deshabilitado ($count)';
  }

  @override
  String get lyricsProvidersAtLeastOne => 'Debe permanecer habilitado al menos un proveedor';

  @override
  String get lyricsProvidersSaved => 'Prioridad del proveedor de letras guardada';

  @override
  String get lyricsProvidersDiscardContent => 'Tienes cambios sin guardar que se perderán';

  @override
  String get lyricsProviderLrclibDesc => 'Base de datos de letras sincronizadas de código abierto';

  @override
  String get lyricsProviderNeteaseDesc => 'NetEase Cloud Music (ideal para canciones asiáticas)';

  @override
  String get lyricsProviderMusixmatchDesc => 'La base de datos de letras más grande (multilingüe)';

  @override
  String get lyricsProviderAppleMusicDesc => 'Letras sincronizadas palabra por palabra (a través de proxy)';

  @override
  String get lyricsProviderQqMusicDesc => 'QQ Music (ideal para canciones chinas, vía proxy)';

  @override
  String get lyricsProviderExtensionDesc => 'Proveedor de extensiones';

  @override
  String get safMigrationTitle => 'Actualización de almacenamiento necesaria';

  @override
  String get safMigrationMessage1 => 'Bitly ahora usa el Marco de Acceso al Almacenamiento de Android (SAF) para las descargas. Esto corrige los errores de "permiso denegado" en Android 10 y versiones posteriores.';

  @override
  String get safMigrationMessage2 => 'Seleccione de nuevo su carpeta de descargas para cambiar al nuevo sistema de almacenamiento.';

  @override
  String get safMigrationSuccess => 'Carpeta de descargas actualizada al modo SAF';

  @override
  String get settingsDonate => 'Donar';

  @override

  String get settingsDonateSubtitle => 'Apoya el desarrollo de Bitly';

  @override
  String get tooltipLoveAll => 'Me gusta todo';

  @override
  String get tooltipAddToPlaylist => 'Añadir a la lista de reproducción';

  @override
  String snackbarRemovedTracksFromLoved(int count) {
    return 'Se eliminaron $count pistas de la lista de LibraryCollectionsFavorites';
  }

  @override
  String snackbarAddedTracksToLoved(int count) {
    return 'Se agregaron $count pistas a la lista de LibraryCollectionsFavorites';
  }

  @override
  String get dialogDownloadAllTitle => 'Descargar todo';

  @override
  String dialogDownloadAllMessage(int count) {
  return '¿Descargar $count pistas?';

  }

  @override
  String get homeSkipAlreadyDownloaded => 'Saltar las canciones ya descargadas';

  @override
  String get homeGoToAlbum => 'Ir al álbum';

  @override
  String get homeAlbumInfoUnavailable => 'Información del álbum no disponible';

  @override
  String get snackbarLoadingCueSheet => 'Cargando la hoja CUE...';

  @override
  String get snackbarMetadataSaved => 'Metadatos guardados correctamente';

  @override

  String get snackbarFailedToEmbedLyrics => 'Error al insertar la letra';

  @override
  String get snackbarFailedToWriteStorage => 'Error al guardar en el almacenamiento';

  @override
  String snackbarError(String error) {
  return 'Error: $error';

  }

  @override
  String get snackbarNoActionDefined => 'No se ha definido ninguna acción para este botón';

  @override
  String get noTracksFoundForAlbum => 'No se han encontrado pistas para este álbum';

  @override
  String get downloadLocationSubtitle => 'Seleccione el modo de almacenamiento para los archivos descargados.';

  @override
  String get storageModeAppFolder => 'Carpeta de la aplicación (no SAF)';

  @override
  String get storageModeAppFolderSubtitle => 'Usar la ruta predeterminada de Música/Bitly';

  @override

    String get storageModeSaf => 'Carpeta SAF';
  
  @override
  String get storageModeSafSubtitle => 'Selecciona la carpeta mediante el marco de acceso al almacenamiento de Android';

  @override
  String downloadFilenameDescription(Object album, Object artist, Object date, Object disc, Object title, Object track, Object year) {
    return 'Personaliza el nombre de tus archivos.';
  }

  @override
  String get downloadFilenameInsertTag => 'Toca para insertar la etiqueta:';

  @override
  String get downloadSeparateSinglesEnabled => 'Carpetas Albums/ y Singles/';

  @override
  String get downloadSeparateSinglesDisabled => 'Todos los archivos en la misma estructura';

  @override
  String get downloadArtistNameFilters => 'Filtros de nombre de artista';

  @override
  String get downloadCreatePlaylistSourceFolder => 'Crea la carpeta de origen de la lista de reproducción';

  @override
  String get downloadCreatePlaylistSourceFolderEnabled => 'Las descargas de listas de reproducción usan la carpeta Playlist/ además de la estructura de carpetas habitual.';

  @override
  String get downloadCreatePlaylistSourceFolderDisabled => 'Las descargas de listas de reproducción usan solo la estructura de carpetas habitual.';

  @override
  String get downloadCreatePlaylistSourceFolderRedundant => 'Playlist ya coloca las descargas dentro de una carpeta de lista de reproducción.';

  @override
  String get downloadSongLinkRegion => 'Región de SongLink';

  @override
  String get downloadNetworkCompatibilityMode => 'Modo de compatibilidad de red';

  @override
  String get downloadNetworkCompatibilityModeEnabled => 'Habilitado: intenta HTTP + acepta certificados TLS no válidos (inseguro)';

  @override
  String get downloadNetworkCompatibilityModeDisabled => 'Desactivado: validación estricta del certificado HTTPS (recomendado)';

  @override
  String get downloadSelectServiceToEnable => 'Seleccione un servicio integrado para habilitar';

  @override
  String get downloadSelectTidalQobuz => 'Seleccione Tidal o Qobuz arriba para configurar la calidad';

  @override
  String get downloadEmbedLyricsDisabled => 'Deshabilitado mientras la opción "Incrustar metadatos" esté desactivada';

  @override
  String get downloadNeteaseIncludeTranslation => 'Netease: Incluir traducción';

  @override
  String get downloadNeteaseIncludeTranslationEnabled => 'Añadir la letra traducida cuando esté disponible';

  @override
  String get downloadNeteaseIncludeTranslationDisabled => 'Usar solo la letra original';

  @override
  String get downloadNeteaseIncludeRomanization => 'Netease: Incluir romanización';

  @override

  String get downloadNeteaseIncludeRomanizationEnabled => 'Añadir letras romanizadas cuando estén disponibles';

  @override
  String get downloadNeteaseIncludeRomanizationDisabled => 'Deshabilitado';

  @override
  String get downloadAppleQqMultiPerson => 'Apple/QQ Multi-Person palabra por palabra';

  @override
  String get downloadAppleQqMultiPersonEnabled => 'Habilitar el hablante v1/v2 y las etiquetas [bg:]';

  @override
  String get downloadAppleQqMultiPersonDisabled => 'Formato simplificado palabra por palabra';

  @override
  String get downloadMusixmatchLanguage => 'Idioma de Musixmatch';

  @override
  String get downloadMusixmatchLanguageAuto => 'Automático (original)';

  @override

  String get downloadFilterContributing => 'Filtrar artistas contribuyentes en Artista del álbum';

  @override
  String get downloadFilterContributingEnabled => 'Album Artist metadata uses primary artist only';

  @override
  String get downloadFilterContributingDisabled => 'Keep full Album Artist metadata value';

  @override
  String get downloadProvidersNoneEnabled => 'None enabled';

  @override
  String get downloadMusixmatchLanguageCode => 'Language code';

  @override
  String get downloadMusixmatchLanguageHint => 'auto / en / es / ja';

  @override
  String get downloadMusixmatchLanguageDesc => 'Set preferred language code (example: en, es, ja). Leave empty for auto.';

  @override
  String get downloadMusixmatchAuto => 'Auto';

  @override
  String get downloadNetworkAnySubtitle => 'WiFi + Mobile Data';

  @override
  String get downloadNetworkWifiOnlySubtitle => 'Pause downloads on mobile data';

  @override
  String get downloadSongLinkRegionDesc => 'Used as userCountry for SongLink API lookup.';

  @override
  String get snackbarUnsupportedAudioFormat => 'Unsupported audio format';

  @override
  String get cacheRefresh => 'Refresh';

  @override
  String dialogDownloadPlaylistsMessage(int trackCount, int playlistCount) {
    String _temp0 = intl.Intl.pluralLogic(
      trackCount,
      locale: localeName,
      other: 'canciones',
      one: 'cancion',
    );
    String _temp1 = intl.Intl.pluralLogic(
      playlistCount,
      locale: localeName,
      other: 'playlists',
      one: 'playlist',
    );
    return 'Descarga $trackCount $_temp0 desde $playlistCount $_temp1?';
  }

  @override
  String bulkDownloadPlaylistsButton(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'playlists',
      one: 'playlist',
    );
    return 'Descarga $count $_temp0';
  }

  @override
  String get bulkDownloadSelectPlaylists => 'Selecciona una playlist para descargar';

  @override
  String get snackbarSelectedPlaylistsEmpty => 'Playlist seleccionada sin canciones';

  @override
  String playlistsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count playlists',
      one: '1 playlist',
    );
    return '$_temp0';
  }

  @override
  String get editMetadataAutoFill => 'Autocompletar desde metadatos en línea';

  @override
  String get editMetadataAutoFillDesc => 'Seleccione los campos que se completarán automáticamente desde los metadatos en línea';

  @override
  String get editMetadataAutoFillFetch => 'Obtener y completar';

  @override
  String get editMetadataAutoFillSearching => 'Buscando en línea...';

  @override
  String get editMetadataAutoFillNoResults => 'No se encontraron metadatos coincidentes en línea';

  @override
  String editMetadataAutoFillDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'fields',
      one: 'field',
    );
    return 'Completed $count $_temp0 from online metadata';
  }

  @override
  String get editMetadataAutoFillNoneSelected => 'Seleccione al menos un campo para autocompletar';

  @override
  String get editMetadataFieldTitle => 'Título';

  @override
  String get editMetadataFieldArtist => 'Artista';

  @override
  String get editMetadataFieldAlbum => 'Álbum';

  @override
  String get editMetadataFieldAlbumArtist => 'Artista del álbum';

  @override
  String get editMetadataFieldDate => 'Fecha';

  @override
  String get editMetadataFieldTrackNum => 'Número de pista';

  @override
  String get editMetadataFieldDiscNum => 'Número de disco';

  @override
  String get editMetadataFieldGenre => 'Género';

  @override
  String get editMetadataFieldIsrc => 'ISRC';

  @override
  String get editMetadataFieldLabel => 'Etiqueta';

  @override
  String get editMetadataFieldCopyright => 'Derechos de autor';

  @override
  String get editMetadataFieldCover => 'Portada';

  @override
  String get editMetadataSelectAll => 'Todos';

  @override
  String get editMetadataSelectEmpty => 'Solo vacío';

  @override
  String queueDownloadingCount(int count) {
    return 'Descargando ($count)';
  }

  @override
  String get queueDownloadedHeader => 'Descargado';

  @override
  String get queueFilteringIndicator => 'Filtrando...';

  @override
  String queueTrackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pistas',
      one: '1 pista',
    );
    return '$_temp0';
  }

  @override
  String queueAlbumCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count álbumes',
      one: '1 álbum',
    );
    return '$_temp0';
  }

  @override
  String get queueEmptyAlbums => 'No hay descargas de álbumes';

  @override
  String get queueEmptyAlbumsSubtitle => 'Descarga varias pistas de un álbum para verlas aquí';

  @override
  String get queueEmptySingles => 'No hay descargas individuales';

  @override
  String get queueEmptySinglesSubtitle => 'Aquí aparecerán las descargas de pistas individuales';

  @override
  String get queueEmptyHistory => 'Sin historial de descargas';

  @override
  String get queueEmptyHistorySubtitle => 'Aquí aparecerán las pistas descargadas';

  @override
  String get selectionAllPlaylistsSelected => 'Todas las listas de reproducción seleccionadas';

  @override
  String get selectionTapPlaylistsToSelect => 'Toca las listas de reproducción para seleccionar';

  @override
  String get selectionSelectPlaylistsToDelete => 'Selecciona las listas de reproducción para eliminar';

  @override
  String get audioAnalysisTitle => 'Análisis de calidad de audio';

  @override
  String get audioAnalysisDescription => 'Verificar la calidad sin pérdidas con análisis de espectro';

  @override
  String get audioAnalysisAnalyzing => 'Analizando audio...';

  @override
  String get audioAnalysisSampleRate => 'Frecuencia de muestreo';

  @override
  String get audioAnalysisBitDepth => 'Profundidad de bits';

  @override
  String get audioAnalysisChannels => 'Canales';

  @override
  String get audioAnalysisDuration => 'Duración';

  @override
  String get audioAnalysisNyquist => 'Nyquist';

  @override
  String get audioAnalysisFileSize => 'Tamaño';

  @override
  String get audioAnalysisDynamicRange => 'Rango dinámico';

  @override
  String get audioAnalysisPeak => 'Pico';

  @override
  String get audioAnalysisRms => 'RMS';

  @override
  String get audioAnalysisSamples => 'Muestras';

  @override
  String extensionsSearchWith(String providerName) {
    return 'Buscar con $providerName';
  }

  @override
  String get extensionsHomeFeedProvider => 'Proveedor de la fuente de inicio';

  @override
  String get extensionsHomeFeedDescription => 'Elige qué extensión proporciona la fuente de inicio en la pantalla principal';

  @override
  String get extensionsHomeFeedAuto => 'Automático';

  @override
  String get extensionsHomeFeedAutoSubtitle => 'Automatically select the best available';
  
  @override
  String get extensionsHomeFeedOff => 'Desactivado';

  @override
  String get extensionsHomeFeedOffSubtitle => 'No mostrar el feed en la pantalla principal';
  
  @override
  String extensionsHomeFeedUse(String extensionName) {
    return 'Usar la fuente de inicio $extensionName';
  }

  @override
  String get extensionsNoHomeFeedExtensions => 'No hay extensiones con fuente de inicio';

  @override
  String get sortAlphaAsc => 'A-Z';

  @override
  String get sortAlphaDesc => 'Z-A';

  @override
  String get cancelDownloadTitle => '¿Cancelar descarga?';

  @override
  String cancelDownloadContent(String trackName) {
    return 'Esto cancelará la descarga activa de "$trackName"';
  }

  @override
  String get cancelDownloadKeep => 'Mantener';

  @override
  String get metadataSaveFailedFfmpeg => 'Error al guardar los metadatos con FFmpeg';

  @override

  String get metadataSaveFailedStorage => 'Error al guardar los metadatos en el almacenamiento';

  @override
  String snackbarFolderPickerFailed(String error) {
    return 'Error al abrir el selector de carpetas: $error';
  }

  @override
  String get errorLoadAlbum => 'Error al cargar el álbum';

  @override
  String get errorLoadPlaylist => 'Error al cargar la lista de reproducción';

  @override
  String get errorLoadArtist => 'Error al cargar el artista';

  @override
  String get notifChannelDownloadName => 'Progreso de la descarga';

  @override
  String get notifChannelDownloadDesc => 'Muestra el progreso de la descarga de las pistas';

  @override
  String get notifChannelLibraryScanName => 'Análisis de la biblioteca';

  @override
  String get notifChannelLibraryScanDesc => 'Muestra el progreso del escaneo de la biblioteca local';

  @override
  String notifDownloadingTrack(String trackName) {
    return 'Descargando $trackName';
  }

  @override
  String notifFinalizingTrack(String trackName) {
    return 'Finalizando $trackName';
  }

  @override
  String get notifEmbeddingMetadata => 'Incrustando metadatos...';

  @override
  String notifAlreadyInLibraryCount(int completed, int total) {
    return 'Ya en la biblioteca ($completed/$total)';
  }

  @override
  String get notifAlreadyInLibrary => 'Ya en la biblioteca';

  @override

  String notifDownloadCompleteCount(int completed, int total) {
    return 'Descarga completada ($completed/$total)';
  }

  @override
  String get notifDownloadComplete => 'Descarga completada';

  @override
  String notifDownloadsFinished(int completed, int failed) {
    return 'Descargas finalizadas ($completed done, $failed failed)';
  }

  @override
  String get notifAllDownloadsComplete => 'Todas las descargas completadas';

  @override
  String notifTracksDownloadedSuccess(int count) {
    return '$count pistas descargadas correctamente';
  }

  @override
  String notifDownloadsFinishedBody(int completed, int failed) {
    String _temp0 = intl.Intl.pluralLogic(
      completed,
      locale: localeName,
      other: '$completed pistas descargadas',
      one: '1 pista descargada',
    );
    String _temp1 = intl.Intl.pluralLogic(
      failed,
      locale: localeName,
      other: '$failed fallidas',
      one: '1 fallida',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String get notifDownloadsCanceledTitle => 'Descargas canceladas';

  @override
  String notifDownloadsCanceledBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count descargas canceladas por el usuario',
      one: '1 descarga cancelada por el usuario',
    );
    return '$_temp0';
  }

  @override
  String get notifScanningLibrary => 'Escaneando la biblioteca local';

  @override
  String notifLibraryScanProgressWithTotal(int scanned, int total, int percentage) {
    return '$scanned/$total archivos • $percentage%';
  }

  @override
  String notifLibraryScanProgressNoTotal(int scanned, int percentage) {
    return '$scanned archivos escaneados • $percentage%';
  }

  @override
  String get notifLibraryScanComplete => 'Escaneo de la biblioteca completado';

  @override
  String notifLibraryScanCompleteBody(int count) {
    return '$count pistas indexadas';
  }

  @override
  String notifLibraryScanExcluded(int count) {
    return '$count excluded';
  }

  @override
  String notifLibraryScanErrors(int count) {
    return '$count errores';
  }

  @override
  String get notifLibraryScanFailed => 'Error al escanear la biblioteca';

  @override
  String get notifLibraryScanCancelled => 'Escaneo de la biblioteca cancelado';

  @override
  String get notifLibraryScanStopped => 'Escaneo detenido antes de completarse.';

  @override
  String notifDownloadingUpdate(String version) {
    return 'Descargando Bitly v$version';
  }

  @override
  String notifUpdateProgress(String received, String total, int percentage) {
    return '$received / $total MB • $percentage%';
  }

  @override
  String get notifUpdateReady => 'Actualización lista';

  @override
  String notifUpdateReadyBody(String version) {
    return 'Bitly v$version descargado. Toca para instalar.';
  }

  @override
  String get notifUpdateFailed => 'Error al actualizar';

  @override
  String get notifUpdateFailedBody => 'No se pudo descargar la actualización. Inténtalo de nuevo más tarde.';

  @override
  String get searchTracks => 'Pistas';

  @override
  String get homeSearchHintDefault => 'Pega una URL compatible o busca...';

  @override
  String homeSearchHintProvider(String providerName) {
    return 'Buscar con $providerName...';
  }

  @override
  String get homeImportCsvTooltip => 'Importar CSV';

  @override
  String get homeChangeSearchProviderTooltip => 'Cambiar proveedor de búsqueda';

  @override
  String get actionPaste => 'Pegar';

  @override
  String get searchTracksHint => 'Buscar pistas...';

  @override
  String get searchTracksEmptyPrompt => 'Buscar pistas';

  @override
  String get tutorialSearchHint => 'Pega o busca...';

  @override
  String get tutorialDownloadCompletedSemantics => 'Descarga completada';

  @override
  String get tutorialDownloadInProgressSemantics => 'Descarga en curso';

  @override
  String get tutorialStartDownloadSemantics => 'Iniciar descarga';

  @override
  String get optionsEmbedMetadata => 'Incrustar Metadatos';

  @override
  String get optionsEmbedMetadataSubtitleOn => 'Escribir metadatos, carátula y letras en los archivos';

  @override
  String get optionsEmbedMetadataSubtitleOff => 'Desactivado (avanzado): saltar toda la incrustación de metadatos';

  @override
  String get optionsMaxQualityCoverSubtitleDisabled => 'Desactivado cuando la incrustación de metadatos está apagada';

  @override
  String downloadFilenameHintExample(Object artist, Object title) {
    return '$artist - $title';
  }

  @override
  String get trackCoverNoEmbeddedArt => 'No se encontró carátula incrustada';

  @override
  String get trackCoverReplace => 'Reemplazar Carátula';

  @override
  String get trackCoverPick => 'Elegir Carátula';

  @override
  String get trackCoverClearSelected => 'Limpiar carátula seleccionada';

  @override
  String get trackCoverCurrent => 'Carátula actual';

  @override
  String get trackCoverSelected => 'Carátula seleccionada';

  @override
  String get trackCoverReplaceNotice => 'La carátula seleccionada reemplazará la actual cuando toques Guardar.';

  @override
  String get actionStop => 'Detener';

  @override
  String get queueFinalizingDownload => 'Finalizando descarga';

  @override
  String get queueDownloadedFileMissing => 'Archivo descargado no encontrado';

  @override
  String get queueDownloadCompleted => 'Descarga completada';

  @override
  String appearanceSelectAccentColor(String hex) {
    return 'Seleccionar color de acento $hex';
  }

  @override
  String get logAutoScrollOn => 'Desplazamiento auto. ACTIVADO';

  @override
  String get logAutoScrollOff => 'Desplazamiento auto. DESACTIVADO';

  @override
  String get logCopyLogs => 'Copiar registros';

  @override
  String get logClearSearch => 'Limpiar búsqueda';

  @override
  String get logIssueIspBlockingLabel => 'BLOQUEO DEL ISP DETECTADO';

  @override
  String get logIssueIspBlockingDescription => 'Tu ISP puede estar bloqueando el acceso a los servicios de descarga';

  @override
  String get logIssueIspBlockingSuggestion => 'Prueba usando una VPN o cambia el DNS a 1.1.1.1 o 8.8.8.8';

  @override
  String get logIssueRateLimitedLabel => 'LÍMITE EXCEDIDO';

  @override
  String get logIssueRateLimitedDescription => 'Demasiadas solicitudes al servicio';

  @override
  String get logIssueRateLimitedSuggestion => 'Espera unos minutos antes de intentar de nuevo';

  @override
  String get logIssueNetworkErrorLabel => 'ERROR DE RED';

  @override
  String get logIssueNetworkErrorDescription => 'Se detectaron problemas de conexión';

  @override
  String get logIssueNetworkErrorSuggestion => 'Verifica tu conexión a internet';

  @override
  String get logIssueTrackNotFoundLabel => 'PISTA NO ENCONTRADA';

  @override
  String get logIssueTrackNotFoundDescription => 'Algunas pistas no se encontraron en los servicios de descarga';

  @override
  String get logIssueTrackNotFoundSuggestion => 'La pista puede no estar disponible en calidad lossless';

  @override
  String get clickableLookingUpArtist => 'Buscando artista...';

  @override
  String clickableInformationUnavailable(String type) {
    return 'Información de $type no disponible';
  }

  @override
  String get extensionDetailsTags => 'Etiquetas';

  @override
  String get extensionDetailsInformation => 'Información';

  @override
  String get extensionUtilityFunctions => 'Funciones de Utilidad';

  @override
  String get actionDismiss => 'Descartar';

  @override
  String get setupChangeFolderTooltip => 'Cambiar carpeta';

  @override
  String a11yOpenTrackByArtist(String trackName, String artistName) {
    return 'Abrir pista $trackName de $artistName';
  }

  @override
  String a11yOpenItem(String itemType, String name) {
    return 'Abrir $itemType $name';
  }

  @override
  String a11yOpenItemCount(String title, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'elementos',
      one: 'elemento',
    );
    return 'Abrir $title, $count $_temp0';
  }

  @override
  String a11yOpenAlbumByArtistTrackCount(String albumName, String artistName, int trackCount) {
    return 'Abrir álbum $albumName de $artistName, $trackCount pistas';
  }

  @override
  String a11yTrackByArtist(String trackName, String artistName) {
    return '$trackName de $artistName';
  }

  @override
  String a11ySelectAlbum(String albumName) {
    return 'Seleccionar álbum $albumName';
  }

  @override
  String a11yOpenAlbum(String albumName) {
    return 'Abrir álbum $albumName';
  }

  @override
  String get optionsDefaultSearchTabAlbums => 'Álbumes';

  @override
  String get optionsDefaultSearchTabTracks => 'Canciones';

  @override
  String get settingsFiles => 'Archivos y carpetas';

  @override
  String get settingsFilesSubtitle => 'Ubicación de descarga, nombre de archivo, estructura de carpetas';

  @override
  String get settingsMetadata => 'Metadatos';

  @override
  String get settingsMetadataSubtitle => 'Portada, etiquetas, ReplayGain, proveedores';

  @override
  String get settingsLyrics => 'Letras';

  @override
  String get settingsLyricsSubtitle => 'Insertar, modo, proveedores, opciones de idioma';

  @override
  String get settingsApp => 'Aplicación';

  @override
  String get settingsAppSubtitle => 'Actualizaciones, datos, repositorio de extensiones, depuración';

  @override
  String get sectionMetadataProviders => 'Proveedores';

  @override
  String get sectionDuplicates => 'Duplicados';

  @override
  String get sectionLyricsProviderOptions => 'Opciones del proveedor';

  @override
  String get metadataProvidersTitle => 'Prioridad del proveedor de metadatos';

  @override
  String get metadataProvidersSubtitle => 'Arrastra para establecer el orden de búsqueda y de la fuente de metadatos';

  @override
  String get downloadDeduplication => 'Omitir descargas duplicadas';

  @override
  String get downloadDeduplicationEnabled => 'Se omitirán las pistas ya descargadas';

  @override
  String get downloadDeduplicationDisabled => 'Se descargarán todas las pistas independientemente del historial';

  @override
  String get downloadFallbackExtensions => 'Extensiones de reserva';

  @override
  String get downloadFallbackExtensionsSubtitle => 'Elige qué extensiones se pueden usar como reserva';
}