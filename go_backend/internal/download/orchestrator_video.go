package download

import (
	"fmt"
	"regexp"
	"strings"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/provider"
	"github.com/zarz/bitly/go_backend/internal/provider/youtube"
)

// videoIDRe matches a bare YouTube video id (11 chars, [A-Za-z0-9_-]).
var videoIDRe = regexp.MustCompile(`^[A-Za-z0-9_-]{11}$`)

// ResolveVideoURL resolves a direct video stream URL for [videoID] at the
// requested quality height. Two independent routes:
//  1. native youtube provider (yt-dlp) → GetVideoURL — returns a real
//     video+audio stream at the requested quality. Prefer it when the binary
//     is installed (yt-dlp is downloaded in the background on Android); it is
//     also what the visualizer used successfully before the streaming route
//     existed.
//  2. ytmusic-spotiflac extension → getDownloadUrl(id, quality, forceVideo=true),
//     which resolves itag=18 (video+audio mp4) through the InnerTube player
//     API — used when yt-dlp is not installed yet, or as a last-resort stream.
//
// [videoID] must be a bare YouTube id; foreign track ids must be mapped to one
// first (see ResolveVisualizerStream below).
func (o *Orchestrator) ResolveVideoURL(videoID, quality string) (string, error) {
	id := strings.TrimPrefix(strings.TrimSpace(videoID), "yt:")
	if id == "" {
		return "", fmt.Errorf("video: falta ID de video")
	}
	// Route 1: native youtube provider via yt-dlp.
	if p := o.providers.Get("youtube"); p != nil {
		if yc, ok := p.(*youtube.Client); ok {
			if url, err := yc.GetVideoURL(id, quality); err == nil && url != "" {
				return url, nil
			}
		}
	}
	// Route 2: the bundled ytmusic extension (InnerTube, no external binary).
	// Any registered extension exposing getDownloadUrl with video support wins;
	// prefer ytmusic-spotiflac, then any -web extension in the fallback order.
	for _, name := range o.fallbackOrder {
		if cooldown.IsCooledOp(name, downloadCooldownOp) {
			continue
		}
		p := o.providers.Get(name)
		if p == nil {
			continue
		}
		ep, ok := p.(*provider.ExtensionProvider)
		if !ok {
			continue
		}
		if url, err := ep.GetVisualizerURL(id, quality); err == nil && url != "" {
			cooldown.MarkOpOk(name, downloadCooldownOp)
			return url, nil
		}
	}
	// Ultimo recurso: cualquier URL de stream (aunque sea solo audio, deja que
	// el visualizador muestre el arte del album / waveform en vez de fallar).
	return o.resolveStreamURL(id, quality)
}
