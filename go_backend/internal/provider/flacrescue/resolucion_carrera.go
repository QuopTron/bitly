// ─────────────────────────────────────────────────────────────
// resolucion_carrera.go — La carrera de CANALES del rescate: todos
// los caminos (Qobuz firmado, stash-relay, arcod, espejos) se
// intentan A LA VEZ y gana el que primero entregue audio.
//
// Por qué existe: la resolución recorría los canales EN SERIE, así
// que el tiempo era la SUMA de sus presupuestos (Qobuz 2,5s + stash
// hasta 8s + arcod 4s + espejos 5s = hasta ~17s) aunque el espejo
// que sí tenía el FLAC respondiera en 300ms. Como el rescate es la
// PRIMERA fase de la reproducción, ese peor caso se sentía como un
// tap roto. En paralelo el tiempo pasa a ser el del canal MÁS
// RÁPIDO, que es lo que importa cuando hay una canción esperando.
//
// Lo que NO cambia (es lo que mantiene la robustez y la calidad):
//   · cada canal conserva su presupuesto y su propia resiliencia
//     (pausa de arcod, caché de la config del relay, TTLs, cuotas);
//   · la calidad y la preferencia se respetan RETENIENDO, no
//     descartando: un resultado con pérdida espera a que llegue el
//     sin pérdida que está en vuelo (y solo esa espera se paga
//     completa, porque es audio lo que se gana), mientras que
//     cambiar de canal sin cambiar de calidad espera muy poco;
//   · en cuanto los canales mejores dicen "no tengo nada", el
//     retenido gana al instante (no se espera la gracia entera por
//     una fuente que ya contestó);
//   · los canales APAGADOS o sin credenciales contestan su error en
//     microsegundos (no hacen red), así que no retienen nada;
//   · un canal que contestara "sin error" pero SIN enlace se normaliza a
//     fallo: una URL vacía nunca puede llegar al reproductor como si fuera
//     audio (era un fallo silencioso, el peor de los modos de fallo).
//
// Cada carrera deja UNA línea de log (ganador, ms y motivo de cada canal que
// falló): es lo único que permite, con el log de una app real, decir si el FLAC
// vino de las credenciales, del relay, de arcod o de los espejos.
//
// Se conecta con: resolucion.go (resolverPorISRC) y client.go.
// Parte del flujo: interior del rescate de audio (no se usa solo).
// ─────────────────────────────────────────────────────────────

package flacrescue

import (
	"errors"
	"fmt"
	"log"
	"strings"
	"sync"
	"time"
)

// Grados de preferencia de un canal. Cuanto más alto, más se retiene un
// resultado de grado menor esperando al de grado mayor.
const (
	// gradoCredenciales: el CDN con las credenciales del propio usuario. Es el
	// único que entrega una URL directa de primera mano.
	gradoCredenciales = 3
	// gradoSinPerdida: sin pérdida de terceros (stash-relay, arcod). Misma
	// calidad entre ellos: gana el primero que responda, que es justamente la
	// optimización (los dos entregan el FLAC real).
	gradoSinPerdida = 2
	// gradoEspejos: los espejos por ISRC. Contestan rápido y pueden degradar a
	// MP3 cuando el FLAC no está, de ahí que un resultado CON pérdida espere.
	gradoEspejos = 1
)

// errNingunCanalDioAudio es el error de "contestaron todos y ninguno traía
// audio". El llamador lo distingue del fallo de un canal concreto para poder
// explicar el motivo que sí le sirve al usuario ("sin espejos configurados").
var errNingunCanalDioAudio = errors.New("rescate: ningún canal entregó audio")

// graciaRescateLossless es cuánto retiene un resultado CON pérdida a que llegue
// el sin pérdida de un canal que ya está en vuelo. Misma cifra que la gracia del
// race de reproducción (ver streaming/rescue_race.go): una canción sonando ya es
// mejor que un FLAC hipotético, pero un FLAC que está a un segundo también.
const graciaRescateLossless = 1200 * time.Millisecond

// graciaRescatePreferencia es la espera cuando el resultado retenido es IGUAL de
// bueno (los dos sin pérdida) y lo único que se gana esperando es una fuente
// mejor ubicada (las credenciales propias antes que un tercero). Corta a
// propósito: cambiar de canal no mejora el audio, así que hacer esperar a la
// canción por eso no se justifica.
const graciaRescatePreferencia = 300 * time.Millisecond

// techoRescate es la red de seguridad de la carrera: por encima de cualquier
// presupuesto de canal, así que solo actúa si un canal se quedó colgado más
// allá de lo que su propio contexto permite.
const techoRescate = 15 * time.Second

// politicaEspera decide cuánto se retiene un resultado. Va en dos cifras porque
// lo que se gana esperando NO vale lo mismo en los dos casos: calidad (FLAC vs
// MP3) se paga; preferencia de canal (misma calidad) casi no.
type politicaEspera struct {
	// conPerdida: el retenido NO es sin pérdida y hay un canal sin pérdida en
	// vuelo. Es una diferencia de CALIDAD: se espera completo.
	conPerdida time.Duration
	// porPreferencia: el retenido es igual de bueno; solo se espera una fuente
	// mejor ubicada.
	porPreferencia time.Duration
}

// vacia reporta si la política no da nada que esperar (gana el primero que
// llegue, que es lo que quiere un pedido con pérdida).
func (p politicaEspera) vacia() bool {
	return p.conPerdida <= 0 && p.porPreferencia <= 0
}

// canalRescate es un camino de resolución con su preferencia. [correr] devuelve
// la URL, si el resultado tiene PÉRDIDA, y el error.
type canalRescate struct {
	nombre     string
	grado      int
	sinPerdida bool // este canal, con esta calidad pedida, entrega sin pérdida
	correr     func() (string, bool, error)
}

// resultadoCanal es lo que un canal reporta a la carrera.
type resultadoCanal struct {
	nombre  string
	url     string
	grado   int
	perdida bool
	err     error
}

// seguimiento es lo que la carrera sabe de un canal que todavía no contestó.
type seguimiento struct {
	grado      int
	sinPerdida bool
}

// carreraDeCanales corre todos los [canales] a la vez y devuelve el mejor
// resultado disponible: el primero que llegue, salvo que todavía pueda llegar
// uno mejor —en cuyo caso lo retiene según [politica]—.
//
// El error de la carrera es el del último canal que falló; si ningún canal
// llegó a fallar (todos apagados o sin credenciales) se devuelve uno genérico.
func carreraDeCanales(canales []canalRescate, politica politicaEspera) (urlOut, fuenteOut string, errOut error) {
	if len(canales) == 0 {
		return "", "", errors.New("rescate: sin canales disponibles")
	}
	inicio := time.Now()

	resultados := make(chan resultadoCanal, len(canales))
	var mu sync.Mutex
	pendientes := make(map[string]seguimiento, len(canales))
	for _, canal := range canales {
		pendientes[canal.nombre] = seguimiento{
			grado:      canal.grado,
			sinPerdida: canal.sinPerdida,
		}
	}

	// Un canal que contesta al instante su error de configuración (apagado, sin
	// credenciales) sale de [pendientes] enseguida, así no retiene a nadie.
	olvidar := func(nombre string) {
		mu.Lock()
		delete(pendientes, nombre)
		mu.Unlock()
	}

	// loQueSePuedeGanar dice qué le falta a [r] que otro canal en vuelo todavía
	// pueda mejorar: CALIDAD (hay un sin pérdida en camino y [r] no lo es) o
	// PREFERENCIA (hay un canal de grado mayor).
	loQueSePuedeGanar := func(r resultadoCanal) (calidad, preferencia bool) {
		mu.Lock()
		defer mu.Unlock()
		for _, p := range pendientes {
			if r.perdida && p.sinPerdida {
				calidad = true
			}
			if p.grado > r.grado {
				preferencia = true
			}
		}
		return calidad, preferencia
	}

	// esperaDe decide cuánto se retiene [r] y si vale la pena retenerlo.
	esperaDe := func(r resultadoCanal) (time.Duration, bool) {
		if politica.vacia() {
			return 0, false
		}
		calidad, preferencia := loQueSePuedeGanar(r)
		switch {
		case calidad:
			return politica.conPerdida, politica.conPerdida > 0
		case preferencia:
			return politica.porPreferencia, politica.porPreferencia > 0
		default:
			return 0, false
		}
	}

	// yaNoGanaNadieMas reporta si el retenido ya no tiene a quién esperar.
	yaNoGanaNadieMas := func(r resultadoCanal) bool {
		_, vale := esperaDe(r)
		return !vale
	}

	// nadieMasEnVuelo dice si ya no queda ningún canal por contestar.
	nadieMasEnVuelo := func() bool {
		mu.Lock()
		defer mu.Unlock()
		return len(pendientes) == 0
	}

	for _, canal := range canales {
		canal := canal
		go func() {
			url, perdida, err := canal.correr()
			resultados <- resultadoCanal{
				nombre:  canal.nombre,
				url:     url,
				grado:   canal.grado,
				perdida: perdida,
				err:     err,
			}
		}()
	}

	var (
		ultimoError error
		retenido    *resultadoCanal
		fallos      []string
	)

	// Latencia, ganador y motivo de cada canal en UNA línea. Sin esto, con el log
	// de una app real no hay forma de saber si el FLAC vino de las credenciales,
	// del relay, de arcod o de los espejos, ni cuánto se pagó por él: es la misma
	// instrumentación que el [play] tap de la reproducción, aplicada a la carrera.
	defer func() {
		ganador := fuenteOut
		if errOut != nil || ganador == "" {
			ganador = "ninguno"
		}
		log.Printf("[rescate] carrera %dms ganó=%s canales=%d fallos=[%s]",
			time.Since(inicio).Milliseconds(), ganador, len(canales), strings.Join(fallos, " | "))
	}()

	// Temporizador de la gracia: se arma UNA vez por carrera (el retenido ya
	// lleva su espera contada) y se apaga al devolver.
	var (
		timerGracia *time.Timer
		canalGracia <-chan time.Time
	)
	defer func() {
		if timerGracia != nil {
			timerGracia.Stop()
		}
	}()

	techo := time.NewTimer(techoRescate)
	defer techo.Stop()

	for {
		select {
		case r := <-resultados:
			olvidar(r.nombre)

			// Un "éxito" sin enlace sería una trampa: el llamador lo tomaría por
			// un stream y el reproductor se quedaría en silencio. Se normaliza a
			// fallo acá, en un solo lugar, para que ningún canal —presente ni
			// futuro— pueda entregar un vacío como si fuera audio.
			if r.err == nil && strings.TrimSpace(r.url) == "" {
				r.err = fmt.Errorf("%s: contestó sin enlace de audio", r.nombre)
			}

			if r.err != nil {
				ultimoError = r.err
				fallos = append(fallos, resumirFallo(r.nombre, r.err))
			} else if espera, vale := esperaDe(r); !vale {
				// Nadie puede entregar algo mejor (o el pedido no espera
				// mejoras: con pérdida pedida, el primero que llegue gana).
				return r.url, r.nombre, nil
			} else {
				// Todavía puede salir uno mejor: se retiene. Si el que estaba
				// retenido era peor, se reemplaza.
				if retenido == nil || mejorResultado(r, *retenido) {
					copia := r
					retenido = &copia
				}
				if timerGracia == nil {
					timerGracia = time.NewTimer(espera)
					canalGracia = timerGracia.C
				}
			}

			// Si el retenido ya no tiene a nadie mejor por quien esperar, se
			// devuelve YA: esperar la gracia entera por una fuente que ya dijo
			// "no tengo nada" solo se siente como que el tap no respondió.
			if retenido != nil && yaNoGanaNadieMas(*retenido) {
				return retenido.url, retenido.nombre, nil
			}
			// Y si se quedaron todos sin resultado, se corta acá, sin esperar el
			// techo: los que contestaron eran todos los que había.
			if retenido == nil && nadieMasEnVuelo() {
				if ultimoError == nil {
					ultimoError = errNingunCanalDioAudio
				}
				return "", "", ultimoError
			}

		case <-canalGracia:
			if retenido != nil {
				return retenido.url, retenido.nombre, nil
			}
			canalGracia = nil

		case <-techo.C:
			if retenido != nil {
				return retenido.url, retenido.nombre, nil
			}
			if ultimoError == nil {
				ultimoError = errors.New("rescate: se agotó el tiempo")
			}
			return "", "", ultimoError
		}
	}
}

// maxFalloEnLog acota lo que un canal copia al log de la carrera: los errores
// traen el cuerpo de la respuesta del sitio, y una línea de log no es un volcado
// de HTML.
const maxFalloEnLog = 160

// resumirFallo arma "canal: motivo" para el log de la carrera, en una sola línea
// y con el recorte en RUNAS (cortar bytes podría partir un acento). Los errores
// de los canales ya suelen venir con su propio prefijo, así que no se repite.
func resumirFallo(nombre string, err error) string {
	detalle := strings.Join(strings.Fields(err.Error()), " ")
	if runas := []rune(detalle); len(runas) > maxFalloEnLog {
		detalle = string(runas[:maxFalloEnLog]) + "…"
	}
	if strings.HasPrefix(detalle, nombre+":") {
		return detalle
	}
	return nombre + ": " + detalle
}

// mejorResultado reporta si [a] es un desempate mejor que [b]: primero por
// preferencia del canal, y entre iguales, el que NO tiene pérdida.
func mejorResultado(a, b resultadoCanal) bool {
	if a.grado != b.grado {
		return a.grado > b.grado
	}
	return b.perdida && !a.perdida
}
