package providers

import (
	"github.com/zarz/bitly/go_backend_bitly/internal/sources/core"

	_ "github.com/zarz/bitly/go_backend_bitly/internal/sources/providers/deezer"
	_ "github.com/zarz/bitly/go_backend_bitly/internal/sources/providers/qobuz"
	_ "github.com/zarz/bitly/go_backend_bitly/internal/sources/providers/spotify"
	_ "github.com/zarz/bitly/go_backend_bitly/internal/sources/providers/tidal"
)

func RegisterAllBuiltin(registry *core.ProviderRegistry) {
	registry.RegisterSearchProvider("deezer", &deezerSearchAdapter{})
	registry.RegisterSearchProvider("tidal", &tidalSearchAdapter{})
	registry.RegisterSearchProvider("qobuz", &qobuzSearchAdapter{})

	registry.RegisterMetadataProvider("deezer", &deezerMetadataAdapter{})
	registry.RegisterMetadataProvider("tidal", &tidalMetadataAdapter{})
	registry.RegisterMetadataProvider("qobuz", &qobuzMetadataAdapter{})

	registry.RegisterDownloadProvider("deezer", &deezerDownloadAdapter{})
	registry.RegisterDownloadProvider("tidal", &tidalDownloadAdapter{})
	registry.RegisterDownloadProvider("qobuz", &qobuzDownloadAdapter{})
}
