package download

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"

	"github.com/zarz/bitly/go_backend/internal/httpclient"
)

// downloadToFile streams [url] to disk under [outDir] using a temp file +
// atomic rename, reporting progress via [onProgress]. Supports HTTP Range
// resume: if a partial download exists for the same URL, it sends a Range
// header to resume from where it left off instead of restarting from zero.
func descargarAArchivo(url, outDir string, req Request, title, artist string, onProgress func(done, total int64)) (string, error) {
	return descargarAArchivoCon(url, outDir, req, title, artist, onProgress, true)
}

// descargarAArchivoCon es descargarAArchivo con el sondeo/reanudación opcional.
//
// sondear=false es para enlaces de UN SOLO USO (los sitios raspables de FLAC):
// el enlace firmado se consume con la primera petición —el sondeo con
// Range: bytes=0-0 incluido— y la descarga real recibe 409 Conflict. Verificado
// contra superflac: sondeo 200 y descarga siguiente 409, con el mismo enlace.
func descargarAArchivoCon(url, outDir string, req Request, title, artist string, onProgress func(done, total int64), sondear bool) (string, error) {
	if err := os.MkdirAll(outDir, 0755); err != nil {
		return "", err
	}
	// Un llamador sin interés en el progreso (la mejora a FLAC, por ejemplo)
	// pasa nil: se reemplaza por un aviso vacío en vez de panicar al primer
	// bloque escrito.
	if onProgress == nil {
		onProgress = func(int64, int64) {}
	}

	ext := detectarExt(url)
	base := req.TrackID
	if base == "" {
		base = req.ItemID
	}
	pista := sanitizarNombreArchivo(base)
	dest := filepath.Join(outDir, pista+ext)
	huella := huellaFuente(url)

	// Busca un parcial REANUDABLE. Tiene que ser de esta misma pista y de esta
	// misma fuente: adoptar el tamaño de otro archivo como offset del Range
	// produce un archivo cosido con dos audios distintos (la canción "arranca
	// desde la mitad"). Ver orchestrator_parciales.go.
	partialPath, existingSize := buscarParcial(outDir, pista, huella, ext)

	// Cliente de MEDIA: sin timeout global (un FLAC grande tarda) y con
	// muchas conexiones reutilizadas por host, que es lo que hace posible
	// tanto la descarga paralela como la reanudación sin reabrir TLS.
	client := httpclient.NewMediaClient()
	var resp *http.Response
	var err error

	// Descarga PARALELA cuando el origen la soporta. Una sola conexión TCP
	// deja la mayor parte del ancho de banda sin usar en cuanto hay latencia,
	// así que un FLAC de decenas de MB llega varias veces más rápido en N
	// tramos. Si el origen no soporta rangos o el archivo es chico, sigue la
	// ruta secuencial de abajo sin cambiar nada.
	if sondear && (partialPath == "" || existingSize == 0) {
		if info := sondearOrigen(context.Background(), client, url); info.soporta {
			parcial, cerrar := os.CreateTemp(outDir, nombreParcial(pista, huella, ext, true))
			if cerrar == nil {
				tmpParalelo := parcial.Name()
				parcial.Close()
				if perr := descargarEnParalelo(context.Background(), url, tmpParalelo, info,
					conexionesParalelo, onProgress); perr == nil {
					if rerr := os.Rename(tmpParalelo, dest); rerr == nil {
						return dest, nil
					}
				}
				_ = os.Remove(tmpParalelo)
				log.Printf("[download] paralelo no sirvió para %s, se usa secuencial", base)
			}
		}
	}

	if parcialReanudable(sondear, partialPath, existingSize) {
		// Attempt resume with Range header.
		reqHTTP, _ := http.NewRequest("GET", url, nil)
		reqHTTP.Header.Set("Range", fmt.Sprintf("bytes=%d-", existingSize))
		resp, err = client.Do(reqHTTP)
		if err == nil && resp.StatusCode == http.StatusPartialContent {
			// Server supports Range: append to the existing partial file.				log.Printf("[download] resuming from byte %d for %s", existingSize, base)
			// Se le pasa el destino FINAL explícito: antes lo deducía del
			// nombre del temporal y el archivo quedaba con un nombre
			// aleatorio (dl-7283645.flac → 7283645.flac) en vez del de la
			// pista, así que el reproductor y StreamCacheFile no lo veían.
			return anexarAArchivo(dest, partialPath, resp, existingSize, onProgress)
		}
		// El servidor no soporta Range o devolvio error — se cae a una
		// descarga completa, descartando el parcial.
		if resp != nil {
			resp.Body.Close()
		}
		log.Printf("[download] resume not supported (status=%d), restarting from zero for %s",
			func() int {
				if resp != nil {
					return resp.StatusCode
				}
				return 0
			}(), base)
		_ = os.Remove(partialPath)
		partialPath = ""
		existingSize = 0
	}

	// Full download from zero.
	return descargarSecuencialBajandoCompleto(client, url, outDir, dest, pista, huella, ext, onProgress)
}

// parcialReanudable dice si corresponde intentar retomar un parcial ya bajado.
// Con sondear=false (enlaces de un solo uso) nunca: la reanudación pediría el
// enlace otra vez y el servidor responde 409.
func parcialReanudable(sondear bool, partialPath string, existingSize int64) bool {
	return sondear && partialPath != "" && existingSize > 0
}
