// ─────────────────────────────────────────────────────────────
// orchestrator_mejora_flac_bajar.go — Bajada del FLAC de la mejora:
// arma las URLs candidatas (SITIOS RASPABLES primero, contrato de
// espejos después), baja la primera que pase la validación y reemplaza
// el archivo con pérdida.
//
// Por qué los sitios primero: los espejos con contrato se quedaron sin
// cuentas vivas y el canal Qobuz firmado devuelve una muestra de 30 s
// sin token de suscriptor, así que el contrato de espejos hoy casi nunca
// da audio. Los sitios raspables (superflac) entregan el FLAC real sin
// cuenta en unos segundos.
//
// Se conecta con: mejora_flac.go y orchestrator_mejora_flac.go.
// Parte del flujo: descargas (después de entregar).
// ─────────────────────────────────────────────────────────────

package download

import (
	"fmt"
	"os"
	"strings"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// resolutorSitioFLAC lo implementa flac-rescue: resuelve el enlace del FLAC
// REAL en sitios raspables que no piden cuenta. SOLO PARA DESCARGAR: sus
// enlaces son el archivo completo y no soportan peticiones por rango, así que
// usarlos como stream obligaría a bajar la canción entera antes de oírla.
type resolutorSitioFLAC interface {
	ResolverSitioFLAC(isrc, titulo, artista string, durMS int, formato string) (string, string, error)
}

// urlFLAC es una URL candidata con el origen que la propuso (para el log) y si
// es de UN SOLO USO (los sitios raspables firman un enlace que se consume con la
// primera petición, así que no se puede sondear ni reanudar).
type urlFLAC struct {
	origen    string
	url       string
	soloUnUso bool
}

// bajarFLACDe resuelve la canción en [name] y baja el archivo sin pérdida ya
// validado (FLAC de verdad y de la duración pedida).
func (o *Orchestrator) bajarFLACDe(t trabajoMejoraFLAC, name string, p provider.Provider) (string, error) {
	// Soulseek trae el archivo él mismo y ya verifica duración/calidad.
	if d, ok := p.(descargadorPropio); ok {
		id, _, _ := resolverTrackIDProvider(p, name, t.req)
		if id == "" {
			return "", fmt.Errorf("no se pudo identificar la canción")
		}
		destino, err := d.DescargarAArchivo(id, "FLAC", t.outDir, t.req.DurationMS/1000)
		if err != nil {
			return "", err
		}
		if ok, motivo := esFLACSinPerdida(destino); !ok {
			_ = os.Remove(destino)
			return "", fmt.Errorf("%s", motivo)
		}
		return destino, nil
	}

	candidatas, motivos := o.urlsFLACCandidatas(t, name, p)
	for _, candidata := range candidatas {
		ruta, err := o.descargarFLACValidado(t, candidata)
		if err != nil {
			motivos = append(motivos, candidata.origen+": "+err.Error())
			continue
		}
		return ruta, nil
	}
	if len(motivos) == 0 {
		motivos = append(motivos, "sin fuentes que consultar")
	}
	return "", fmt.Errorf("%s", strings.Join(motivos, "; "))
}

// urlsFLACCandidatas arma, en orden de intento, los enlaces que pueden entregar
// el sin pérdida de esta canción, junto con los motivos de los canales que ya
// fallaron antes de bajar nada (para que el log diga POR QUÉ no hubo FLAC).
func (o *Orchestrator) urlsFLACCandidatas(t trabajoMejoraFLAC, name string, p provider.Provider) ([]urlFLAC, []string) {
	var candidatas []urlFLAC
	var motivos []string

	// 1) Sitios raspables (flac-rescue los implementa). Necesitan el título y
	// el artista del catálogo: son la única forma de confirmar que el sitio
	// devolvió la canción pedida, porque busca por texto y no por ISRC.
	if sitios, ok := p.(resolutorSitioFLAC); ok {
		switch {
		case t.req.ISRC == "":
			motivos = append(motivos, "sitios: sin ISRC con el que buscar")
		default:
			url, sitio, err := sitios.ResolverSitioFLAC(t.req.ISRC, t.req.Title, t.req.Artist, t.req.DurationMS, "FLAC")
			if err != nil || url == "" {
				motivos = append(motivos, fmt.Sprintf("sitios: %v", err))
			} else {
				candidatas = append(candidatas, urlFLAC{origen: "sitio " + sitio, url: url, soloUnUso: true})
			}
		}
	}

	// 2) Contrato de espejos / Qobuz firmado del propio provider.
	id, _, _ := resolverTrackIDProvider(p, name, t.req)
	if id == "" {
		motivos = append(motivos, "espejos: no se pudo identificar la canción")
		return candidatas, motivos
	}
	url, err := p.GetStreamURL(id, "FLAC")
	if err != nil || url == "" {
		motivos = append(motivos, fmt.Sprintf("espejos: %v", err))
		return candidatas, motivos
	}
	return append(candidatas, urlFLAC{origen: "espejos", url: url}), motivos
}

// descargarFLACValidado baja [url] y solo la devuelve si el archivo es un FLAC
// de verdad y de la duración esperada. Un archivo rechazado se borra: dejarlo
// sería basura en la carpeta del usuario.
func (o *Orchestrator) descargarFLACValidado(t trabajoMejoraFLAC, candidata urlFLAC) (string, error) {
	if candidata.url == "" {
		return "", fmt.Errorf("sin enlace")
	}
	// Varias fuentes devuelven "algo reproducible" cuando el sin pérdida no
	// existe (Internet Archive cae a su derivado MP3). Bajarlo para después
	// rechazarlo gasta megas y tiempo: si la propia URL delata un formato con
	// pérdida, esta fuente no tiene el FLAC.
	if promete, motivo := urlPrometeSinPerdida(candidata.url); !promete {
		return "", fmt.Errorf("%s", motivo)
	}
	// sondear=false en los enlaces de un solo uso: sondear (Range) los consume.
	ruta, err := descargarAArchivoCon(candidata.url, t.outDir, t.req, t.req.Title,
		t.req.Artist, nil, !candidata.soloUnUso)
	if err != nil {
		return "", err
	}
	if ok, motivo := esFLACSinPerdida(ruta); !ok {
		_ = os.Remove(ruta)
		return "", fmt.Errorf("%s", motivo)
	}
	if t.req.DurationMS > 0 {
		if ms := duracionFLACMs(ruta); ms > 0 &&
			abs(ms-t.req.DurationMS) > toleranciaDuracionMejoraMS {
			_ = os.Remove(ruta)
			return "", fmt.Errorf("la duración no coincide (%dms vs %dms)", ms, t.req.DurationMS)
		}
	}
	return ruta, nil
}
