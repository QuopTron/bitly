package streaming

import (
	"net/http"
	"strings"

	"github.com/zarz/bitly/go_backend/internal/httpclient"
)

type Streamer struct {
	client *http.Client
	cache  *Cache
	server *http.Server
	// trozoFijo fuerza el tamaño de cada petición de rango (0 = automático
	// según el host). Existe para que las pruebas puedan usar trozos chicos
	// y verificar que el audio llega byte a byte, sin huecos ni duplicados.
	trozoFijo int64
}

// NewStreamer creates an audio streamer.
//
// El cliente es el de MEDIA (httpclient.NewMediaClient): sin timeout global
// —un tema largo no puede morir a los 30 s— y con muchas conexiones ociosas
// por host, que es lo que evita reabrir TLS en cada trozo y se percibe como
// cortes en la reproducción.
func NewStreamer() *Streamer {
	return &Streamer{
		client: httpclient.NewMediaClient(),
		cache:  NewCache(),
	}
}

// streamChunkSize es el tamaño de cada petición de rango para YouTube.
// YouTube bot-gates some egress IPs: whole-file, open-ended, o Range
// requests grandes (>1MB) get 403 mientras pequeño bounded ranges (un real
// cliente's fragmento solicitudes) serve fine. mpv asks for the whole file in
// one request, so the proxy fetches upstream in bounded chunks and pipes them
// through.
const streamChunkSize = 512 * 1024

// streamChunkSizeCDN es el tamaño de trozo para el resto de las fuentes
// (CDN de Deezer/Tidal/Qobuz, SoundCloud). No tienen el bot-gate de YouTube,
// y trozos más grandes significan menos idas y vueltas: con 512KB cada 20 s de
// audio FLAC había que pedir un rango nuevo, y ese viaje se notaba como un
// hueco. DL
const streamChunkSizeCDN = 4 * 1024 * 1024

// tamanoDeTrozo elige el tamaño de cada petición de rango según el host.
func tamanoDeTrozo(audioURL string) int64 {
	if strings.Contains(audioURL, "googlevideo.com") {
		return streamChunkSize
	}
	return streamChunkSizeCDN
}

// youtubeMediaUA matches the ANDROID_VR client the resolved googlevideo URLs
// are minted for (c=ANDROID_VR). Accepted on small bounded ranges regardless of
// UA, but sending the client's own UA is the closest to a real device.
const youtubeMediaUA = "com.google.android.apps.youtube.vr.oculus/1.65.10 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip"

// StreamURL proxies an audio URL with Range support, fetching the upstream in
// small bounded chunks (see streamChunkSize) and piping them to the caller
// (mpv). Used for desktop and, since googlevideo URLs are bot-gated on some
// networks, for Android playback through the in-process Go server.
