// ─────────────────────────────────────────────────────────────
// atajo_presupuesto.go — Techo de TIEMPO para los atajos al proveedor preferido.
//
// Por qué existe: los dos atajos (StreamQuick en play_quick.go e intentarStream
// en rescue_try.go) recorrían el bucle de calidades SIN techo: hasta 8 llamadas
// a GetStreamURL en serie contra un cliente HTTP con timeout de 30 s cada uno,
// más las verificaciones de identidad entre medias. Un proveedor que se
// quedara colgado (firma de sesión, CDN lento, extensión JS que no devuelve)
// convertía un toque en un MINUTO de silencio, y el rescate —que sondea el
// resto de fuentes en paralelo— ni siquiera había arrancado.
//
// El corte es por TIEMPO y no por error a propósito: si el proveedor contesta
// rápido con un fallo, el bucle sigue con la siguiente calidad (eso es lo que
// permite bajar de FLAC a MP3 y sigue siendo rápido). Lo que el camino rápido
// no puede es DEMORARSE: a los [presupuestoAtajo] el llamador pasa al rescate,
// que es donde de verdad se gana el stream cuando este proveedor está lento o
// caído. Un corte por tiempo NUNCA se marca en el cooldown: el proveedor no
// falló, se le acabó el turno.
//
// Se conecta con: play_quick.go (StreamQuick), rescue_try.go (intentarStream),
// stream_package_fallback.go (el llamador que sigue al rescate cuando el
// atajo se corta).
// Parte del flujo: resolución de la URL de audio en el toque.
// ─────────────────────────────────────────────────────────────

package streaming

import (
	"fmt"
	"log"
	"time"
)

// presupuestoAtajo es cuánto puede durar un atajo al proveedor preferido.
//
// 4 s es la misma cota que fija la nota de latencia del rescate ("stream en
// menos de 4 s"): si en ese margen el proveedor preferido no dio stream, el
// atajo ya no está acelerando nada — está COMIENDO el margen que le queda al
// rescate. Un atajo que funciona resuelve en 1-2 s, así que el techo no toca
// el caso normal.
//
// Es `var` y no `const` para que los tests puedan acortarlo; en producción
// nadie lo toca.
var presupuestoAtajo = 4 * time.Second

// techoAtajo lleva el reloj de UN atajo y avisa cuando se agotó.
type techoAtajo struct {
	inicio    time.Time
	proveedor string
	intentos  int
}

// nuevoTechoAtajo arranca el reloj del atajo de [proveedor].
func nuevoTechoAtajo(proveedor string) *techoAtajo {
	return &techoAtajo{inicio: time.Now(), proveedor: proveedor}
}

// comprobar devuelve nil mientras quede tiempo, o el error de corte si no
// queda. Sirve para las etapas que NO son una llamada de stream (verificación
// de identidad, GetTrackByISRC): esas también consumen el presupuesto.
func (t *techoAtajo) comprobar(etapa string) error {
	if time.Since(t.inicio) < presupuestoAtajo {
		return nil
	}
	return t.cortar(etapa)
}

// probar es comprobar + contar: se llama ANTES de cada GetStreamURL, así que
// el intento que se reporta es el que de verdad llegó a la red.
func (t *techoAtajo) probar() error {
	if time.Since(t.inicio) >= presupuestoAtajo {
		return t.cortar("calidades")
	}
	t.intentos++
	return nil
}

// cortar deja constancia del corte y arma el error. El mensaje lo distingue
// de un fallo del proveedor: el llamador (streamPackageFallback) lo trata como
// "este atajo no dio stream" y sigue al rescate sin enfriar a nadie.
func (t *techoAtajo) cortar(etapa string) error {
	log.Printf("[play] atajo %s: %s agotó el presupuesto de %s tras %d intentos -> sigue el rescate",
		t.proveedor, etapa, presupuestoAtajo, t.intentos)
	return fmt.Errorf("presupuesto del atajo agotado en %s (%s)", t.proveedor, etapa)
}
