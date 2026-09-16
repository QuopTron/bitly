// ─────────────────────────────────────────────────────────────
// carrera_espejos.go — Pregunta a TODOS los espejos por el mismo
// formato a la vez y se queda con el primero que responde audio.
//
// Por qué existe: la resolución recorría espejos EN SERIE, así que con
// dos espejos —uno lento o caído— el tiempo era la SUMA (2 × timeout de
// 3s = 6s, por encima del presupuesto entero de 5s) y el usuario oía
// silencio aunque el segundo espejo tuviera el FLAC al instante. En
// paralelo el tiempo pasa a ser el del MÁS RÁPIDO, que es lo que importa
// cuando el rescate es la primera fase de la reproducción.
//
// Lo que NO cambia: el orden de la CASCADA de formatos (FLAC → MP3_320 →
// MP3_128) sigue siendo estricto por formato; dentro de un formato todos
// los espejos dan lo mismo, así que ganar por velocidad no cambia la
// calidad servida.
//
// Se conecta con: resolucion.go (resolverPorISRC).
// Parte del flujo: rescate de audio por ISRC (reproducción y descarga).
// ─────────────────────────────────────────────────────────────

package flacrescue

import (
	"errors"
	"time"
)

// resultadoEspejo es lo que devuelve un espejo en la carrera.
type resultadoEspejo struct {
	url    string
	espejo string
	err    error
}

// carreraPorFormato lanza un intento por espejo (todos con el MISMO formato) y
// devuelve el primero que consigue audio. [fin] es el vencimiento del
// presupuesto compartido: al llegar ahí se devuelve el último error en vez de
// seguir esperando. Los intentos que quedan en vuelo se descartan solos (el
// canal tiene capacidad para todos, así que ninguna goroutine queda colgada).
func (c *Client) carreraPorFormato(espejos []string, isrc, formato string, fin time.Time) (string, string, error) {
	if len(espejos) == 0 {
		return "", "", errors.New("sin espejos")
	}
	canal := make(chan resultadoEspejo, len(espejos))
	for _, espejo := range espejos {
		go func(e string) {
			u, err := c.resolverEnEspejo(e, isrc, formato)
			canal <- resultadoEspejo{url: u, espejo: e, err: err}
		}(espejo)
	}

	limite := time.NewTimer(time.Until(fin))
	defer limite.Stop()

	var ultimo error
	for rango := 0; rango < len(espejos); rango++ {
		select {
		case r := <-canal:
			if r.err == nil {
				return r.url, r.espejo, nil
			}
			ultimo = r.err
		case <-limite.C:
			if ultimo == nil {
				ultimo = errors.New("tiempo agotado")
			}
			return "", "", ultimo
		}
	}
	if ultimo == nil {
		ultimo = errors.New("sin respuesta de los espejos")
	}
	return "", "", ultimo
}
