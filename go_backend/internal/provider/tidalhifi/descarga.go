// ─────────────────────────────────────────────────────────────
// descarga.go — Bajada del FLAC real de Tidal, segmento a segmento y
// escribiendo directo a disco.
//
// Cómo evita cargar la RAM: en ningún momento se tiene la canción en
// memoria. Se baja el segmento inicial (KB), se escriben los bloques de
// metadata, y después CADA segmento del manifiesto se recibe, se le saca el
// `mdat` y se escribe al archivo, uno por uno. El pico de memoria por
// canción es el tamaño de un segmento (~1 MB), no el de la canción.
//
// Por qué hace falta un archivo temporal: si la bajada se corta a la mitad el
// usuario tendría un FLAC truncado con el nombre de la canción. Se escribe
// como `.partial` y solo se renombra al terminar (rename atómico).
//
// Se conecta con: catalogo.go (resolver), manifiesto.go (plan),
// mp4_flac.go (armado) y el orquestador de descargas (descargadorPropio).
// Parte del flujo: descarga (rescate de FLAC exacto).
// ─────────────────────────────────────────────────────────────

package tidalhifi

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
)

const (
	// timeoutSegmento es el techo de cada segmento de audio (~4 s de música,
	// menos de 1 MB). Con una conexión normal llega en mucho menos; el techo
	// existe para no colgar la descarga de fondo para siempre.
	timeoutSegmento = 20 * time.Second
	// topeSegmento protege de una respuesta absurda (HTML de error, otro
	// audio): 32 MB por segmento es holgadísimo para 4 s sin pérdida.
	topeSegmento = 32 << 20
)

// DescargarAArchivo implementa el camino de los proveedores que traen el
// archivo ellos mismos: resuelve la pista, lee el manifiesto, baja los
// segmentos y deja un `.flac` completo en [outDir].
//
// [id] puede ser un id de Tidal o cualquier identificador de la pista (ISRC);
// [duracionSeg] es la duración que el pipeline espera y sirve para confirmar
// que la pista es la correcta cuando no hay id de Tidal.
func (c *Client) DescargarAArchivo(id, quality, outDir string, duracionSeg int) (string, error) {
	return c.DescargarPista(id, "", "", "", quality, outDir, duracionSeg)
}

// DescargarPista es la versión completa: resuelve por id o por ISRC/nombre y
// baja el audio. El orquestador usa la de arriba; esta existe para poder
// pasarle el ISRC y el nombre cuando se conocen (match exacto).
func (c *Client) DescargarPista(id, isrc, titulo, artista, quality, outDir string, duracionSeg int) (string, error) {
	pista, err := c.resolverPista(id, isrc, titulo, artista, duracionSeg*1000)
	if err != nil {
		return "", err
	}
	plan, err := c.pedirPlan(fmt.Sprintf("%d", pista.ID), quality)
	if err != nil {
		return "", err
	}
	if outDir == "" {
		return "", fmt.Errorf("tidal-hifi: sin carpeta de destino")
	}
	if err := os.MkdirAll(outDir, 0o755); err != nil {
		return "", err
	}
	return c.bajarPlan(plan, pista, outDir)
}

// bajarPlan recorre el plan escribiendo el FLAC en un temporal y renombrando
// al final. Con [plan.esSinPerdida] en false el archivo igual se arma (Tidal
// entrega el mismo envoltorio), así que la degradación a HIGH no rompe nada.
func (c *Client) bajarPlan(plan planDescarga, pista pistaTidal, outDir string) (string, error) {
	destino := filepath.Join(outDir, nombreArchivo(pista, plan.formato))
	temporal := destino + ".partial"
	archivo, err := os.Create(temporal)
	if err != nil {
		return "", err
	}
	listo := false
	defer func() {
		archivo.Close()
		if !listo {
			_ = os.Remove(temporal)
		}
	}()

	inicial, err := c.bajarSegmento(plan.inicial)
	if err != nil {
		return "", fmt.Errorf("tidal-hifi: no se pudo leer el inicio del audio: %v", err)
	}
	bloques, err := bloquesFLACDe(inicial)
	if err != nil {
		return "", err
	}
	if _, err := archivo.Write(append([]byte(cabeceraFLAC), bloques...)); err != nil {
		return "", err
	}
	// Cada segmento: se recibe completo (a lo sumo un par de MB), se le saca
	// el mdat y se escribe. Nada de acumular la canción en memoria.
	for i, url := range plan.segmentos {
		segmento, err := c.bajarSegmento(url)
		if err != nil {
			return "", fmt.Errorf("tidal-hifi: segmento %d de %d falló: %v", i+1, len(plan.segmentos), err)
		}
		for _, payload := range payloadsMdat(segmento) {
			if _, err := archivo.Write(payload); err != nil {
				return "", err
			}
		}
	}
	if err := archivo.Sync(); err != nil {
		return "", err
	}
	if err := archivo.Close(); err != nil {
		return "", err
	}
	if err := os.Rename(temporal, destino); err != nil {
		_ = os.Remove(temporal)
		return "", err
	}
	listo = true
	return destino, nil
}

// bajarSegmento trae una URL de audio del manifiesto. Usa su propio cliente
// sin el timeout corto de la metadata: un segmento puede tardar más y no
// conviene abortarlo por eso.
func (c *Client) bajarSegmento(url string) ([]byte, error) {
	cliente := &http.Client{Timeout: timeoutSegmento}
	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", userAgent)
	req.Header.Set("Accept", "*/*")
	resp, err := cliente.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 400 {
		return nil, fmt.Errorf("HTTP %d", resp.StatusCode)
	}
	return io.ReadAll(io.LimitReader(resp.Body, topeSegmento))
}

// nombreArchivo arma el nombre del FLAC: artista - título, sin caracteres que
// rompan el sistema de archivos.
func nombreArchivo(p pistaTidal, formato string) string {
	nombre := strings.TrimSpace(p.Artist.Name + " - " + p.Title)
	nombre = strings.Map(func(r rune) rune {
		switch r {
		case '/', '\\', ':', '*', '?', '"', '<', '>', '|':
			return '-'
		}
		return r
	}, nombre)
	if nombre == "" {
		nombre = fmt.Sprintf("tidal-%d", p.ID)
	}
	if len(nombre) > 120 {
		nombre = nombre[:120]
	}
	return nombre + ".flac"
}
