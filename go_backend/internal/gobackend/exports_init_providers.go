package gobackend

import (
	"log"

	"github.com/zarz/bitly/go_backend/internal/bundled_extensions"
	"github.com/zarz/bitly/go_backend/internal/extensions"
	"github.com/zarz/bitly/go_backend/internal/provider"
	"github.com/zarz/bitly/go_backend/internal/provider/apple"
	"github.com/zarz/bitly/go_backend/internal/provider/deezer"
	"github.com/zarz/bitly/go_backend/internal/provider/musicbrainz"
	"github.com/zarz/bitly/go_backend/internal/provider/qobuz"
	"github.com/zarz/bitly/go_backend/internal/provider/soundcloud"
	"github.com/zarz/bitly/go_backend/internal/provider/spotify"
	"github.com/zarz/bitly/go_backend/internal/provider/tidal"
	"github.com/zarz/bitly/go_backend/internal/provider/youtube"
)

// initProviders registers extension-based providers FIRST (may be overwritten
// by native below). Best-effort registry: never nil even if the dir is
// unwritable, so the embedded (-web) extensions always load on every device
// (Android included). Native providers are registered AFTER extensions, and
// any native superseded by a bundled extension is skipped (the source picker
// would otherwise show duplicates, e.g. qobuz AND qobuz-web).
func inicializarProviders(reg *provider.Registry) []bundled_extensions.RegisteredExtension {
	extRegistry = extensions.NewRegistryBestEffort(dirExtensiones())
	// Actualización SILENCIOSA de extensiones: el registro empaquetado es la
	// fuente de verdad. Si una extensión instalada en disco quedó vieja (p.ej.
	// de una versión anterior de la app que no reescribió el archivo), se
	// reescribe acá sola, sin molestar al usuario. Best-effort: nunca rompe el
	// arranque.
	if actualizadas := bundled_extensions.SincronizarConDisco(dirExtensiones()); len(actualizadas) > 0 {
		log.Printf("[extensions] %d extensiones actualizadas en disco: %v",
			len(actualizadas), actualizadas)
	}
	bundledExts = bundled_extensions.LoadAllToRegistry(extRegistry)
	// Names of built-in providers superseded by a bundled extension. We must
	// not register those natives, otherwise the source picker shows duplicates
	// (e.g. qobuz AND qobuz-web, spotify AND spotify-web).
	replacedByExt := map[string]bool{}
	for _, ext := range bundledExts {
		if ext.Enabled {
			ep := provider.NewExtensionProvider(ext.ID, ext.ID, extRegistry.Runtime())
			ep.SetHomeFeedEnabled(ext.HasHomeFeed)
			ep.SetQualityOptions(ext.QualityOptions)
			ep.SetDownloadCapable(ext.IsDownloadProvider)
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
		apple.NewClient(nil, "", "us"),
		soundcloud.NewClient(nil, ""),
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
