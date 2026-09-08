package gobackend

import (
	"os"
	"path/filepath"
	"strings"

	"github.com/zarz/bitly/go_backend/internal/download"
)

// downloadLyricsToDisk fetches lyrics and writes a .lrc sidecar next to the
// audio file, matching the filename Flutter expects: lyrics_{sha1(id)}.{lrc,txt}.
func descargarLetrasADisco(req download.Request) string {
	outDir := req.OutputDir
	if outDir == "" {
		outDir = download.GlobalOutputDir()
	}
	if outDir == "" || lyricsClient == nil || req.TrackID == "" {
		return `{"itemId":"` + req.ItemID + `","success":false,"error":"letras: falta outDir o trackID"}`
	}
	if err := os.MkdirAll(outDir, 0o755); err != nil {
		return `{"itemId":"` + req.ItemID + `","success":false,"error":"` + err.Error() + `"}`
	}
	lyr, err := lyricsClient.GetLyrics(req.Title, req.Artist, 0)
	if err != nil || lyr == nil {
		return `{"itemId":"` + req.ItemID + `","success":false,"error":"letras no encontradas"}`
	}
	text := lyr.SyncedLyrics
	if text == "" {
		text = lyr.PlainLyrics
	}
	if text == "" {
		return `{"itemId":"` + req.ItemID + `","success":false,"error":"instrumental sin letras"}`
	}
	hash := sha1Hex(req.TrackID)
	base := filepath.Join(outDir, "lyrics_"+hash)
	lrcPath := base + ".lrc"
	txtPath := base + ".txt"
	if err := writeFileAtomic(lrcPath, text); err != nil {
		return `{"itemId":"` + req.ItemID + `","success":false,"error":"` + err.Error() + `"}`
	}
	_ = writeFileAtomic(txtPath, text)
	return `{"itemId":"` + req.ItemID + `","success":true,"filePath":"` + lrcPath + `","title":"` + req.Title + `","artist":"` + req.Artist + `"}`
}

// downloadVideoToDisk resolves a video stream and writes {Artist} - {Title}.mp4.
func descargarVideoADisco(req download.Request) string {
	outDir := req.OutputDir
	if outDir == "" {
		outDir = download.GlobalOutputDir()
	}
	if outDir == "" || req.TrackID == "" {
		return `{"itemId":"` + req.ItemID + `","success":false,"error":"video: falta outDir o trackID"}`
	}
	if err := os.MkdirAll(outDir, 0o755); err != nil {
		return `{"itemId":"` + req.ItemID + `","success":false,"error":"` + err.Error() + `"}`
	}
	videoID := req.TrackID
	// El canción id comes de cualquier proveedor (spotify/deezer/...). youtube necesita
	// un real video ID, so cuando el caller gives us un foreign ID plus el canción
	// name, search YouTube first and use the best match (video is a separate
	// visual feature — never the audio stream).
	if !strings.HasPrefix(videoID, "yt:") && req.Title != "" {
		query := req.Title
		if req.Artist != "" {
			query = req.Title + " " + req.Artist
		}
		if p := reg.Get("youtube"); p != nil {
			if results, serr := p.SearchTracks(query, 1); serr == nil && len(results) > 0 && results[0].ID != "" {
				videoID = results[0].ID // "yt:<videoID>"
			}
		}
	}
	if videoID == "" {
		return `{"itemId":"` + req.ItemID + `","success":false,"error":"video: sin ID de video"}`
	}
	streamURL, err := downloadOrch.ResolveVideoURL(videoID, req.Quality)
	if err != nil || streamURL == "" {
		return `{"itemId":"` + req.ItemID + `","success":false,"error":"video: no se pudo resolver URL"}`
	}
	name := "video_" + req.TrackID
	if req.Artist != "" && req.Title != "" {
		name = req.Artist + " - " + req.Title
	}
	path := filepath.Join(outDir, sanitizeFileName(name)+".mp4")
	if err := downloadOrch.WriteURLToFile(streamURL, path); err != nil {
		return `{"itemId":"` + req.ItemID + `","success":false,"error":"` + err.Error() + `"}`
	}
	return `{"itemId":"` + req.ItemID + `","success":true,"filePath":"` + path + `","title":"` + req.Title + `","artist":"` + req.Artist + `"}`
}
