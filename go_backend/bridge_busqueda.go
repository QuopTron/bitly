// Bridge de export para gomobile — busqueda.
//
// gomobile bind no puede bindear paquetes bajo internal/ (el gobind
// generado vive en un modulo temporal 'gobind' fuera del arbol del
// modulo, y Go prohibe importar internal/ desde afuera). Antes de la
// reorganizacion este paquete vivia en la raiz; ahora la raiz solo
// re-exporta internal/gobackend para que el CI de Android/iOS siga
// generando el AAR/xcframework con la misma API (gobackend.Gobackend).
// No editar a mano los wrappers generados.

package gobackend

import gobackend "github.com/zarz/bitly/go_backend/internal/gobackend"

// EnrichMetadata re-exportado desde internal/gobackend.
func EnrichMetadata(isrc string) string {
	return gobackend.EnrichMetadata(isrc)
}

// FetchAlbumDetail re-exportado desde internal/gobackend.
func FetchAlbumDetail(payload string) string {
	return gobackend.FetchAlbumDetail(payload)
}

// FetchArtistDetail re-exportado desde internal/gobackend.
func FetchArtistDetail(payload string) string {
	return gobackend.FetchArtistDetail(payload)
}

// FetchPlaylistDetail re-exportado desde internal/gobackend.
func FetchPlaylistDetail(payload string) string {
	return gobackend.FetchPlaylistDetail(payload)
}

// GetAlbum re-exportado desde internal/gobackend.
func GetAlbum(payload string) string {
	return gobackend.GetAlbum(payload)
}

// GetArtist re-exportado desde internal/gobackend.
func GetArtist(payload string) string {
	return gobackend.GetArtist(payload)
}

// GetHomeFeed re-exportado desde internal/gobackend.
func GetHomeFeed(_locale string) string {
	return gobackend.GetHomeFeed(_locale)
}

// GetProviderHealthStatus re-exportado desde internal/gobackend.
func GetProviderHealthStatus() string {
	return gobackend.GetProviderHealthStatus()
}

// GetRecommendationsFromHistory re-exportado desde internal/gobackend.
func GetRecommendationsFromHistory(limit int) string {
	return gobackend.GetRecommendationsFromHistory(limit)
}

// GetSearchConfig re-exportado desde internal/gobackend.
func GetSearchConfig() string {
	return gobackend.GetSearchConfig()
}

// GetSearchStreamResults re-exportado desde internal/gobackend.
func GetSearchStreamResults() string {
	return gobackend.GetSearchStreamResults()
}

// GetSimilarArtists re-exportado desde internal/gobackend.
func GetSimilarArtists(payload string) string {
	return gobackend.GetSimilarArtists(payload)
}

// GetSimilarTracks re-exportado desde internal/gobackend.
func GetSimilarTracks(payload string) string {
	return gobackend.GetSimilarTracks(payload)
}

// GetSources re-exportado desde internal/gobackend.
func GetSources() string {
	return gobackend.GetSources()
}

// GetTopTracks re-exportado desde internal/gobackend.
func GetTopTracks(limit int) string {
	return gobackend.GetTopTracks(limit)
}

// GetTrack re-exportado desde internal/gobackend.
func GetTrack(payload string) string {
	return gobackend.GetTrack(payload)
}

// ResolveISRC re-exportado desde internal/gobackend.
func ResolveISRC(isrc string) string {
	return gobackend.ResolveISRC(isrc)
}

// Search re-exportado desde internal/gobackend.
func Search(payload string) string {
	return gobackend.Search(payload)
}

// SearchAlbums re-exportado desde internal/gobackend.
func SearchAlbums(query string) string {
	return gobackend.SearchAlbums(query)
}

// SearchArtists re-exportado desde internal/gobackend.
func SearchArtists(query string) string {
	return gobackend.SearchArtists(query)
}

// SearchPlaylists re-exportado desde internal/gobackend.
func SearchPlaylists(query string) string {
	return gobackend.SearchPlaylists(query)
}

// SearchStream re-exportado desde internal/gobackend.
func SearchStream(payload string) string {
	return gobackend.SearchStream(payload)
}

// SearchTracks re-exportado desde internal/gobackend.
func SearchTracks(query string) string {
	return gobackend.SearchTracks(query)
}
