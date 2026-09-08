// Bridge de export para gomobile — media.
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

// ConvertFile re-exportado desde internal/gobackend.
func ConvertFile(requestJSON string) string {
	return gobackend.ConvertFile(requestJSON)
}

// CoversDir re-exportado desde internal/gobackend.
func CoversDir() string {
	return gobackend.CoversDir()
}

// DeleteCover re-exportado desde internal/gobackend.
func DeleteCover(payload string) string {
	return gobackend.DeleteCover(payload)
}

// EmbedCover re-exportado desde internal/gobackend.
func EmbedCover(payload string) string {
	return gobackend.EmbedCover(payload)
}

// ExportPlaylistXSPF re-exportado desde internal/gobackend.
func ExportPlaylistXSPF(payload string) string {
	return gobackend.ExportPlaylistXSPF(payload)
}

// GetCoverPathForTrack re-exportado desde internal/gobackend.
func GetCoverPathForTrack(payload string) string {
	return gobackend.GetCoverPathForTrack(payload)
}

// LikeItem re-exportado desde internal/gobackend.
func LikeItem(payload string) string {
	return gobackend.LikeItem(payload)
}

// ParseCUE re-exportado desde internal/gobackend.
func ParseCUE(cueContent string) string {
	return gobackend.ParseCUE(cueContent)
}

// ParsePlaylistXSPF re-exportado desde internal/gobackend.
func ParsePlaylistXSPF(xspfContent string) string {
	return gobackend.ParsePlaylistXSPF(xspfContent)
}

// ReadFileMetadata re-exportado desde internal/gobackend.
func ReadFileMetadata(filePath string) string {
	return gobackend.ReadFileMetadata(filePath)
}

// ResolveVisualizerUrl re-exportado desde internal/gobackend.
func ResolveVisualizerUrl(payload string) string {
	return gobackend.ResolveVisualizerUrl(payload)
}

// SaveCover re-exportado desde internal/gobackend.
func SaveCover(payload string) string {
	return gobackend.SaveCover(payload)
}

// WriteFileMetadata re-exportado desde internal/gobackend.
func WriteFileMetadata(payload string) string {
	return gobackend.WriteFileMetadata(payload)
}
