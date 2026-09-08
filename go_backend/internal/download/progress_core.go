package download

import (
	"encoding/json"
)

type Status int

const (
	StatusQueued Status = iota
	StatusDownloading
	StatusProcessing
	StatusCompleted
	StatusFailed
	StatusCancelled
)

func (s Status) String() string {
	switch s {
	case StatusQueued:
		return "queued"
	case StatusDownloading:
		return "downloading"
	case StatusProcessing:
		return "processing"
	case StatusCompleted:
		return "completed"
	case StatusFailed:
		return "failed"
	case StatusCancelled:
		return "cancelled"
	default:
		return "unknown"
	}
}

// MarshalJSON serializes the status as its stable string form (e.g.
// "downloading") instead of the raw integer enum value. The Flutter
// DownloadCubit polling contract compares status against strings
// ('completed', 'downloading', 'failed', 'cancelled', ...), so sending the
// int here made every poll throw a cast error on the client and the dot
// stayed orange forever even when the download had finished.
func (s Status) MarshalJSON() ([]byte, error) {
	return json.Marshal(s.String())
}

// Progress holds download progress for a single item.
type Progress struct {
	ItemID     string  `json:"itemId"`
	Title      string  `json:"title"`
	TrackName  string  `json:"track_name,omitempty"`
	ArtistName string  `json:"artist_name,omitempty"`
	Status     Status  `json:"status"`
	Progress   float64 `json:"progress"` // 0.0 to 1.0
	BytesDone  int64   `json:"bytesDone"`
	BytesTotal int64   `json:"bytesTotal"`
	Error      string  `json:"error,omitempty"`
	Provider   string  `json:"provider"`
	OutputPath string  `json:"outputPath,omitempty"`
	// Encrypted marca un archivo de salida que es un stream DRM/encriptado
	// (aun no reproducible). ClientDecrypt es true cuando el backend no pudo
	// descifrarlo aqui (sin CLI ffmpeg, p. ej. Android) asi que el cliente
	// debe descifrarlo (ffmpeg-kit) antes de reproducir; DecryptionKey /
	// OutputExtension llevan la clave y la extension del contenedor del
	// output descifrado; InputFormat es el contenedor encriptado de origen
	// (p. ej. "mov") para el paso de descifrado.
	Encrypted       bool   `json:"encrypted,omitempty"`
	ClientDecrypt   bool   `json:"clientDecrypt,omitempty"`
	DecryptionKey   string `json:"decryptionKey,omitempty"`
	OutputExtension string `json:"outputExtension,omitempty"`
	InputFormat     string `json:"inputFormat,omitempty"`
}

// Tracker maintains progress of all active downloads.
