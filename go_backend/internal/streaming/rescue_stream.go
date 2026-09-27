package streaming

import (
	"log"
	"sync"
	"time"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// rescueStream busca un stream URL en TODOS los providers que streamean.
// Los intentos por ISRC y por nombre corren en PARALELO entre providers con
// ventanas acotadas, de modo que un provider lento (captcha/sesión fría/429)
// ya no suma su tiempo a cada provider posterior — el más rápido gana en
// segundos en vez de arrastrar 60-100s como el walk serial anterior.
// [verified] reports that a provider HAS the exact track but needs its signed
// session to stream it — the caller fails fast on that verdict.
// duracionQuery devuelve la duración consultada en ms (0 si no la conocemos),
// para que el ranking por nombre pueda desempatar versiones de la misma
// canción cuando la fuente no expone ISRC.
func duracionQuery(track *provider.TrackResult) int {
	if track == nil || track.Duration <= 0 {
		return 0
	}
	return track.Duration
}

// albumQuery devuelve el álbum del pedido cuando se conoce ("" si no). El
// ranking por nombre lo usa para preferir la toma del disco pedido: la misma
// canción vive en el álbum original, en un recopilatorio y en un "remix album",
// y sin este dato podía sonar la versión de otro disco.
func albumQuery(track *provider.TrackResult) string {
	if track == nil {
		return ""
	}
	return track.Album
}

// [identidadProbada] reporta que la identidad del pedido (ISRC / ids
// cross-proveedor) YA se resolvió contra las fuentes de audio antes de entrar
// acá — es la fase de identificadores de RescueStreamURL. En ese caso la fase
// exacta no se repite salvo que un ISRC NUEVO llegue derivado en vuelo (ese dato
// no existía cuando se sondeó), para no duplicar carga ni disparar 429s.
func rescueStream(reg *provider.Registry, track *provider.TrackResult, trackName, artistName, quality string, identidadProbada bool) (url, prov string, attempted []string, verified bool) {
	inicioTotal := time.Now()
	// Instrumentación de LATENCIA: cada fase termina cuando vence su presupuesto
	// o cuando TODOS sus workers terminan, así que el total percibido es la SUMA
	// de las fases. Sin estos números no se puede saber qué fase se come los
	// segundos (ver el log del usuario: 24s de punta a punta).
	defer func() {
		log.Printf("[rescue] TOTAL %.0fms -> prov=%q url=%v verified=%v",
			float64(time.Since(inicioTotal).Microseconds())/1000, prov, url != "", verified)
	}()
	// Fuentes sin ISRC (YouTube, SoundCloud, re-subidos): derivar el ISRC de un
	// catálogo que SÍ lo publica habilita la fase exacta por ISRC y el rescate
	// FLAC, sin pedirle nada al usuario y sin sesión. Es best-effort y cacheado.
	//
	// Corre EN PARALELO con las búsquedas: antes era un paso SERIAL de hasta 4s
	// que se ejecutaba ANTES de que arrancara cualquier fase, así que un track sin
	// ISRC pagaba esos segundos enteros en cada tap. Cuando el ISRC llega, habilita
	// la fase exacta en pleno vuelo; si la búsqueda por nombre ya trajo el audio,
	// no se espera nunca (ver el cosechador de fases).
	chISRC := make(chan string, 1)
	rastreandoISRC := false
	if track != nil && track.ISRC == "" && trackName != "" && artistName != "" {
		rastreandoISRC = true
		dur := duracionQuery(track)
		go func() { chISRC <- provider.DerivarISRC(reg, trackName, artistName, dur) }()
	}
	// El ISRC con el que se resuelve la fase EXACTA puede llegar DESPUÉS (derivado
	// en vuelo) y lo leen dos goroutines: la búsqueda por nombre —para preferir el
	// candidato de la MISMA grabación— y la fase exacta al lanzarse. Se guarda
	// bajo mutex en vez de reasignar `track`: aquel `track = &copia` era una
	// carrera de datos real contra la goroutine de nombre, que leía el puntero a
	// la vez que el colector lo reemplazaba.
	var isrcMu sync.RWMutex
	isrcActual := ""
	if track != nil {
		isrcActual = track.ISRC
	}
	leerISRC := func() string {
		isrcMu.RLock()
		defer isrcMu.RUnlock()
		return isrcActual
	}
	fijarISRC := func(v string) {
		isrcMu.Lock()
		isrcActual = v
		isrcMu.Unlock()
	}
	// Sin pérdida, las fuentes que pueden entregarlo van primero (y con un turno
	// extra): el orden decide quién ARRANCA primero, y con menos turnos que fuentes
	// eso decide quién alcanza a entregar antes de que la fase devuelva. Ver
	// ordenProvidersStreamingCalidad.
	names := ordenProvidersStreamingCalidad(reg, quality)
	// Un proveedor que tiene la cancion exacta pero necesita su sesion
	// verificada se RECUERDA, nunca es fatal: la siguiente fase (busqueda por
	// nombre) aun puede encontrar la cancion en un proveedor que no indexa
	// ISRC (p. ej. youtube). El veredicto de verificacion solo se devuelve
	// cuando NINGUNA fase produjo un stream.
	var verifyName string

	// LA BÚSQUEDA POR NOMBRE ARRANCA YA, EN PARALELO CON LA FASE EXACTA.
	//
	// Por qué ahora sí, si una versión anterior de esto se revirtió: aquella
	// carrera recorría ~14 proveedores, catálogos incluidos, y solaparla duplicaba
	// la carga sobre las extensiones —medido en el emulador: metadata 2,2s →
	// 5,8-11,2s y stream 12,6s → 17-20s—. Con los catálogos FUERA del audio (ver
	// proveedoresAudio) quedan pocas fuentes reales y cada una sabe resolver la
	// identidad por su cuenta (checkAvailability / índice ISRC), así que la fase
	// exacta ya no compite por los mismos proveedores: reparte.
	//
	// Y es necesario, no un lujo: sin solapar, la fase por ISRC corría ANTES de
	// que YouTube —la fuente de audio obligatoria— tuviera su primer turno.
	// Medido: 12,59s de punta a punta, con la fase de nombre arrancando recién a
	// los ~4s.
	type resultadoFase struct {
		url    string
		prov   string
		verify bool
	}
	chNombre := make(chan resultadoFase, 1)
	if trackName != "" && artistName != "" {
		go func() {
			inicioFase := time.Now()
			u, provName, v := carreraPorConfianzaCalidad(reg, names, 20*time.Second, 4, func(name string, p provider.Provider) (string, bool) {
				results, err := p.SearchTracks(trackName+" "+artistName, 8)
				if err != nil || len(results) == 0 {
					return "", false
				}
				cands := matchesRankeados(trackName, artistName, albumQuery(track), duracionQuery(track), results)
				// Con ISRC conocido, la candidata que lo declara va primero: entre
				// subidas con el mismo título, la que coincide con la identidad
				// exacta es la grabación pedida. Se lee del holder porque el ISRC
				// puede haber llegado mientras esta búsqueda corría.
				if isr := leerISRC(); isr != "" {
					cands = provider.PreferirISRC(isr, cands)
				}
				var sawVerify bool
				for _, cand := range cands {
					candURL, cv := rescueProviderUnaVez(p, cand.ID, quality)
					if cv {
						sawVerify = true
						continue
					}
					if candURL != "" {
						// Instrumentación de LATENCIA: el momento en que el proveedor
						// RESOLVIÓ el stream, no el momento en que la fase lo devolvió.
						// La diferencia entre ambos es lo que se pasó esperando la
						// gracia de una fuente sin pérdida — sin este número no se puede
						// distinguir "yt-dlp llegó tarde" de "yt-dlp llegó y lo
						// retuvimos esperando un FLAC".
						log.Printf("[rescue] fase 2: %s resolvió en %.0fms (id=%s)",
							name, float64(time.Since(inicioFase).Microseconds())/1000, cand.ID)
						return candURL, false
					}
				}
				if sawVerify {
					return "", true
				}
				return "", false
			}, quality)
			log.Printf("[rescue] fase 2 (nombre) %.0fms -> prov=%q url=%v verify=%v",
				float64(time.Since(inicioFase).Microseconds())/1000, provName, u != "", v)
			chNombre <- resultadoFase{u, provName, v}
		}()
	}

	// FASE DEL VIDEO OFICIAL: arranca ya, en paralelo, y solo se la espera al
	// final cuando NINGUNA otra fase consiguió audio (ver más abajo). Es la
	// salida cuando la búsqueda por nombre no confirma la canción: el id
	// oficial no busca, resuelve.
	chVideo := make(chan resultadoFase, 1)
	if trackName != "" && artistName != "" {
		go func() {
			u, provName := faseVideoOficial(reg, track, trackName, artistName, quality)
			chVideo <- resultadoFase{url: u, prov: provName}
		}()
	}

	// FASE 1: la GRABACIÓN EXACTA por IDENTIDAD (ISRC, y los ids cross-proveedor
	// cuando el pedido los trae). La atienden TODAS las fuentes de audio que sepan
	// traducir esa identidad a un id propio: una extensión lo hace por su
	// checkAvailability —YTMusic resuelve el ISRC al video de YouTube Music
	// verificado por título/artista/duración, que es el audio que sí existe— y
	// flac-rescue por su índice, que ES el ISRC. Antes esta fase ERA solo
	// GetTrackByISRC, así que en la práctica únicamente flac-rescue podía
	// contestar y un track sin ISRC propio (YouTube/SoundCloud) se quedaba sin la
	// fuente que mejor lo tiene. Ver rescue_identidad.go.
	//
	// Por eso el presupuesto sigue siendo de 3s: si una fuente tiene la grabación
	// la resuelve en 1-2s, y si no, esperar más solo retrasa lo que la fase de
	// nombre (que corre en paralelo) ya tiene listo. Un resultado exacto sigue
	// ganando: es identidad, no parecido.
	//
	// Se lanza en su PROPIA goroutine para poder COSECHARLA junto a la fase de
	// nombre: antes se esperaba la fase 1 COMPLETA —hasta 3s— antes de mirar la
	// otra, así que un tema que el canal exacto no tiene pagaba el presupuesto
	// entero aunque el stream ya estuviera servido (medido: 3s de un tap de 3,7s).
	chExacto := make(chan resultadoFase, 1)
	exactoLanzado, exactoPendiente := false, false
	// ¿El ISRC que habilita la fase exacta llegó DERIVADO en vuelo? Solo entonces
	// la fase exacta aporta algo que la fase de identificadores no pudo probar.
	isrcDeDerivacion := false
	lanzarFaseExacta := func() {
		if exactoLanzado {
			return
		}
		isrcExacto := leerISRC()
		if isrcExacto == "" {
			return
		}
		if identidadProbada && !isrcDeDerivacion {
			return
		}
		exactoLanzado, exactoPendiente = true, true
		// La identidad completa (ISRC + ids cross-proveedor + título/artista +
		// duración) se arma ACÁ, en la goroutine del llamador, y se pasa por
		// valor: la resolución por identidad de cada fuente corre en paralelo y
		// no toca el estado compartido.
		ident := identidadDeTrack(track, trackName, artistName)
		ident.isrc = isrcExacto
		go func() {
			inicioFase := time.Now()
			// Presupuesto 4s (antes 3s): la fase ahora también pasa por
			// checkAvailability de las extensiones, que resuelve el ISRC a su
			// propio id con una búsqueda — negarle ese segundo dejaba afuera a la
			// fuente que sí lo tiene. No alarga el caso exitoso (el colector sirve
			// el primero que llegue) ni el fallido (lo domina la fase de nombre).
			u, provName, v := carreraPorConfianzaCalidad(reg, names, 4*time.Second, workersRescate(quality), func(name string, p provider.Provider) (string, bool) {
				// Antes esto ERA solo GetTrackByISRC, así que en la práctica
				// únicamente flac-rescue podía contestar por ISRC. Ahora toda
				// fuente que sepa traducir la identidad lo intenta primero por su
				// checkAvailability (YTMusic resuelve el ISRC al video verificado)
				// y el resto cae a GetTrackByISRC. Ver rescue_identidad.go.
				return resolverStreamPorIdentidad(p, quality, ident)
			}, quality)
			log.Printf("[rescue] fase 1 (identidad exacta) %.0fms -> prov=%q url=%v verify=%v",
				float64(time.Since(inicioFase).Microseconds())/1000, provName, u != "", v)
			chExacto <- resultadoFase{u, provName, v}
		}()
	}
	lanzarFaseExacta()

	// COSECHADOR: gana la primera fase que consiga una URL. Un veredicto de
	// verificación (sesión firmada pendiente) se RECUERDA sin cortar nada — la otra
	// fase todavía puede hacer sonar la canción. Solo se sigue esperando mientras
	// quede alguna fuente viva: si la derivación del ISRC todavía corre, de ella
	// puede nacer la fase exacta (y con ella el FLAC), pero si la búsqueda por
	// nombre ya trajo el audio se sale sin esperarla.
	nombrePendiente := trackName != "" && artistName != ""
	urlFinal, provFinal := "", ""
	for urlFinal == "" && (exactoPendiente || nombrePendiente || rastreandoISRC) {
		select {
		case r := <-chExacto:
			exactoPendiente = false
			if r.verify && verifyName == "" {
				verifyName = r.prov
			}
			if r.url != "" {
				urlFinal, provFinal = r.url, r.prov
			} else {
				attempted = append(attempted, names...)
			}
		case r := <-chNombre:
			nombrePendiente = false
			if r.verify && verifyName == "" {
				verifyName = r.prov
			}
			if r.url != "" {
				urlFinal, provFinal = r.url, r.prov
			} else {
				attempted = append(attempted, names...)
			}
		case derivado := <-chISRC:
			rastreandoISRC = false
			if derivado != "" && leerISRC() == "" {
				fijarISRC(derivado)
				isrcDeDerivacion = true
				// El ISRC habilita la fase exacta (y el rescate FLAC) en pleno vuelo.
				lanzarFaseExacta()
			}
		}
	}
	if urlFinal != "" {
		return urlFinal, provFinal, nil, false
	}
	// Última oportunidad antes de declarar el fallo: el video OFICIAL de la
	// pista. Ya viene corriendo desde el arranque, así que en el caso normal ya
	// está listo; la gracia acota lo que puede sumar (la pausa del cliente de
	// Last.fm). Un video oficial es identidad, no parecido: entra aunque las
	// fases por nombre hayan fallado.
	if trackName != "" && artistName != "" {
		select {
		case r := <-chVideo:
			if r.url != "" {
				return r.url, r.prov, nil, false
			}
		case <-time.After(esperaVideoOficial):
			log.Printf("[rescue] video oficial: sin respuesta en %.0fs", esperaVideoOficial.Seconds())
		}
	}
	if verifyName != "" {
		return "", verifyName, attempted, true
	}
	return "", "", attempted, false
}
