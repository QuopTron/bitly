package download

import (
	"fmt"
	"log"
	"os"
	"path/filepath"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

// attemptExtensionDownload runs a full extension-provider download pipeline
// (writes the file to disk and reports real progress). Handles verification
// errors, DRM/encrypted outputs and playability validation; on success the
// file is quality-adjusted and finalized.
func (o *Orchestrator) attemptExtensionDownload(req Request, name string, p provider.Provider, ep *provider.ExtensionProvider, trackID, title, artist, outDir string) *Result {
	o.tracker.Update(req.ItemID, StatusDownloading, 0.2)
	// La descarga() de la extension espera una ruta destino completa, no un
	// directorio. Se construye un basename del id del track (o titulo); el
	// sufijo unico ".tmp.<provider>" evita que descargas companeras
	// concurrentes del mismo item colisionen en un solo filename.
	extBase := req.ItemID
	if extBase == "" {
		extBase = title + " - " + artist
	}
	extDest := filepath.Join(outDir, sanitizarNombreArchivo(extBase)+".tmp."+sanitizarNombreArchivo(name))
	result := ep.Download(trackID, calidadParaProvider(p, req.Quality), extDest, func(percent int) {
		o.tracker.Update(req.ItemID, StatusDownloading, 0.2+float64(percent)/100.0*0.7)
	})
	if !result.Success {
		cooldown.MarkOpError(name, downloadCooldownOp, result.Error)
		if vt := clasificarErrorVerificacion(result.Error); vt != "" {
			// Remember the verification-needing provider so we can surface it
			// only if every provider ends up streamless.
			o.tracker.SetError(req.ItemID, "verification required")
			return &Result{ItemID: req.ItemID, Success: false, Error: "Download failed: " + result.Error, ErrorType: vt, Service: name}
		}
		// Storage write failures cannot be solved by trying another provider —
		// propagate the error so the fallback loop stops immediately.
		if esFalloEscrituraAlmacenamiento(result.Error) {
			return &Result{ItemID: req.ItemID, Success: false, Error: result.Error, ErrorType: "storage_write_failure", Service: name}
		}
		return &Result{ItemID: req.ItemID, Success: false, Error: result.Error}
	}
	if result.FilePath == "" {
		return &Result{ItemID: req.ItemID, Success: false, Error: fmt.Sprintf("%s: sin archivo", name)}
	}
	// Double-check the downloaded file is the ORIGINAL song. The extension
	// reports the real title/artist of what it put on disk; if they don't
	// strongly match the request, discard it so another provider serves the
	// original instead of a wrong version (cover/remix/wrong artist).
	if req.Title != "" && (result.Title != "" || result.Artist != "") {
		if _, ok := provider.OriginalStrength(req.Title, req.Artist, provider.TrackResult{Title: result.Title, Artist: result.Artist}); !ok {
			_ = os.Remove(result.FilePath)
			return &Result{ItemID: req.ItemID, Success: false, Error: fmt.Sprintf("%s: archivo no es la cancion original", name)}
		}
	}
	// Providers like amazon hand back an encrypted/DRM file (.m4a) with a
	// decryption key. If we can decrypt it into a playable file, serve that
	// (real, high-quality audio). Only when no key/ffmpeg is available do we
	// treat it as a failure and let another provider try.
	if result.Encrypted && result.DecryptionKey != "" {
		// Trust the file over the flag: a provider may mark a download as
		// encrypted yet actually serve a plain, playable container (zarz
		// returning a plain FLAC with a stale key). In that case serve it
		// directly instead of forcing a doomed mov-key decrypt.
		if esArchivoAudioPlano(result.FilePath) {
			result.FilePath = o.applyQuality(req.ItemID, result.FilePath, outDir, req.Quality)
			result.FilePath = finalizarArchivoDescarga(outDir, req.ItemID, result.FilePath)
			cooldown.MarkOpOk(name, downloadCooldownOp)
			o.tracker.SetOutputPath(req.ItemID, result.FilePath)
			return &Result{ItemID: req.ItemID, Success: true, Provider: name, FilePath: result.FilePath, Encrypted: false}
		}
		if dec, derr := descifrarStream(result.FilePath, result.DecryptionKey, outDir, result.OutputExtension, result.InputFormat); derr == nil && dec != "" {
			_ = os.Remove(result.FilePath)
			dec = o.applyQuality(req.ItemID, dec, outDir, req.Quality)
			dec = finalizarArchivoDescarga(outDir, req.ItemID, dec)
			cooldown.MarkOpOk(name, downloadCooldownOp)
			o.tracker.SetOutputPath(req.ItemID, dec)
			return &Result{ItemID: req.ItemID, Success: true, Provider: name, FilePath: dec, Encrypted: false}
		} else if FFmpegPath() == "" && result.FilePath != "" {
			// No CLI ffmpeg (e.g. Android). Keep the encrypted file on disk
			// and hand it to the client so it can decrypt via ffmpeg-kit.
			// Give it a stable {item_id}{ext} name (the extension may have
			// left a ".tmp.<provider>" basename) so the persisted DB path
			// stays meaningful and reusable on later plays.
			result.FilePath = finalizarArchivoDescarga(outDir, req.ItemID, result.FilePath)
			o.tracker.SetEncryptedOutput(req.ItemID, result.FilePath, result.DecryptionKey, result.OutputExtension, result.InputFormat)
			log.Printf("[orchestrator] encrypted itemID=%q path=%q key=%q ext=%q inFmt=%q provider=%q", req.ItemID, result.FilePath, result.DecryptionKey, result.OutputExtension, result.InputFormat, name)
			cooldown.MarkOpOk(name, downloadCooldownOp)
			return &Result{ItemID: req.ItemID, Success: true, Provider: name, FilePath: result.FilePath, Encrypted: true, ClientDecrypt: true, DecryptionKey: result.DecryptionKey, OutputExtension: result.OutputExtension, InputFormat: result.InputFormat}
		}
		// Fall through to rejection (ffmpeg present but decrypt failed).
	}
	if result.Encrypted {
		_ = os.Remove(result.FilePath)
		return &Result{ItemID: req.ItemID, Success: false, Error: fmt.Sprintf("%s: stream encriptado no reproducible", name)}
	}
	result.FilePath = o.applyQuality(req.ItemID, result.FilePath, outDir, req.Quality)
	result.FilePath = finalizarArchivoDescarga(outDir, req.ItemID, result.FilePath)
	// Validate the file is actually playable audio before accepting.
	// SoundCloud HLS streams disguised as .mp3 pass the extension check
	// but fail here - they start with 0x47 (MPEG-TS), not real MP3.
	if !esArchivoAudioReproducible(result.FilePath) {
		// Comprueba si este es un HLS/M3U8 manifest (text lista de reproducción, sin DRM).
		// SoundCloud sometimes returns HLS stream URLs that are just playlist
		// manifests — these are NOT encrypted audio and must NOT be sent to the
		// client for "decryption". Delete and fail cleanly so the next provider
		// can be tried.
		if esManifiestoHLS(result.FilePath) {
			info, _ := os.Stat(result.FilePath)
			log.Printf("[orchestrator] %s: downloaded file is HLS manifest (%d bytes), not audio — deleting", name, info.Size())
			_ = os.Remove(result.FilePath)
			return &Result{ItemID: req.ItemID, Success: false, Error: fmt.Sprintf("%s: HLS manifest, no audio data", name)}
		}
		// The archivo puede ser un DRM-encrypted container (e.g. Apple Music .m4a)
		// that the client can decrypt via ffmpeg-kit. Return as encrypted so
		// Dart's download_cubit attempts client-side decryption.
		info, serr := os.Stat(result.FilePath)
		if serr == nil && info.Size() > 1024 {
			log.Printf("[orchestrator] %s: file not decodable but exists (%d bytes), marking encrypted for client decrypt", name, info.Size())
			cooldown.MarkOpOk(name, downloadCooldownOp)
			o.tracker.SetEncryptedOutput(req.ItemID, result.FilePath, "", "", "")
			return &Result{ItemID: req.ItemID, Success: true, Provider: name, FilePath: result.FilePath, Encrypted: true, ClientDecrypt: true}
		}
		_ = os.Remove(result.FilePath)
		return &Result{ItemID: req.ItemID, Success: false, Error: fmt.Sprintf("%s: archivo corrupto o muy pequeno", name)}
	}
	cooldown.MarkOpOk(name, downloadCooldownOp)
	o.tracker.SetOutputPath(req.ItemID, result.FilePath)
	return &Result{ItemID: req.ItemID, Success: true, Provider: name, FilePath: result.FilePath, Encrypted: false}
}
