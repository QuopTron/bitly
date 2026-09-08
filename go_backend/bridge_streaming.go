// Bridge de export para gomobile — streaming.
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

// ClearStreamCache re-exportado desde internal/gobackend.
func ClearStreamCache() string {
	return gobackend.ClearStreamCache()
}

// FetchLyrics re-exportado desde internal/gobackend.
func FetchLyrics(payload string) string {
	return gobackend.FetchLyrics(payload)
}

// GetLibraryStats re-exportado desde internal/gobackend.
func GetLibraryStats() string {
	return gobackend.GetLibraryStats()
}

// GetLyricsLRCWithSource re-exportado desde internal/gobackend.
func GetLyricsLRCWithSource(payload string) string {
	return gobackend.GetLyricsLRCWithSource(payload)
}

// GetNowPlaying re-exportado desde internal/gobackend.
func GetNowPlaying() string {
	return gobackend.GetNowPlaying()
}

// GetPlaybackStats re-exportado desde internal/gobackend.
func GetPlaybackStats() string {
	return gobackend.GetPlaybackStats()
}

// GetStreamCacheStats re-exportado desde internal/gobackend.
func GetStreamCacheStats() string {
	return gobackend.GetStreamCacheStats()
}

// GetStreamPackage re-exportado desde internal/gobackend.
func GetStreamPackage(payload string) string {
	return gobackend.GetStreamPackage(payload)
}

// GetStreamURL re-exportado desde internal/gobackend.
func GetStreamURL(payload string) string {
	return gobackend.GetStreamURL(payload)
}

// MarkPlayed re-exportado desde internal/gobackend.
func MarkPlayed(payload string) string {
	return gobackend.MarkPlayed(payload)
}

// ReportNowPlaying re-exportado desde internal/gobackend.
func ReportNowPlaying(trackJSON string) string {
	return gobackend.ReportNowPlaying(trackJSON)
}

// ScanLibrary re-exportado desde internal/gobackend.
func ScanLibrary(directory string) string {
	return gobackend.ScanLibrary(directory)
}

// SetGeniusToken re-exportado desde internal/gobackend.
func SetGeniusToken(token string) string {
	return gobackend.SetGeniusToken(token)
}

// StartStreamingServer re-exportado desde internal/gobackend.
func StartStreamingServer(port int) string {
	return gobackend.StartStreamingServer(port)
}

// StopStreamingServer re-exportado desde internal/gobackend.
func StopStreamingServer() string {
	return gobackend.StopStreamingServer()
}

// StreamAudioChunk re-exportado desde internal/gobackend.
func StreamAudioChunk(payload string) string {
	return gobackend.StreamAudioChunk(payload)
}
