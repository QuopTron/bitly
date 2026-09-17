// ─────────────────────────────────────────────────────────────
// orchestrator_mejora_flac.go — Mejora silenciosa a FLAC: cuando una
// descarga termina en un formato con pérdida y el usuario pidió sin
// pérdida, un worker propio busca el FLAC real y reemplaza el archivo.
//
// Por qué así: pedirle al usuario que espere al sin pérdida retrasa
// cada descarga; pedirle el FLAC a la carrera original la degradaba a
// la fuente más rápida. Acá lo urgente (tener la canción) no cambia y
// la calidad llega después, sin bloquear nada.
//
// El archivo nuevo se publica con el MISMO itemID en el tracker: la
// app ve el path actualizado en su próximo poll y re-apunta la fila de
// la BD y el reproductor (ver descargas_poll_completado.dart).
//
// Se conecta con: mejora_flac.go (decisiones puras),
// orchestrator_mejora_flac_bajar.go (bajada y reemplazo),
// orchestrator_download.go (hook) y el tracker de progreso.
// Parte del flujo: descargas (después de entregar).
// ─────────────────────────────────────────────────────────────

package download

import (
	"fmt"
	"log"
	"os"
	"path/filepath"
	"time"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

const (
	// capacidadMejoraFLAC acota la cola: un álbum grande no debe acumular
	// trabajo infinito en memoria; lo que sobra se descarta (la canción queda
	// en su formato actual, que ya se entregó).
	capacidadMejoraFLAC = 24
	// presupuestoMejoraFLAC es lo máximo que puede tardar UNA canción entre
	// todas las fuentes sin pérdida. Es trabajo de fondo: si no aparece, se
	// abandona sin consecuencias.
	presupuestoMejoraFLAC = 40 * time.Second
	// toleranciaDuracionMejoraMS: cuánto puede diferir el FLAC de la duración
	// del catálogo. Más que esto es otra grabación (directo, corte, remix).
	toleranciaDuracionMejoraMS = 4000
)

// trabajoMejoraFLAC es una canción ya entregada, candidata a mejorarse.
type trabajoMejoraFLAC struct {
	req        Request
	outDir     string
	rutaActual string
	ganador    string
}

// solicitarMejoraFLAC encola la búsqueda del sin pérdida de una descarga
// recién terminada. Nunca bloquea: el worker arranca una sola vez y una cola
// llena descarta el trabajo (la canción ya está entregada).
func (o *Orchestrator) solicitarMejoraFLAC(req Request, outDir string, res *Result) {
	ok, razon := debeMejorarSinPerdida(req, res)
	if !ok {
		log.Printf("[mejora-flac] %q: no aplica (%s)", req.Title, razon)
		return
	}
	if _, err := os.Stat(res.FilePath); err != nil {
		log.Printf("[mejora-flac] %q: el archivo entregado no está en disco: %v", req.Title, err)
		return
	}
	o.mejoraOnce.Do(func() {
		if o.mejoraCh == nil {
			o.mejoraCh = make(chan trabajoMejoraFLAC, capacidadMejoraFLAC)
		}
		go o.cicloMejoraFLAC()
	})
	trabajo := trabajoMejoraFLAC{
		req:        req,
		outDir:     outDir,
		rutaActual: res.FilePath,
		ganador:    res.Provider,
	}
	select {
	case o.mejoraCh <- trabajo:
		log.Printf(
			"[mejora-flac] %q en cola: %s by %s, se busca el sin pérdida en segundo plano",
			req.Title, filepath.Ext(res.FilePath), res.Provider,
		)
	default:
		log.Printf("[mejora-flac] %q: cola llena, se queda en %s", req.Title, filepath.Ext(res.FilePath))
	}
}

// cicloMejoraFLAC consume la cola de a una: es trabajo de fondo, compite con
// las descargas reales por red y CPU, así que no se paraleliza.
func (o *Orchestrator) cicloMejoraFLAC() {
	for trabajo := range o.mejoraCh {
		o.intentarMejoraFLAC(trabajo)
	}
}

// intentarMejoraFLAC prueba las fuentes sin pérdida en orden y reemplaza el
// archivo con el primer FLAC válido. Registra el motivo de cada fallo: sin eso
// "no se encontró FLAC" no dice nada.
func (o *Orchestrator) intentarMejoraFLAC(t trabajoMejoraFLAC) {
	fin := time.Now().Add(presupuestoMejoraFLAC)
	var motivos []string
	for _, name := range proveedoresFLACMejora {
		if time.Now().After(fin) {
			motivos = append(motivos, name+": sin presupuesto")
			break
		}
		p := o.providers.Get(name)
		if p == nil {
			motivos = append(motivos, name+": no registrado")
			continue
		}
		if ep, ok := p.(*provider.ExtensionProvider); ok && !ep.DownloadCapable() {
			motivos = append(motivos, name+": no puede entregar audio")
			continue
		}
		if cooldown.IsCooledOp(name, downloadCooldownOp) {
			motivos = append(motivos, name+": en enfriamiento")
			continue
		}
		ruta, err := o.bajarFLACDe(t, name, p)
		if err != nil {
			motivos = append(motivos, fmt.Sprintf("%s: %v", name, err))
			continue
		}
		if err := o.reemplazarPorFLAC(t, ruta, name); err != nil {
			motivos = append(motivos, fmt.Sprintf("%s: %v", name, err))
			continue
		}
		log.Printf("[mejora-flac] ✔ %q ahora en FLAC (%s)", t.req.Title, name)
		return
	}
	log.Printf("[mejora-flac] ✖ %q se queda en %s (%v)", t.req.Title, filepath.Ext(t.rutaActual), motivos)
}
