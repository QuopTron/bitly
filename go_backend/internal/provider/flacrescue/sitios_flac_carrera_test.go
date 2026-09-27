// sitios_flac_carrera_test.go — Fija dos cosas nuevas del canal de sitios:
//
//  1. El ajuste "sitios" acepta una instancia que NO está en la lista de fábrica
//     (superflac es una de muchas del mismo software), respetando el orden y
//     deduplicando por host.
//  2. Los sitios se consultan EN PARALELO: gana el más rápido y un sitio colgado
//     no se come el presupuesto de los demás.
package flacrescue

import (
	"testing"
	"time"
)

// sitioStub implementa sitioFLAC para probar el registro y la carrera sin red.
type sitioStub struct {
	nombreS string
	baseS   string
	demora  time.Duration
	url     string
	err     error
	bloqueo chan struct{} // si no es nil, resolver espera su cierre
}

func (s *sitioStub) nombre() string { return s.nombreS }
func (s *sitioStub) base() string   { return s.baseS }
func (s *sitioStub) resolver(isrc, titulo, artista string, durMS int, formato string) (string, error) {
	if s.bloqueo != nil {
		<-s.bloqueo
	}
	if s.demora > 0 {
		time.Sleep(s.demora)
	}
	if s.url == "" {
		return "", s.err
	}
	return s.url, nil
}

func TestSitiosDeListaRespetaOrdenYDeduplica(t *testing.T) {
	sitios := sitiosDeLista([]string{
		"https://b.example", "https://a.example", "https://b.example/", "no-es-url",
	})
	if len(sitios) != 2 {
		t.Fatalf("esperaba 2 instancias (dedup + válidas), hubo %d: %v", len(sitios), sitios)
	}
	if sitios[0].base() != "https://b.example" || sitios[1].base() != "https://a.example" {
		t.Fatalf("no se respetó el orden del usuario: %q, %q", sitios[0].base(), sitios[1].base())
	}

	// Un host de fábrica usa su sitio registrado (no una instancia genérica).
	conocido := sitiosDeLista([]string{"https://superflac.com"})
	if len(conocido) != 1 || conocido[0].nombre() != "superflac" {
		t.Fatalf("el host conocido debe usar su sitio de fábrica: %v", conocido)
	}
}

func TestCarreraSitiosGanaLaMasRapida(t *testing.T) {
	lento := &sitioStub{nombreS: "lento", baseS: "https://lento.example", demora: 400 * time.Millisecond, url: "https://lento.example/a.flac"}
	rapido := &sitioStub{nombreS: "rapido", baseS: "https://rapido.example", demora: 20 * time.Millisecond, url: "https://rapido.example/b.flac"}

	cliente := NewClient()
	url, nombre, err := cliente.carreraSitios([]sitioFLAC{lento, rapido},
		"US0000000001", "Tema", "Artista", 180000, "FLAC", time.Now().Add(5*time.Second))
	if err != nil {
		t.Fatalf("no debería fallar: %v", err)
	}
	if nombre != "rapido" || url != "https://rapido.example/b.flac" {
		t.Fatalf("debe ganar el más rápido; ganó %q (%q)", nombre, url)
	}
}

func TestCarreraSitiosPrefiereErrorDeMatchYRespetaElTope(t *testing.T) {
	sinMatch := &sitioStub{nombreS: "sinmatch", baseS: "https://x.example", err: errSinCoincidencia}
	colgado := &sitioStub{nombreS: "colgado", baseS: "https://y.example", bloqueo: make(chan struct{})}
	defer close(colgado.bloqueo)

	cliente := NewClient()
	_, _, err := cliente.carreraSitios([]sitioFLAC{sinMatch, colgado},
		"US0000000001", "Tema", "Artista", 180000, "FLAC", time.Now().Add(120*time.Millisecond))
	if err != errSinCoincidencia {
		t.Fatalf("con un sitio que no tiene match, se prefiere ese error al de tiempo agotado; fue %v", err)
	}

	// Solo un sitio colgado: el tope del presupuesto corta la espera.
	inicio := time.Now()
	_, _, err = cliente.carreraSitios([]sitioFLAC{colgado},
		"US0000000001", "Tema", "Artista", 180000, "FLAC", time.Now().Add(120*time.Millisecond))
	if err == nil {
		t.Fatal("un sitio colgado debe terminar en error de tiempo agotado")
	}
	if transcurrido := time.Since(inicio); transcurrido > 2*time.Second {
		t.Fatalf("el tope no cortó la espera: %s", transcurrido)
	}
}
