package download

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/provider"
	"github.com/zarz/bitly/go_backend/internal/provider/youtube"
)

// ResolveVisualizerStream finds the song's YouTube video id and resolves a
// VIDEO-capable stream URL for it. It mirrors how audio resolution identifies
// El exact canción (isrc primero mediante cada extension's checkavailability, entonces a// strict title+artist search) but never depends on the native youtube provider
// / yt-dlp, so the visualizer works on any device where audio streaming works.
func (o *Orchestrator) ResolveVisualizerStream(req Request, quality string) (string, error) {
	// A real YouTube video id already in hand → resolve it directly.
	tid := strings.TrimSpace(req.TrackID)
	tid = quitarPrefijoTrack(tid)
	if strings.HasPrefix(req.Provider, "yt") || strings.HasPrefix(tid, "yt:") ||
		videoIDRe.MatchString(tid) {
		return o.ResolveVideoURL(tid, quality)
	}

	queryTitle, artist := req.Title, req.Artist
	q := strings.TrimSpace(queryTitle + " " + artist)

	// 1) Native youtube provider (yt-dlp): returns a REAL YouTube video id for
	// el canción (normalmente el official music video). Prefer se — el visualizer
	// needs actual video frames and yt-dlp has proven to work on this device.
	// Only when the binary is not installed does this fail fast, letting the
	// fallback below take over.
	if yp := o.providers.Get("youtube"); yp != nil {
		if yc, ok := yp.(*youtube.Client); ok && q != "" {
			if results, err := yc.SearchTracks(q, 5); err == nil && len(results) > 0 {
				for _, res := range results {
					if res.ID == "" {
						continue
					}
					if queryTitle != "" && artist != "" {
						if provider.BestOriginal(queryTitle, artist, results) == nil {
							continue
						}
					}
					if u, err := o.ResolveVideoURL(res.ID, quality); err == nil && u != "" {
						return u, nil
					}
					break // ResolveVideoURL already walked its own routes
				}
			}
		}
	}

	// 2) ytmusic-spotiflac catalog search (InnerTube): returns the canonical
	// music-video id for the track. Used when yt-dlp is unavailable.
	ytName := "ytmusic-spotiflac"
	yp := o.providers.Get(ytName)
	if ep, ok := yp.(*provider.ExtensionProvider); ok {
		if vid := ep.ResolveVisualizerVideoID(q, artist); vid != "" {
			if u, err := o.ResolveVideoURL(vid, quality); err == nil && u != "" {
				return u, nil
			}
		}
		if q != "" {
			if results, err := ep.SearchTracks(q, 8); err == nil && len(results) > 0 {
				if queryTitle != "" && artist != "" {
					if best := provider.BestOriginal(queryTitle, artist, results); best != nil && best.ID != "" {
						if u, err2 := o.ResolveVideoURL(best.ID, quality); err2 == nil && u != "" {
							return u, nil
						}
					}
				} else if results[0].ID != "" {
					if u, err2 := o.ResolveVideoURL(results[0].ID, quality); err2 == nil && u != "" {
						return u, nil
					}
				}
			}
		}
	}
	return "", fmt.Errorf("video: no se encontro un video para la cancion")
}

// resolveStreamURL returns a stream URL for a track from any registered provider.
func (o *Orchestrator) resolveStreamURL(trackID, quality string) (string, error) {
	for _, name := range o.fallbackOrder {
		if cooldown.IsCooledOp(name, downloadCooldownOp) {
			continue
		}
		p := o.providers.Get(name)
		if p == nil {
			continue
		}
		if url, err := p.GetStreamURL(trackID, quality); err == nil && url != "" {
			cooldown.MarkOpOk(name, downloadCooldownOp)
			return url, nil
		}
	}
	return "", fmt.Errorf("ERR_NO_STREAM_URL: ningun proveedor genero una URL de stream")
}

// WriteURLToFile downloads [url] to [path] using the same temp+rename logic.
func (o *Orchestrator) WriteURLToFile(url, path string) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	client := &http.Client{Timeout: 0}
	resp, err := client.Get(url)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("HTTP %d al obtener stream", resp.StatusCode)
	}
	tmp, err := os.CreateTemp(filepath.Dir(path), "dl-*")
	if err != nil {
		return err
	}
	tmpPath := tmp.Name()
	defer os.Remove(tmpPath)
	buf := make([]byte, 256*1024)
	for {
		n, rerr := resp.Body.Read(buf)
		if n > 0 {
			if _, werr := tmp.Write(buf[:n]); werr != nil {
				tmp.Close()
				return werr
			}
		}
		if rerr == io.EOF {
			break
		}
		if rerr != nil {
			tmp.Close()
			return rerr
		}
	}
	tmp.Close()
	return os.Rename(tmpPath, path)
}
