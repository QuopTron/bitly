// ─────────────────────────────────────────────────────────────
// qobuz_memoria.go — Memoria compartida del id de pista de Qobuz:
// ISRC → id, con una sola búsqueda por ISRC aunque la pidan dos
// canales a la vez.
//
// Por qué existe: el id de Qobuz lo necesitan DOS canales —el Qobuz
// firmado (para pedir /track/getFileUrl) y el stash-relay (que solo
// habla de ids, no de ISRC, así que traduce por el catálogo)—, y desde
// que la resolución los corre EN PARALELO los dos pedían la MISMA
// búsqueda en el mismo instante: dos veces la cuota, dos veces la
// latencia y dos veces la chance de comerse un 429. Acá el primero que
// la pide la paga y el otro se engancha a esa misma búsqueda.
//
// Lo que NO comparte: los FALLOS. Compartir un fallo ataría el destino
// de un canal al del otro —si la petición del primero se cayó por un
// parpadeo de red, el segundo heredaría el fallo sin haber intentado—,
// y la robustez del rescate depende de que cada canal falle por su
// cuenta. Si la búsqueda compartida falló, el que esperaba la hace él.
//
// La memoria es de ACIERTOS y sin TTL: el catálogo ES el de Qobuz, así
// que la grabación de un ISRC no cambia de id. Se vacía cuando cambian
// las credenciales (SetSettingsQobuz), que es lo único que puede
// apuntar a otro catálogo.
//
// Se conecta con: qobuz_archivo.go y stash_relay.go (los dos que la
// piden) y client.go (estado del cliente).
// Parte del flujo: rescate de audio por ISRC.
// ─────────────────────────────────────────────────────────────

package flacrescue

import (
	"context"
	"fmt"
	"strings"
)

// vueloIDQobuz es una búsqueda de id EN CURSO. Los canales que llegan mientras
// corre esperan su cierre y leen su resultado: es un BROADCAST, así que TODOS
// los que esperan reciben lo mismo (no uno solo).
type vueloIDQobuz struct {
	// listo se cierra cuando [id] y [err] ya están escritos. El cierre es la
	// barrera que hace visible el resultado a los que esperaban.
	listo chan struct{}
	id    string
	err   error
}

// esperar bloquea hasta que el vuelo termina y devuelve su resultado.
func (v *vueloIDQobuz) esperar() (string, error) {
	<-v.listo
	return v.id, v.err
}

// trackIDPorISRCCompartido devuelve el id de pista de Qobuz de [isrc] pagando,
// como mucho, UNA búsqueda por ISRC por vuelo (ver la nota del archivo).
func (c *Client) trackIDPorISRCCompartido(ctx context.Context, base, isrc string) (string, error) {
	clave := strings.ToUpper(strings.TrimSpace(isrc))
	if clave == "" {
		return "", fmt.Errorf("qobuz-firmado: ISRC vacío")
	}

	c.idsQobuzMu.Lock()
	if id := c.idsQobuz[clave]; id != "" {
		c.idsQobuzMu.Unlock()
		return id, nil
	}
	if enVuelo, ok := c.idsQobuzVuelo[clave]; ok {
		c.idsQobuzMu.Unlock()
		// Otro canal ya está pagando EXACTAMENTE esta búsqueda: se espera su
		// resultado en vez de pedirlo de nuevo. Si esa falló, este canal la hace
		// por su cuenta —los fallos no se comparten (ver la nota del archivo)—.
		id, err := enVuelo.esperar()
		if err == nil && id != "" {
			return id, nil
		}
		return c.trackIDPorISRC(ctx, base, isrc)
	}
	// Este canal es el que la paga: publica su vuelo para que los que lleguen
	// mientras corre se enganchen a él.
	enVuelo := &vueloIDQobuz{listo: make(chan struct{})}
	c.idsQobuzVuelo[clave] = enVuelo
	c.idsQobuzMu.Unlock()

	id, err := c.trackIDPorISRC(ctx, base, isrc)

	c.idsQobuzMu.Lock()
	// Se despublica ANTES de publicar el resultado: el que llegue a partir de
	// acá encuentra la memoria (si hubo acierto) o paga su propia búsqueda.
	delete(c.idsQobuzVuelo, clave)
	if err == nil && id != "" {
		if len(c.idsQobuz) > maxCache {
			c.idsQobuz = map[string]string{}
		}
		c.idsQobuz[clave] = id
	}
	c.idsQobuzMu.Unlock()

	enVuelo.id, enVuelo.err = id, err
	close(enVuelo.listo)
	return id, err
}

// olvidarIDsQobuz vacía la memoria de ids: cambió lo que define QUÉ catálogo es
// (las credenciales), así que un id memorizado ya no dice nada del nuevo.
func (c *Client) olvidarIDsQobuz() {
	c.idsQobuzMu.Lock()
	defer c.idsQobuzMu.Unlock()
	c.idsQobuz = map[string]string{}
	c.idsQobuzVuelo = map[string]*vueloIDQobuz{}
}
