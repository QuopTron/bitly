package download

import (
	"fmt"
	"log"
	"os"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

// attemptNativeDownload resolves a stream URL via a native (non-extension)
// provider and downloads it to disk, validating the result is playable audio.
// Without an output dir it falls back to returning the raw stream URL.
func (o *Orchestrator) attemptNativeDownload(req Request, name string, p provider.Provider, trackID, title, artist, outDir string) *Result {
	// Native provider: resolve a stream URL and download it to disk.
	streamURL, err := p.GetStreamURL(trackID, calidadParaProvider(p, req.Quality))
	if err != nil || streamURL == "" {
		if err != nil {
			cooldown.MarkOpError(name, downloadCooldownOp, err.Error())
		}
		return &Result{ItemID: req.ItemID, Success: false, Error: fmt.Sprintf("%s: sin stream", name)}
	}
	if outDir != "" {
		filePath, derr := descargarAArchivo(streamURL, outDir, req, title, artist, func(done, total int64) {
			if total > 0 {
				o.tracker.Update(req.ItemID, StatusDownloading, 0.3+float64(done)/float64(total)*0.65)
			}
		})
		if derr != nil {
			return &Result{ItemID: req.ItemID, Success: false, Error: fmt.Sprintf("%s: %v", name, derr)}
		}
		filePath = o.applyQuality(req.ItemID, filePath, outDir, req.Quality)
		filePath = finalizarArchivoDescarga(outDir, req.ItemID, filePath)
		// Validate the file is actually playable audio.
		if !esArchivoAudioReproducible(filePath) {
			// Comprueba si esto es un manifest HLS/M3U8 — sin DRM, solo una lista de reproduccion.
			if esManifiestoHLS(filePath) {
				info, _ := os.Stat(filePath)
				log.Printf("[orchestrator] %s native: downloaded file is HLS manifest (%d bytes), deleting", name, info.Size())
				_ = os.Remove(filePath)
				return &Result{ItemID: req.ItemID, Success: false, Error: fmt.Sprintf("%s: HLS manifest, no audio data", name)}
			}
			// Don't delete — may be DRM-encrypted; let client decrypt.
			info, serr := os.Stat(filePath)
			if serr == nil && info.Size() > 1024 {
				log.Printf("[orchestrator] %s native: file not decodable but exists (%d bytes), marking encrypted", name, info.Size())
				cooldown.MarkOpOk(name, downloadCooldownOp)
				o.tracker.SetEncryptedOutput(req.ItemID, filePath, "", "", "")
				return &Result{ItemID: req.ItemID, Success: true, Provider: name, FilePath: filePath, StreamURL: streamURL, Encrypted: true, ClientDecrypt: true}
			}
			_ = os.Remove(filePath)
			return &Result{ItemID: req.ItemID, Success: false, Error: fmt.Sprintf("%s: archivo corrupto o muy pequeno", name)}
		}
		cooldown.MarkOpOk(name, downloadCooldownOp)
		o.tracker.SetOutputPath(req.ItemID, filePath)
		return &Result{ItemID: req.ItemID, Success: true, Provider: name, FilePath: filePath, StreamURL: streamURL}
	}

	// No output dir configured: fall back to returning the stream URL
	// (compatible with the previous streaming-only behavior).
	o.tracker.SetOutputPath(req.ItemID, streamURL)
	cooldown.MarkOpOk(name, downloadCooldownOp)
	return &Result{ItemID: req.ItemID, Success: true, Provider: name, StreamURL: streamURL}
}
