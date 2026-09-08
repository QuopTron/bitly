package gobackend

import (
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/zarz/bitly/go_backend/internal/download"
)

// qualityWantsLossless maps a quality token to lossless intent (FLAC tier).
func calidadQuiereLossless(q string) bool {
	switch strings.ToUpper(strings.TrimSpace(q)) {
	case "FLAC", "LOSSLESS", "HI_RES":
		return true
	}
	return false
}

// copyFile copies [src] to [dst], removing a partially-written destination on
// failure so a broken copy is never left behind as a "downloaded" file.
func copiarArchivo(src, dst string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	out, err := os.Create(dst)
	if err != nil {
		return err
	}
	if _, err := io.Copy(out, in); err != nil {
		out.Close()
		_ = os.Remove(dst)
		return err
	}
	return out.Close()
}

// samePath reports whether two paths resolve to the same location (used to
// avoid copying the stream cache onto itself).
func samePath(a, b string) bool {
	aa, ea := filepath.Abs(a)
	bb, eb := filepath.Abs(b)
	if ea != nil || eb != nil {
		return false
	}
	return strings.EqualFold(filepath.Clean(aa), filepath.Clean(bb))
}

// reuseStreamCacheForDownload copies an already-played stream-cache file into
// El requested descarga carpeta cuando se satisfies el requested calidad,// instead of re-walking every provider and re-downloading the same audio from
// scratch. Mirrors how the streaming path already reuses the stream cache
// (streamFallbackDownload → StreamCacheFile): an explicit download of a track
// El usuario ya transmitido debería sin re-pay el proveedor walk + completo// download. Returns true when the download is considered complete (file copied
// or already present), false when the normal pipeline should run.
func reuseStreamCacheForDownload(req download.Request) bool {
	streamDir := streamCacheDirPath()
	if streamDir == "" || req.OutputDir == "" || req.ItemID == "" {
		return false
	}
	// Never copy the cache onto itself (the streaming fallback writes there).
	if samePath(streamDir, req.OutputDir) {
		return false
	}
	cached := download.StreamCacheFile(streamDir, req.ItemID)
	if cached == "" {
		return false
	}
	ext := strings.ToLower(strings.TrimPrefix(filepath.Ext(cached), "."))
	wantLossless := calidadQuiereLossless(req.Quality)
	if wantLossless && ext != "flac" {
		// El usuario pidio explicitamente una copia lossless; solo un FLAC la
		// satisface.
		return false
	}
	if !wantLossless && req.Quality != "" && ext == "flac" {
		// El usuario pidio una copia lossy mas pequena pero solo se streameo un
		// archivo lossless: no sobrescribir silenciosamente su eleccion de
		// almacenamiento; dejar que el pipeline normal produzca el archivo lossy.
		return false
	}
	dest := filepath.Join(req.OutputDir, filepath.Base(cached))
	if err := os.MkdirAll(req.OutputDir, 0o755); err != nil {
		return false
	}
	if _, err := os.Stat(dest); err != nil {
		if err := copiarArchivo(cached, dest); err != nil {
			return false
		}
	}
	// Mark the download completed so the client's progress poll flags it as
	// downloaded (same contract as a normal orchestrator run).
	tr := downloadOrch.Progress()
	tr.Add(req.ItemID, req.Title, req.Provider)
	if req.Artist != "" {
		tr.SetTrackInfo(req.ItemID, req.Title, req.Artist)
	}
	tr.SetOutputPath(req.ItemID, dest)
	return true
}
