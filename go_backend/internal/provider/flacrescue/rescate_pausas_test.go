package flacrescue

// rescate_pausas_test.go — Fija la regla de las PAUSAS del rescate: un canal que
// se cayó (pool sin cuentas, relay ocupado, cuenta sin sesión) se deja en paz,
// PERO un ajuste NUEVO lo vuelve a habilitar al instante.
//
// Por qué importa (es la mitad de código de "que la segunda fuente funcione"):
// las pausas existen para no pagar en cada canción un canal que ya dijo que no,
// y ese ahorro es real (medido en el tap: qobuz-firmado se pagaba 2,7 s por
// carrera y el relay hasta 10,5 s en frío). El riesgo es el opuesto: el usuario
// entra a Ajustes, pega su token o repunta el canal —justo la acción que iba a
// arreglarlo— y se encuentra con que el canal sigue apagado hasta una hora
// después. Estas pruebas fijan las dos caras.
//
// Nunca sale a Internet (los espejos son nombres inertes y el relay local).

import (
	"testing"
)

// TestAjusteArcodNuevoLevantaElBackoff: pegar un Bearer (o apuntar arcod a una
// instancia propia) es el arreglo que el usuario viene a hacer; el backoff del
// pool vacío era del canal ANTERIOR y no puede sobrevivirlo.
func TestAjusteArcodNuevoLevantaElBackoff(t *testing.T) {
	c := NewClient()
	c.marcarFalloArcod()
	if !c.enPausaArcod() {
		t.Fatal("premisa del test: el canal quedó en pausa")
	}

	c.aplicarAjusteArcod(map[string]string{claveTokenArcod: "Bearer nuevo"})
	if c.enPausaArcod() {
		t.Fatal("un token nuevo debe levantar el backoff del pool anterior")
	}
}

// TestAjusteArcodIgualNoTocaElEstado: Ajustes se reenvía entero en cada
// arranque, así que un valor idéntico no puede levantar un backoff vigente (si
// no, la pausa no serviría para nada).
func TestAjusteArcodIgualNoTocaElEstado(t *testing.T) {
	c := NewClient()
	c.aplicarAjusteArcod(map[string]string{"arcod": "on"})
	c.marcarFalloArcod()
	if !c.enPausaArcod() {
		t.Fatal("premisa del test: el canal quedó en pausa")
	}

	c.aplicarAjusteArcod(map[string]string{"arcod": "on"})
	if !c.enPausaArcod() {
		t.Fatal("un reenvío idéntico de Ajustes no puede levantar el backoff")
	}
}

// TestAjusteStashNuevoLevantaLaPausa: si el usuario apaga y vuelve a encender el
// relay —o lo repunta a otra config—, la pausa del relay anterior no dice nada
// del nuevo. Es el mejor canal sin pérdida: dejarlo dormido por un 503 viejo es
// regalar la calidad.
func TestAjusteStashNuevoLevantaLaPausa(t *testing.T) {
	rp := nuevoRelayPrueba(t, claveStashPrueba)
	c := clienteStash(t, rp)

	c.pausarRelay()
	c.aplicarAjusteStash(map[string]string{claveStashRelay: "off"})
	if c.relayPausado() {
		t.Fatal("un ajuste NUEVO debe levantar la pausa del relay")
	}

	// Y el reenvío idéntico, en cambio, la respeta.
	c.pausarRelay()
	c.aplicarAjusteStash(map[string]string{claveStashRelay: "off"})
	if !c.relayPausado() {
		t.Fatal("un reenvío idéntico de Ajustes no puede levantar la pausa")
	}
}

// TestEspejosNuevosOlvidanElPoolSinCuentas: volver a pegar un espejo que el
// maintainer acaba de recargar es exactamente el arreglo que el usuario hace en
// Ajustes; si la marca de "sin cuentas" sobrevive, el espejo sigue salteándose
// cinco minutos y parece que el ajuste no sirvió.
func TestEspejosNuevosOlvidanElPoolSinCuentas(t *testing.T) {
	c := NewClient()
	c.marcarEspejoSinCuentas("https://espejo.caido")
	if !c.espejoSinCuentas("https://espejo.caido") {
		t.Fatal("premisa del test: el espejo quedó marcado")
	}

	c.aplicarAjustesEspejos(map[string]string{"mirrors": "https://espejo.caido"})
	if c.espejoSinCuentas("https://espejo.caido") {
		t.Fatal("una lista nueva de espejos debe olvidar las marcas del pool anterior")
	}
}

// TestEspejosIgualesNoSeReaplican: una lista idéntica no es un cambio, así que
// no vacía la caché de resoluciones ni toca las marcas. Ajustes manda el bloque
// entero en cada arranque y vaciar la caché en cada envío hacía pagar
// resoluciones que ya estaban hechas.
func TestEspejosIgualesNoSeReaplican(t *testing.T) {
	c := NewClient()
	c.marcarEspejoSinCuentas("https://espejo.caido")
	// Los mirrors por defecto son otros: se fija una lista y después se repite.
	c.aplicarAjustesEspejos(map[string]string{"mirrors": "https://a.test,https://b.test"})
	c.marcarEspejoSinCuentas("https://a.test")

	c.aplicarAjustesEspejos(map[string]string{"mirrors": "https://a.test,https://b.test"})
	if !c.espejoSinCuentas("https://a.test") {
		t.Fatal("una lista idéntica no es un cambio: no debe olvidar las marcas")
	}
}
