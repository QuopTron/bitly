package gobackend

import (
	"log"

	"github.com/zarz/bitly/go_backend/internal/bundled_extensions"
	"github.com/zarz/bitly/go_backend/internal/extensions"
	"github.com/zarz/bitly/go_backend/internal/provider"
	"github.com/zarz/bitly/go_backend/internal/provider/apple"
	"github.com/zarz/bitly/go_backend/internal/provider/deezer"
	"github.com/zarz/bitly/go_backend/internal/provider/flacrescue"
	"github.com/zarz/bitly/go_backend/internal/provider/internetarchive"
	"github.com/zarz/bitly/go_backend/internal/provider/lastfm"
	"github.com/zarz/bitly/go_backend/internal/provider/musicbrainz"
	"github.com/zarz/bitly/go_backend/internal/provider/qobuz"
	"github.com/zarz/bitly/go_backend/internal/provider/redacted"
	"github.com/zarz/bitly/go_backend/internal/provider/soulseek"
	"github.com/zarz/bitly/go_backend/internal/provider/soundcloud"
	"github.com/zarz/bitly/go_backend/internal/provider/spotify"
	"github.com/zarz/bitly/go_backend/internal/provider/tidal"
	"github.com/zarz/bitly/go_backend/internal/provider/tidalhifi"
	"github.com/zarz/bitly/go_backend/internal/provider/youtube"
)

// initProviders registers extension-based providers FIRST (may be overwritten
// by native below). Best-effort registry: never nil even if the dir is
// unwritable, so the embedded (-web) extensions always load on every device
// (Android included). Native providers are registered AFTER extensions, and
// any native superseded by a bundled extension is skipped (the source picker
// would otherwise show duplicates, e.g. qobuz AND qobuz-web).
func inicializarProviders(reg *provider.Registry) []bundled_extensions.RegisteredExtension {
	setExtRegistry(extensions.NewRegistryBestEffort(dirExtensiones()))
	// Actualización SILENCIOSA de extensiones: el registro empaquetado es la
	// fuente de verdad. Si una extensión instalada en disco quedó vieja (p.ej.
	// de una versión anterior de la app que no reescribió el archivo), se
	// reescribe acá sola, sin molestar al usuario. Best-effort: nunca rompe el
	// arranque.
	if actualizadas := bundled_extensions.SincronizarConDisco(dirExtensiones()); len(actualizadas) > 0 {
		log.Printf("[extensions] %d extensiones actualizadas en disco: %v",
			len(actualizadas), actualizadas)
	}
	erInicial := getExtRegistry()
	bundledExts = bundled_extensions.LoadAllToRegistry(erInicial)
	// Names of built-in providers superseded by a bundled extension. We must
	// not register those natives, otherwise the source picker shows duplicates
	// (e.g. qobuz AND qobuz-web, spotify AND spotify-web).
	replacedByExt := map[string]bool{}
	for _, ext := range bundledExts {
		if ext.Enabled {
			ep := provider.NewExtensionProvider(ext.ID, ext.ID, erInicial.Runtime())
			ep.SetHomeFeedEnabled(ext.HasHomeFeed)
			ep.SetQualityOptions(ext.QualityOptions)
			ep.SetDownloadCapable(ext.IsDownloadProvider)
			// Los patrones de urlHandler dicen qué enlaces (Spotify, YouTube,
			// Deezer...) sabe resolver esta extensión con su handleUrl.
			ep.SetURLPatterns(ext.URLHandler.Patterns)
			reg.Register(ep)
			for _, rp := range ext.Replaces {
				// Keep the native 'spotify' provider registered alongside the
				// 'spotify-web' extension (it exposes a different search/feed
				// surface), so both appear as separate sources.
				if rp == "spotify" {
					continue
				}
				replacedByExt[rp] = true
			}
		}
	}

	// Registra native proveedores AFTER extensions.
	// Some extensions (deezer, soundcloud) have getHomeFeed + download,
	// so we skip their native versions to avoid overwriting.
	nativeRegister := []provider.Provider{
		deezer.NewClient(nil),
		qobuz.NewClient(nil, ""),
		tidal.NewClient(nil, "", ""),
		spotify.NewClient(nil, "", ""),
		youtube.NewClient(ytdlpPath),
		musicbrainz.NewClient(nil, ""),
		// Last.fm: SOLO identidad y el video OFICIAL de YouTube de cada pista
		// (no entrega audio ni ISRC). No aparece en la búsqueda: lo usan la
		// identidad entre extensiones y el rescate cuando todas las fuentes
		// fallaron, con caché de 12 h y 1 petición cada 3 s para no ganarse
		// el desafío anti-bot del sitio.
		lastfm.NewClient(nil),
		apple.NewClient(nil, "", "us"),
		soundcloud.NewClient(nil, ""),
		flacrescue.NewClient(),
		// Tidal HiFi anónimo: catálogo Tidal con ISRC y el audio sin pérdida
		// REAL (FLAC 44,1 kHz) sin cuenta y sin captcha. Es un descargador
		// propio (el audio llega en segmentos DASH que el canal arma solo).
		tidalhifi.NewClient(),
		// Internet Archive: catálogo abierto con FLAC real, sin API key ni
		// cuenta. Es la única fuente lossless que no depende de sesión ni de
		// un gateway firmado.
		internetarchive.NewClient(nil),
		// REDacted: FLAC lossless vía torrent (~3M torrents). Solo se activa
		// si el usuario pone sus credenciales en ajustes. El stream URL
		// devuelto es un magnet link que libtorrent_flutter resuelve.
		redacted.NewClient("", ""),
		// Soulseek: catálogo comercial en FLAC al que se entra SIN invitación,
		// SIN pago y sin dar datos personales (el alta es del lado del
		// cliente: nombre + contraseña). Queda inerte hasta que haya
		// credenciales EN AJUSTES, así el arranque nunca depende de la red.
		soulseek.NewClient("", ""),
	}
	for _, np := range nativeRegister {
		if replacedByExt[np.Name()] {
			continue
		}
		if reg.Get(np.Name()) == nil {
			reg.Register(np)
		}
		// Si existe una extension con el mismo nombre, se mantiene la extension (tiene gethomefeed + descarga)
	}
	return bundledExts
}
