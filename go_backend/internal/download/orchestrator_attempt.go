package download

import (
	"github.com/zarz/bitly/go_backend/internal/provider"
)

// attemptDownload runs ONE provider's full download pipeline for [req]. It is
// invoked concurrently for every resolved candidate so the fastest working
// source wins. It returns a Result: Success=true with the produced file/stream
// on success, or Success=false carrying the failure message, the verification
// service (if any) and an "encriptado" marker so the caller can aggregate.
func (o *Orchestrator) attemptDownload(req Request, name string, p provider.Provider, trackID, title, artist, outDir string) *Result {
	o.tracker.Update(req.ItemID, StatusDownloading, 0.1)
	o.tracker.SetTrackInfo(req.ItemID, title, artist)

	// Full extension download pipeline (writes file to disk, reports real progress).
	if ep, ok := p.(*provider.ExtensionProvider); ok && outDir != "" {
		return o.attemptExtensionDownload(req, name, p, ep, trackID, title, artist, outDir)
	}
	// Proveedor que trae el archivo por su cuenta (Soulseek: el par que sube
	// abre la conexión de datos hacia nosotros, así que no existe una URL que
	// se pueda pedir con GET). Se le pide el archivo ya escrito.
	if d, ok := p.(descargadorPropio); ok && outDir != "" {
		return o.attemptProviderDownload(req, name, p, d, trackID, outDir)
	}
	// Native provider: resolve a stream URL and download it to disk.
	return o.attemptNativeDownload(req, name, p, trackID, title, artist, outDir)
}
