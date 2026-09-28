// ─────────────────────────────────────────────────────────────
// orchestrator_mejora_flac_bajar.go — Bajada del FLAC de la mejora:
// arma las URLs candidatas (SITIOS RASPABLES y contrato de espejos a la
// vez), baja la primera validada y reemplaza el archivo con pérdida.
//
// Por qué los dos caminos van en PARALELO: son independientes y cada uno
// tiene su presupuesto (los sitios, hasta 45s). En serie, el que se
// quedaba sin cuentas arrastraba su espera completa al otro aunque el
// segundo ya tuviera el FLAC en la mano: el usuario veía "mejorando…"
// durante casi un minuto por una fuente muerta.
//
// Por qué ya no hay "sitios primero": los dos caminos terminan en un
// archivo VALIDADO (FLAC de verdad y de la duración pedida, ver
// descargarFLACValidado), así que el primero que llegue sirve. La
// preferencia histórica por los sitios era porque el contrato de espejos
// "casi nunca daba audio"; con el canal sin pérdida (stash/arcod) eso
// dejó de ser cierto.
//
// Se conecta con: mejora_flac.go y orchestrator_mejora_flac.go.
// Parte del flujo: descargas (después de entregar).
// ─────────────────────────────────────────────────────────────

package download

import (
	"fmt"
	"os"
	"strings"
	"sync"

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

// candidatasResueltas es lo que devuelve UN camino de resolución: los enlaces
// que propone y los motivos de los que ya fallaron antes de bajar nada (para
// que el log diga POR QUÉ no hubo FLAC).
type candidatasResueltas struct {
	candidatas []urlFLAC
	motivos    []string
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

	// Los dos caminos se resuelven A LA VEZ y cada uno se usa apenas llega: si
	// el de los sitios se quedó colgado esperando su cupo, el de los espejos
	// baja el FLAC igual, sin esperar a que el otro termine de rendirse.
	var motivos []string
	for resueltas := range resolverEnParalelo(
		func() candidatasResueltas { return o.candidatasSitios(t, p) },
		func() candidatasResueltas { return o.candidatasEspejos(t, name, p) },
	) {
		motivos = append(motivos, resueltas.motivos...)
		for _, candidata := range resueltas.candidatas {
			ruta, err := o.descargarFLACValidado(t, candidata)
			if err == nil {
				return ruta, nil
			}
			motivos = append(motivos, candidata.origen+": "+err.Error())
		}
	}
	if len(motivos) == 0 {
		motivos = append(motivos, "sin fuentes que consultar")
	}
	return "", fmt.Errorf("%s", strings.Join(motivos, "; "))
}

// resolverEnParalelo corre las [resoluciones] a la vez y entrega el resultado
// de cada una APENAS está, en el orden en que van llegando. El canal se cierra
// cuando terminaron todas: quien lo consume sabe que ya no va a llegar nada más
// (y así puede cortar apenas una le sirve, sin esperar a las lentas).
//
// Se asume a cambio que el camino que queda en vuelo NO se cancela (el contrato
// del resolutor no lleva contexto): termina solo, acotado por su propio
// presupuesto, y su resultado se descarta al cerrarse el canal. Es el precio de
// no hacer esperar la descarga al camino más lento, y el presupuesto de cada uno
// ya acota ese trabajo de más.
func resolverEnParalelo(resoluciones ...func() candidatasResueltas) <-chan candidatasResueltas {
	listos := make(chan candidatasResueltas, len(resoluciones))
	var wg sync.WaitGroup
	for _, resolucion := range resoluciones {
		wg.Add(1)
		go func(r func() candidatasResueltas) {
			defer wg.Done()
			listos <- r()
		}(resolucion)
	}
	go func() { wg.Wait(); close(listos) }()
	return listos
}

// candidatasSitios resuelve por los SITIOS raspables. Necesitan el título y el
// artista del catálogo: son la única forma de confirmar que el sitio devolvió la
// canción pedida, porque busca por texto y no por ISRC.
func (o *Orchestrator) candidatasSitios(t trabajoMejoraFLAC, p provider.Provider) candidatasResueltas {
	sitios, ok := p.(resolutorSitioFLAC)
	if !ok {
		return candidatasResueltas{}
	}
	if t.req.ISRC == "" {
		return candidatasResueltas{motivos: []string{"sitios: sin ISRC con el que buscar"}}
	}
	url, sitio, err := sitios.ResolverSitioFLAC(t.req.ISRC, t.req.Title, t.req.Artist, t.req.DurationMS, "FLAC")
	if err != nil || url == "" {
		return candidatasResueltas{motivos: []string{fmt.Sprintf("sitios: %v", err)}}
	}
	return candidatasResueltas{
		candidatas: []urlFLAC{{origen: "sitio " + sitio, url: url, soloUnUso: true}},
	}
}

// candidatasEspejos resuelve por el contrato de espejos / canal sin pérdida del
// propio provider (flac-rescue los reúne: Qobuz firmado, stash-relay, arcod y
// los espejos por ISRC).
func (o *Orchestrator) candidatasEspejos(t trabajoMejoraFLAC, name string, p provider.Provider) candidatasResueltas {
	id, _, _ := resolverTrackIDProvider(p, name, t.req)
	if id == "" {
		return candidatasResueltas{motivos: []string{"espejos: no se pudo identificar la canción"}}
	}
	url, err := p.GetStreamURL(id, "FLAC")
	if err != nil || url == "" {
		return candidatasResueltas{motivos: []string{fmt.Sprintf("espejos: %v", err)}}
	}
	return candidatasResueltas{candidatas: []urlFLAC{{origen: "espejos", url: url}}}
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
