package download

import (
	"log"
	"strings"
	"time"
)

// eventoCarrera es lo que reporta cada intento al bucle de la carrera: el
// Result de la descarga, o la señal de que el feeder ya no tiene más candidatos.
type eventoCarrera struct {
	res       *Result
	ultimoRec bool
	sinMas    bool
}

// consumeCandidates corre la carrera de descargas: mantiene hasta
// maxParallelDownloads intentos en vuelo y pide candidatos NUEVOS al feeder a
// medida que cada uno termina. Devuelve el primer Result exitoso (exacto),
// honra la ventana de gracia para las fuentes de último recurso y corta apenas
// falla la escritura en disco (ningún proveedor puede arreglar eso).
//
// Cada intento pide su candidato en su PROPIA goroutine: resolver el id del
// próximo proveedor puede tardar decenas de segundos (búsqueda web + token) y
// si eso se hiciera en el bucle, un ganador que ya escribió el archivo se
// quedaría esperando en la cola hasta que la resolución termine —era la razón
// por la que una descarga lista tardaba ~40s más en entregarse.
func (o *Orchestrator) consumeCandidates(f *candidatosFeeder, req Request, outDir string, st *fallbackState) *Result {
	salida := make(chan eventoCarrera, maxParallelDownloads)
	enVuelo := 0
	exactInFlight := 0
	agotado := false

	// lanzar arranca intentos hasta el tope. El candidato se resuelve dentro de
	// cada goroutine; si el feeder se quedó sin candidatos, avisa con sinMas.
	lanzar := func() {
		for enVuelo < maxParallelDownloads && !agotado {
			enVuelo++
			go func() {
				c, ok := f.siguiente()
				if !ok {
					salida <- eventoCarrera{sinMas: true}
					return
				}
				res := o.attemptDownload(req, c.name, c.p, c.trackID, c.title, c.artist, outDir)
				salida <- eventoCarrera{
					res:       res,
					ultimoRec: esProviderUltimoRecurso(c.name),
				}
			}()
			// exactInFlight cuenta los intentos que TODAVÍA podrían dar un resultado
			// exacto: al lanzar nadie sabe qué candidato tocará, así que suma acá y
			// resta cuando se sabe que ese intento es de último recurso (o que no
			// había candidato).
		}
	}

	lanzar()

	var lastResort *Result
	var graceCh <-chan time.Time
	var graceTimer *time.Timer
	detenerGracia := func() {
		if graceTimer != nil {
			graceTimer.Stop()
		}
	}

	// Presupuesto global: al expirar, la carrera no espera fuentes nuevas y
	// devuelve lo que haya (nunca deja el RPC colgado).
	restante := maxFallbackDuration - time.Since(st.fallbackStart)
	if restante <= 0 {
		restante = time.Second
	}
	budgetCh := time.After(restante)

	for {
		select {
		case ev := <-salida:
			enVuelo--
			if ev.sinMas {
				agotado = true
				exactInFlight--
				if enVuelo == 0 {
					detenerGracia()
					return lastResort
				}
				continue
			}
			if ev.ultimoRec {
				exactInFlight--
			}
			aceptar, corte := o.evaluarResultadoCarrera(ev.res, req, st, &lastResort)
			if aceptar != nil {
				detenerGracia()
				return aceptar
			}
			if corte {
				detenerGracia()
				return nil
			}
			if lastResort != nil && graceTimer == nil {
				if exactInFlight > 0 {
					// Hay una fuente exacta todavía en vuelo: se le da una
					// ventana corta para que gane la original.
					graceTimer = time.NewTimer(authorityGrace)
					graceCh = graceTimer.C
				} else {
					// Nada mejor en vuelo: no hay por qué esperar la gracia.
					detenerGracia()
					return lastResort
				}
			}
			lanzar()
		case <-graceCh:
			detenerGracia()
			return lastResort
		case <-budgetCh:
			detenerGracia()
			if lastResort != nil {
				return lastResort
			}
			log.Printf("[orchestrator] ⏰ presupuesto agotado con %d intento(s) en vuelo itemID=%q", enVuelo, req.ItemID)
			// Se espera lo que ya está corriendo: todavía puede ganar.
			for enVuelo > 0 {
				ev := <-salida
				enVuelo--
				if ev.sinMas || ev.res == nil {
					continue
				}
				if ev.res.Success && esDuracionPlausible(ev.res.FilePath, req.DurationMS) {
					return ev.res
				}
				o.registrarFalloCarrera(ev.res, st)
			}
			return nil
		}
	}
}

// evaluarResultadoCarrera decide qué hacer con un Result que llegó de un
// intento. Devuelve (resultado, false) cuando la carrera debe terminar con ese
// resultado; (nil, true) cuando debe terminar sin resultado (fallo de escritura
// ya reportado por el tracker) y (nil, false) cuando debe seguir corriendo.
func (o *Orchestrator) evaluarResultadoCarrera(
	res *Result,
	req Request,
	st *fallbackState,
	lastResort **Result,
) (*Result, bool) {
	if res == nil {
		return nil, false
	}
	if res.Success {
		// Una candidata que devolvió un preview/clip no cuenta como descarga:
		// se descarta y la carrera sigue con las demás fuentes (antes el usuario
		// quedaba con un archivo de 30s).
		if !esDuracionPlausible(res.FilePath, req.DurationMS) {
			st.lastErr = "preview/clip descartado de " + res.Provider
			st.registrarFallo(res.Provider, "preview/clip (duración no plausible)")
			log.Printf("[orchestrator] ⚠ %s: descartado por preview/clip itemID=%q", res.Provider, res.ItemID)
			return nil, false
		}
		if !esProviderUltimoRecurso(res.Provider) {
			return res, false
		}
		// Último recurso (búsqueda por nombre): puede ser un remix/edit de la
		// misma canción, así que no gana por llegar primero; se guarda y el
		// llamador decide si espera una fuente exacta.
		if *lastResort == nil {
			*lastResort = res
		}
		return nil, false
	}

	o.registrarFalloCarrera(res, st)
	// Un fallo de escritura en disco (sin espacio, permiso, read-only) no lo
	// arregla ningún proveedor: se corta la carrera de inmediato.
	if esFalloEscrituraAlmacenamiento(res.Error) {
		return nil, true
	}
	return nil, false
}

// registrarFalloCarrera acumula el motivo de una candidata fallida: alimenta el
// mensaje final (el que ve el usuario en el aviso de descarga) y el log de
// diagnóstico, que antes no existía.
func (o *Orchestrator) registrarFalloCarrera(res *Result, st *fallbackState) {
	if res.Error == "" {
		return
	}
	st.lastErr = res.Error
	log.Printf("[orchestrator] ✖ %s: itemID=%q type=%q err=%q", res.Provider, res.ItemID, res.ErrorType, res.Error)
	st.registrarFallo(res.Provider, res.Error)
	// La verificación requerida es el desenlace MÁS accionable (el proveedor
	// tiene la canción, solo hay que refrescar su sesión): se recuerda para que
	// un error genérico posterior no tape la señal.
	if res.ErrorType == "verification_required" || clasificarErrorVerificacion(res.Error) != "" {
		st.verificationSeen = true
	}
	if res.Service != "" {
		st.verificationService = res.Service
	}
	if strings.Contains(res.Error, "encriptado") {
		st.encryptedSeen = true
	}
}
