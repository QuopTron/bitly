// ─────────────────────────────────────────────────────────────
// cobalt.go — Respaldo de DESCARGA del audio de YouTube vía una instancia
// de cobalt (cobalt.tools, open source y self-hosteable).
//
// Por qué existe: yt-dlp puede fallar por IP bloqueada, rate-limit o binario
// viejo, y ahí la descarga se quedaba sin segunda vía. cobalt resuelve el
// mismo audio desde otra IP (la de la instancia del usuario) y lo entrega
// como archivo, así que la canción baja igual.
//
// Por qué NO es una fuente del canal sin pérdida: cobalt no entrega FLAC
// (solo mp3/ogg/wav/opus y "best", que conserva el formato de origen —ver
// imputnet/cobalt#820—). Es el mismo audio de YouTube que ya da yt-dlp, así
// que se usa SOLO como segunda vía de descarga, nunca para "mejorar" a FLAC.
//
// Por qué viene APAGADO: la API pública de cobalt.tools pide sesión/API Key,
// y el principio del proyecto es no depender de cuentas ajenas. Se enciende
// con la URL de una instancia propia (ajuste "cobalt") y, si esa instancia
// lo pide, su clave (ajuste "cobalt_token"). Sin URL, este archivo no abre
// ninguna conexión.
//
// Los ajustes (instancia propia) viven en cobalt_ajustes.go y lo que se BAJA
// y cómo se lo nombra, en cobalt_archivo.go.
//
// Se conecta con: download.go (fallback de Download), extensions_settings.go
// (ajuste "cobalt" de la extensión "youtube") y los otros dos cobalt_*.go.
// Parte del flujo: descarga (YouTube → segunda vía).
// ─────────────────────────────────────────────────────────────

package youtube

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

// userAgent realista: las instancias de cobalt rechazan clientes raros.
const userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
	"(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

const (
	// timeoutCobalt es el techo de la petición a la API: la instancia puede
	// encolar el trabajo del lado suyo, pero no más de esto.
	timeoutCobalt = 30 * time.Second
	// maxCobaltRespuesta acota el JSON de la API (nunca es grande).
	maxCobaltRespuesta = 1 << 20
)

// respuestaCobalt es lo que devuelve la API v10: el estado y, cuando hay
// archivo, su enlace y su nombre.
type respuestaCobalt struct {
	Status   string `json:"status"`
	URL      string `json:"url"`
	Filename string `json:"filename"`
	Error    struct {
		Code string `json:"code"`
	} `json:"error"`
}

// descargarConCobalt baja el audio de [videoID] a [outputDir] usando la
// instancia configurada. Sin instancia devuelve error (y no toca la red).
func (c *Client) descargarConCobalt(videoID, outputDir string) (*DownloadResult, error) {
	instancia := c.instanciaCobalt()
	if !instancia.activa() {
		return nil, fmt.Errorf("cobalt: sin instancia configurada")
	}
	enlace, nombre, err := instancia.pedirAudio(videoID)
	if err != nil {
		return nil, err
	}
	ruta, err := instancia.bajarArchivo(enlace, nombre, videoID, outputDir)
	if err != nil {
		return nil, err
	}
	return &DownloadResult{FilePath: ruta}, nil
}

// pedirAudio le pide a la instancia el archivo del video y devuelve su enlace
// y el nombre sugerido.
func (instancia cobaltConfig) pedirAudio(videoID string) (string, string, error) {
	cuerpo, err := json.Marshal(map[string]string{
		"url": fmt.Sprintf("https://www.youtube.com/watch?v=%s", videoID),
		// "best" conserva el formato de origen: pedir una conversión
		// agregaría una generación de pérdida sin ganar nada.
		"downloadMode":  "audio",
		"audioFormat":   "best",
		"filenameStyle": "basic",
	})
	if err != nil {
		return "", "", err
	}
	req, err := http.NewRequest(http.MethodPost, instancia.base+"/", strings.NewReader(string(cuerpo)))
	if err != nil {
		return "", "", err
	}
	req.Header.Set("Accept", "application/json")
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("User-Agent", userAgent)
	if instancia.token != "" {
		req.Header.Set("Authorization", "Api-Key "+instancia.token)
	}
	cliente := &http.Client{Timeout: timeoutCobalt}
	resp, err := cliente.Do(req)
	if err != nil {
		return "", "", fmt.Errorf("cobalt: no se pudo pedir el audio: %w", err)
	}
	defer resp.Body.Close()
	datos, err := io.ReadAll(io.LimitReader(resp.Body, maxCobaltRespuesta))
	if err != nil {
		return "", "", fmt.Errorf("cobalt: respuesta ilegible: %w", err)
	}
	if resp.StatusCode >= 400 {
		return "", "", fmt.Errorf("cobalt: la instancia respondió %d", resp.StatusCode)
	}
	var r respuestaCobalt
	if err := json.Unmarshal(datos, &r); err != nil {
		return "", "", fmt.Errorf("cobalt: respuesta ilegible")
	}
	switch r.Status {
	case "tunnel", "redirect":
		if r.URL == "" {
			return "", "", fmt.Errorf("cobalt: la instancia no devolvió enlace")
		}
		return r.URL, r.Filename, nil
	case "error":
		// La instancia contesta 200 con el error adentro: se traduce el
		// código tal cual para poder diagnosticar sin adivinar.
		return "", "", fmt.Errorf("cobalt: %s", r.Error.Code)
	default:
		// picker / local-processing: la instancia pide algo del navegador
		// que la app no puede dar.
		return "", "", fmt.Errorf("cobalt: la instancia pidió intervención (%s)", r.Status)
	}
}
