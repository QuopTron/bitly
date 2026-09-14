package download

import (
	"fmt"
	"log"
	"os"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

// descargadorPropio lo implementan los proveedores que NO pueden resolver una
// URL de stream: el audio lo traen ellos mismos. Es el caso de Soulseek, donde
// el par que sube abre la conexión de datos HACIA NOSOTROS, así que no hay
// ningún endpoint que el orquestador pueda pedir con GET.
//
// duracionEsperadaS es la duración del catálogo: con ese dato el proveedor
// verifica que la grabación sea la pedida y no un remix, un directo o un
// archivo cortado. 0 significa "no se sabe" y la verificación se degrada a
// formato solamente, que se reporta tal cual.
type descargadorPropio interface {
	DescargarAArchivo(trackID, quality, destinoDir string, duracionEsperadaS int) (string, error)
}

// attemptProviderDownload es el camino de un descargadorPropio. Termina igual
// que el nativo —aplicando calidad y validando que el resultado sea audio real—
// porque la validación NO depende de en quién confiemos: el archivo igual lo
// escribió un proceso que no controlamos.
func (o *Orchestrator) attemptProviderDownload(req Request, name string, p provider.Provider, d descargadorPropio, trackID, outDir string) *Result {
	o.tracker.Update(req.ItemID, StatusDownloading, 0.3)
	filePath, err := d.DescargarAArchivo(trackID, calidadParaProvider(p, req.Quality), outDir, req.DurationMS/1000)
	if err != nil {
		cooldown.MarkOpError(name, downloadCooldownOp, err.Error())
		return &Result{ItemID: req.ItemID, Success: false, Error: fmt.Sprintf("%s: %v", name, err)}
	}
	o.tracker.Update(req.ItemID, StatusDownloading, 0.95)
	filePath = o.applyQuality(req.ItemID, filePath, outDir, req.Quality)
	filePath = finalizarArchivoDescarga(outDir, req.ItemID, filePath)
	// El filtro de audio es la última palabra: si lo que quedó en disco no es un
	// contenedor de audio conocido (lista blanca de audioguard), no se sirve.
	if !esArchivoAudioReproducible(filePath) {
		log.Printf("[orchestrator] %s: el archivo descargado no pasó la validación de audio, se descarta", name)
		_ = os.Remove(filePath)
		return &Result{ItemID: req.ItemID, Success: false, Error: fmt.Sprintf("%s: el archivo no es audio reproducible", name)}
	}
	cooldown.MarkOpOk(name, downloadCooldownOp)
	o.tracker.SetOutputPath(req.ItemID, filePath)
	return &Result{ItemID: req.ItemID, Success: true, Provider: name, FilePath: filePath}
}
