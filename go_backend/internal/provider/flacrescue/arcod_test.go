package flacrescue

// arcod_test.go — Fija la lectura del catálogo de arcod.xyz y la elección de
// la pista, con el fixture REAL capturado (ver arcod_fixture_test.go).
//
// Por qué la elección se prueba a fondo: buscar "NUEVAYoL" en el sitio
// devuelve diez pistas con ese título y solo una es la de Bad Bunny. Si el
// canal se quedara con la primera, bajaría la canción equivocada —y encima
// reemplazaría el archivo bueno del usuario.
//
// Nunca sale a Internet: el flujo con red simulada está en arcod_flujo_test.go.

import (
	"errors"
	"strings"
	"testing"
)

func TestPistasArcodLeeElCatalogoRealYDescartaLoQueNoSePuedeServir(t *testing.T) {
	pistas, err := pistasArcod([]byte(jsonCatalogoArcod))
	if err != nil {
		t.Fatalf("no debería fallar la lectura: %v", err)
	}
	if len(pistas) != 3 {
		t.Fatalf("esperaba 3 pistas, hubo %d", len(pistas))
	}
	p := pistas[0]
	// El artista de una pista viene en `performer`: leer `artist` (que existe
	// en los álbumes) lo dejaría vacío y no habría con qué identificarla.
	if p.artistaArcod() != "Bad Bunny" {
		t.Fatalf("artista mal leído (¿se buscó en `artist`?): %+v", p)
	}
	if p.tituloArcod() != "NUEVAYoL" || p.ISRC != "QMFMF2447055" {
		t.Fatalf("identidad mal leída: %+v", p)
	}
	if p.idArcod() != "312055179" {
		t.Fatalf("id mal leído: %q", p.idArcod())
	}
	// Un id que llega como texto tiene que leerse igual que uno numérico.
	if pistas[1].idArcod() != "393153762" {
		t.Fatalf("no leyó el id en texto: %q", pistas[1].idArcod())
	}
	// Zero J es downloadable=false: pedirle el audio fallaría.
	if pistas[2].servible() {
		t.Fatal("una pista no descargable no puede darse por servible")
	}
	if pistas[2].artistaArcod() != "Zero J" {
		t.Fatalf("artista mal leído en la tercera pista: %+v", pistas[2])
	}
}

func TestPistaArcodPorISRCNoAceptaParecidos(t *testing.T) {
	pistas, err := pistasArcod([]byte(jsonCatalogoArcod))
	if err != nil {
		t.Fatalf("no debería fallar la lectura: %v", err)
	}
	pista, err := pistaArcodPorISRC(pistas, "QMFMF2447055")
	if err != nil {
		t.Fatalf("debería encontrar su canción: %v", err)
	}
	if pista.idArcod() != "312055179" {
		t.Fatalf("eligió otra pista: %+v", pista)
	}
	// Dos pistas se llaman "NUEVAYoL" y una tercera "NUEVAYOL": sin ISRC no se
	// elige NINGUNA. Antes servir la de otro artista que no servir nada.
	if _, err := pistaArcodPorISRC(pistas, "ZZZZZZZZZZZZ"); !errors.Is(err, errSinCoincidencia) {
		t.Fatalf("un ISRC ausente no puede resolver: %v", err)
	}
	if _, err := pistaArcodPorISRC(pistas, ""); err == nil {
		t.Fatal("sin ISRC no hay nada que buscar")
	}
}

func TestPistasArcodAvisaCuandoElSitioNoTieneCuentas(t *testing.T) {
	_, err := pistasArcod([]byte(jsonSinCuentasArcod))
	if err == nil {
		t.Fatal("una búsqueda fallida no puede pasar por catálogo vacío")
	}
	// Se reconoce para poner el canal en pausa unos minutos en vez de pagar su
	// espera en cada reproducción.
	if !errors.Is(err, errArcodSinCuentas) {
		t.Fatalf("debería marcarse como canal sin cuentas: %v", err)
	}
	// Y el motivo del sitio no se pierde: es lo que ve el log.
	if !strings.Contains(err.Error(), "No healthy Qobuz tokens") {
		t.Fatalf("debería conservar el motivo del sitio: %v", err)
	}
}

func TestPistasArcodSinResultadosNoEsError(t *testing.T) {
	vacio := `{"success":true,"data":{"tracks":{"total":0,"offset":0,"limit":10,"items":[]}}}`
	pistas, err := pistasArcod([]byte(vacio))
	if err != nil {
		t.Fatalf("un catálogo vacío no es un fallo: %v", err)
	}
	if len(pistas) != 0 {
		t.Fatalf("no debería haber pistas: %+v", pistas)
	}
}

func TestCalidadArcodStreamPideFLACSalvoConPerdida(t *testing.T) {
	if q := calidadArcodStream("FLAC"); q != calidadArcodFLAC {
		t.Fatalf("sin pérdida debería pedir FLAC (6): %d", q)
	}
	// Sin formato reconocible se pide FLAC: es lo que quiere el usuario cuando
	// no eligió nada.
	if q := calidadArcodStream(""); q != calidadArcodFLAC {
		t.Fatalf("sin formato debería pedir FLAC (6): %d", q)
	}
	if q := calidadArcodStream("MP3_320"); q != calidadArcodMP3 {
		t.Fatalf("con pérdida debería pedir MP3 (5): %d", q)
	}
}
