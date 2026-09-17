// ─────────────────────────────────────────────────────────────
// manifiesto.go — Lectura del manifiesto DASH de Tidal: pide la URL del MPD
// y extrae lo necesario para bajar el audio (segmento inicial, plantilla de
// segmentos y cuántos son).
//
// Por qué DASH: Tidal no sirve un archivo, sirve un manifiesto con el audio
// partido en segmentos (~4 s cada uno). Cada segmento es MP4 fragmentado con
// los frames FLAC crudos adentro (ver mp4_flac.go); el segmento inicial
// trae los bloques de metadata FLAC (STREAMINFO).
//
// Se conecta con: client.go (pedir) y descarga.go (que los consume).
// Parte del flujo: descarga (rescate de FLAC exacto).
// ─────────────────────────────────────────────────────────────

package tidalhifi

import (
	"fmt"
	"html"
	"net/url"
	"regexp"
	"strconv"
	"strings"
)

// planDescribe es lo que hace falta para bajar la canción entera.
type planDescarga struct {
	inicial      string   // URL del segmento de inicialización (metadata FLAC)
	plantilla    string   // URL de segmentos con $Number$ / $Time$
	segmentos    []string // URLs ya resueltas, en orden
	formato      string   // FLAC, ALAC…
	mpdURL       string
	durTotalMs   int
	esSinPerdida bool
}

var (
	reInicializacion = regexp.MustCompile(`initialization="([^"]+)"`)
	rePlantilla      = regexp.MustCompile(`media="([^"]+)"`)
	reRepresentacion = regexp.MustCompile(`Representation id="([^"]+)"`)
	reSegmento       = regexp.MustCompile(`<S\b([^>]*)/?>`)
	reAtributo       = regexp.MustCompile(`([a-zA-Z]+)="([^"]*)"`)
	reDuracionMPD    = regexp.MustCompile(`mediaPresentationDuration="PT((?:\d+M)?(?:\d+\.?\d*S)?)"`)
)

// pedirPlan pide el manifiesto de una pista y devuelve el plan de descarga.
//
// quality puede ser LOSSLESS (FLAC 44,1 kHz), HI_RES_LOSSLESS (hasta 24/192)
// o HIGH. Se pide el sin pérdida primero y se cae a HIGH si no existe, para
// no dejar la canción sin nada cuando el catálogo no la tiene en FLAC.
func (c *Client) pedirPlan(trackID, quality string) (planDescarga, error) {
	if quality == "" {
		quality = "LOSSLESS"
	}
	var ultimo error
	for _, q := range calidadesAProbar(quality) {
		var respuesta struct {
			Data struct {
				Atributos struct {
					URI     string   `json:"uri"`
					Formats []string `json:"formats"`
				} `json:"attributes"`
			} `json:"data"`
		}
		if err := c.pedir("/manifests?id="+url.QueryEscape(trackID)+"&quality="+q, &respuesta); err != nil {
			ultimo = err
			continue
		}
		if respuesta.Data.Atributos.URI == "" {
			ultimo = fmt.Errorf("tidal-hifi: el manifiesto no trajo URL (%s)", q)
			continue
		}
		plan, err := c.leerMPD(respuesta.Data.Atributos.URI, respuesta.Data.Atributos.Formats)
		if err != nil {
			ultimo = err
			continue
		}
		return plan, nil
	}
	if ultimo == nil {
		ultimo = fmt.Errorf("tidal-hifi: sin manifiesto")
	}
	return planDescarga{}, ultimo
}

// calidadesAProbar arma la cascada de calidades: lo pedido y, si era sin
// pérdida, la degradación a HIGH (equivalente a MP3 320) como último recurso.
func calidadesAProbar(quality string) []string {
	switch strings.ToUpper(strings.TrimSpace(quality)) {
	case "HIGH":
		return []string{"HIGH"}
	case "HI_RES_LOSSLESS":
		return []string{"HI_RES_LOSSLESS", "LOSSLESS", "HIGH"}
	default:
		return []string{"LOSSLESS", "HIGH"}
	}
}

// leerMPD baja el manifiesto y arma el plan de descarga.
func (c *Client) leerMPD(mpdURL string, formatos []string) (planDescarga, error) {
	cuerpo, err := c.pedirCrudo(mpdURL)
	if err != nil {
		return planDescarga{}, fmt.Errorf("tidal-hifi: no se pudo leer el manifiesto: %v", err)
	}
	return analizarMPD(string(cuerpo), formatos, mpdURL)
}

// analizarMPD interpreta el XML del manifiesto. Es una función pura para
// poder fijarla con un test sin salir a la red.
func analizarMPD(xml string, formatos []string, mpdURL string) (planDescarga, error) {
	xml = html.UnescapeString(xml)
	inicial := reInicializacion.FindStringSubmatch(xml)
	plantilla := rePlantilla.FindStringSubmatch(xml)
	if inicial == nil || plantilla == nil {
		return planDescarga{}, fmt.Errorf("tidal-hifi: manifiesto sin plantilla de segmentos")
	}
	plan := planDescarga{
		inicial:    html.UnescapeString(inicial[1]),
		plantilla:  html.UnescapeString(plantilla[1]),
		mpdURL:     mpdURL,
		durTotalMs: duracionDelMPD(xml),
	}
	for _, f := range formatos {
		if strings.EqualFold(f, "FLAC") || strings.EqualFold(f, "ALAC") {
			plan.esSinPerdida = true
			plan.formato = strings.ToUpper(f)
		}
	}
	if plan.formato == "" {
		if m := reRepresentacion.FindStringSubmatch(xml); m != nil {
			plan.formato = strings.ToUpper(strings.Split(m[1], ",")[0])
			plan.esSinPerdida = strings.Contains(plan.formato, "FLAC") ||
				strings.Contains(plan.formato, "ALAC")
		}
	}
	plan.segmentos = urlDeSegmentos(xml, plan.plantilla)
	if len(plan.segmentos) == 0 {
		return planDescarga{}, fmt.Errorf("tidal-hifi: el manifiesto no tiene segmentos")
	}
	return plan, nil
}

// urlDeSegmentos resuelve la plantilla con la lista de segmentos del
// SegmentTimeline, respetando los atributos r (repeticiones) y d (duración).
func urlDeSegmentos(xml, plantilla string) []string {
	var salida []string
	// El número de segmento arranca en startNumber (1 si no viene).
	numero := 1
	if m := regexp.MustCompile(`startNumber="(\d+)"`).FindStringSubmatch(xml); m != nil {
		if n, err := strconv.Atoi(m[1]); err == nil {
			numero = n
		}
	}
	timeline := regexp.MustCompile(`(?s)<SegmentTimeline>(.*?)</SegmentTimeline>`).FindStringSubmatch(xml)
	if timeline == nil {
		return nil
	}
	for _, bloque := range reSegmento.FindAllStringSubmatch(timeline[1], -1) {
		atributos := map[string]string{}
		for _, a := range reAtributo.FindAllStringSubmatch(bloque[1], -1) {
			atributos[a[1]] = a[2]
		}
		repeticiones := 0
		if v, err := strconv.Atoi(atributos["r"]); err == nil {
			repeticiones = v
		}
		// r es "repeticiones de la MISMA duración": r=44 son 45 segmentos.
		for i := 0; i <= repeticiones; i++ {
			url := plantilla
			if strings.Contains(url, "$Number$") {
				url = strings.ReplaceAll(url, "$Number$", strconv.Itoa(numero))
			}
			if strings.Contains(url, "$Time$") {
				url = strings.ReplaceAll(url, "$Time$", atributos["t"])
			}
			salida = append(salida, url)
			numero++
		}
	}
	return salida
}

// duracionDelMPD lee la duración declarada (PT3M3.685S → 183685 ms).
func duracionDelMPD(xml string) int {
	m := reDuracionMPD.FindStringSubmatch(xml)
	if m == nil {
		return 0
	}
	total := 0
	for _, parte := range regexp.MustCompile(`\d+\.?\d*[MS]`).FindAllString(m[1], -1) {
		valor := strings.TrimRight(parte, "MS")
		f, err := strconv.ParseFloat(valor, 64)
		if err != nil {
			continue
		}
		switch parte[len(parte)-1] {
		case 'M':
			total += int(f * 60000)
		case 'S':
			total += int(f * 1000)
		}
	}
	return total
}
