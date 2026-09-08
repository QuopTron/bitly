package gobackend

import (
	"encoding/json"
	"fmt"

	"github.com/zarz/bitly/go_backend/internal/streaming"
)

// streamPackageParams is the decoded RPC payload of GetStreamPackage.
type streamPackageParams struct {
	PreferredProvider string `json:"preferredProvider"`
	TrackID           string `json:"trackID"`
	Quality           string `json:"quality"`
	FetchLyrics       string `json:"fetchLyrics"`
	TrackName         string `json:"trackName"`
	ArtistName        string `json:"artistName"`
	ISRC              string `json:"isrc"`
	DurationMS        int    `json:"durationMs"`
	AllowFallback     bool   `json:"allowFallback"`
	// Cross-provider ids from detail views (album/artist/playlist). Detail
	// Canciones carry estos so cualquier extension puede resolve immediately mediante
	// CheckAvailability instead of a slow name search.
	SpotifyID string `json:"spotifyId"`
	DeezerID  string `json:"deezerId"`
	TidalID   string `json:"tidalId"`
	QobuzID   string `json:"qobuzId"`
}

// GetStreamPackage returns a complete stream package: audio URL + metadata + lyrics + cover.
// Hace fallback entre providers si el especificado no tiene stream.
func GetStreamPackage(payload string) string {
	if reg == nil {
		return `{"error":"no inicializado"}`
	}
	var params streamPackageParams
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{"error":"payload inválido"}`
	}
	fetchL := params.FetchLyrics == "true" || params.FetchLyrics == "1"

	// Real playback (AllowFallback=true).
	//
	// FULL-STREAM providers (youtube/ytmusic/soundcloud/deezer) serve full-length
	// http audio: resolve it via identifiers (~1-2s, no slow name search) and play
	// instantly — media_kit streams it progressively.
	//
	// Preview/DRM providers (apple-music, spotify-web, amazon, qobuz, tidal) have
	// sin stream directo util (clips de 30s o archivos encriptados), asi que la
	// reproduccion produce el archivo real (basado en ids + en cache) igual que antes.
	if params.AllowFallback {
		return streamPackageFallback(&params)
	}

	pkg, err := streaming.GetStreamPackage(reg, lyricsClient, params.PreferredProvider, params.TrackID, params.Quality, fetchL, params.TrackName, params.ArtistName, params.ISRC, params.SpotifyID, params.DeezerID, params.TidalID, params.QobuzID)
	if err != nil && !params.AllowFallback {
		// Background preloads (feed/queue prefetch) skip the download fallback
		// so they don't trigger full audio downloads for every non-streamable
		// track. The player re-resolves with fallback when the user taps play.
		return jsonError(err)
	}
	if err != nil {
		// Last resort: only download-to-cache if the direct resolve above failed
		// (the AllowFallback fast-path already tried it once).
		out := streamFallbackDownload(params.TrackID, params.Quality, params.PreferredProvider, params.TrackName, params.ArtistName, params.ISRC, params.DurationMS, params.SpotifyID, params.DeezerID, params.TidalID, params.QobuzID)
		if out.encrypted != nil {
			return streamEncryptedJSON(out.encrypted, params.PreferredProvider)
		}
		if out.err != nil {
			// Surface the structured error (errorType/service) so the client can
			// open the right verification flow, not just the raw message.
			return streamFallbackErrorJSON(fmt.Errorf("%v; fallback: %v", err, out.err), out)
		}
		pkg = &streaming.StreamPackage{
			AudioURL: out.fileURL,
			Provider: "fallback",
			Quality:  params.Quality,
		}
	}
	data, _ := json.Marshal(pkg)
	return string(data)
}
