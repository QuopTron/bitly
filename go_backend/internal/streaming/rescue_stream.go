package streaming

import (
	"log"
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

func rescueStream(reg *provider.Registry, track *provider.TrackResult, trackName, artistName, quality string) (url, prov string, attempted []string, verified bool) {
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
	// FLAC, sin pedirle nada al usuario y sin sesión. Es best-effort y cacheado:
	// si no se confirma, todo sigue igual (búsqueda por nombre).
	if track != nil && track.ISRC == "" && trackName != "" && artistName != "" {
		if isrc := provider.DerivarISRC(reg, trackName, artistName, duracionQuery(track)); isrc != "" {
			copia := *track
			copia.ISRC = isrc
			track = &copia
		}
	}
	names := ordenProvidersStreaming(reg)
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
	// proveedoresAudio) quedan 6 fuentes reales y la fase exacta solo puede
	// aportar algo con flac-rescue, así que solapar ya no compite: reparte.
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
				cands := matchesRankeados(trackName, artistName, duracionQuery(track), results)
				// Con ISRC conocido, la candidata que lo declara va primero: entre
				// subidas con el mismo título, la que coincide con la identidad
				// exacta es la grabación pedida.
				if track != nil && track.ISRC != "" {
					cands = provider.PreferirISRC(track.ISRC, cands)
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

	// Phase 1: la GRABACIÓN EXACTA por ISRC. Ahora la atiende prácticamente solo
	// flac-rescue (su índice ES el ISRC): los catálogos salieron del audio, así
	// que ya no hay un deezer/qobuz que resuelva por ISRC sin cuenta.
	//
	// Por eso el presupuesto bajó de 8s a 3s: si flac-rescue tiene el FLAC lo
	// resuelve en 1-2s, y si no lo tiene, esperar más solo retrasa lo que la fase
	// de nombre (que corre en paralelo) ya tiene listo. Un resultado suyo sigue
	// ganando: es identidad exacta y sin pérdida.
	if track != nil && track.ISRC != "" {
		inicioFase := time.Now()
		u, provName, v := carreraPorConfianzaCalidad(reg, names, 3*time.Second, 2, func(name string, p provider.Provider) (string, bool) {
			trackByISRC, err := p.GetTrackByISRC(track.ISRC)
			if err != nil || trackByISRC == nil || trackByISRC.ID == "" {
				return "", false
			}
			// Even an ISRC-resolved candidate is verified against the queried
			// title/artist when we have them: an extension whose ISRC search
			// silently falls back to a name search (e.g. SoundCloud re-uploads
			// or a wrong mapping) must never serve an unrelated song.
			if trackName != "" && verificarMatchStream(p, trackByISRC.ID, trackName, artistName, track.ISRC, true) == "" {
				return "", false
			}
			return rescueProviderUnaVez(p, trackByISRC.ID, quality)
		}, quality)
		log.Printf("[rescue] fase 1 (ISRC) %.0fms -> prov=%q url=%v verify=%v",
			float64(time.Since(inicioFase).Microseconds())/1000, provName, u != "", v)
		if v && verifyName == "" {
			verifyName = provName
		}
		if u != "" {
			return u, provName, nil, false
		}
		attempted = append(attempted, names...)
	}

	// Recoge lo que resolvió la fase de nombre, que viene corriendo en paralelo
	// desde el principio (ver arriba). Un match suyo que necesite verificación de
	// sesión se recuerda igual que el de la fase exacta: nunca es fatal mientras
	// algo pueda sonar.
	if trackName != "" && artistName != "" {
		r := <-chNombre
		if r.verify && verifyName == "" {
			verifyName = r.prov
		}
		if r.url != "" {
			return r.url, r.prov, nil, false
		}
		attempted = append(attempted, names...)
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
