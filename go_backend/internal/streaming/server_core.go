package streaming

import (
	"net/http"
	"time"
)

type Streamer struct {
	client *http.Client
	cache  *Cache
	server *http.Server
}

// NewStreamer creates an audio streamer.
func NewStreamer() *Streamer {
	return &Streamer{
		client: &http.Client{Timeout: 30 * time.Second},
		cache:  NewCache(),
	}
}

// streamChunkSize caps each upstream range request. YouTube bot-gates some
// egress IPs: whole-file, open-ended, or large (>1MB) Range requests get 403
// mientras pequeño bounded ranges (un real cliente's fragmento solicitudes) serve fine.// mpv asks for the whole file in one request, so the proxy fetches upstream in
// bounded chunks and pipes them through.
const streamChunkSize = 512 * 1024

// youtubeMediaUA matches the ANDROID_VR client the resolved googlevideo URLs
// are minted for (c=ANDROID_VR). Accepted on small bounded ranges regardless of
// UA, but sending the client's own UA is the closest to a real device.
const youtubeMediaUA = "com.google.android.apps.youtube.vr.oculus/1.65.10 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip"

// StreamURL proxies an audio URL with Range support, fetching the upstream in
// small bounded chunks (see streamChunkSize) and piping them to the caller
// (mpv). Used for desktop and, since googlevideo URLs are bot-gated on some
// networks, for Android playback through the in-process Go server.
