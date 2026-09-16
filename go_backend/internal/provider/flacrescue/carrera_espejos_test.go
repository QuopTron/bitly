// carrera_espejos_test.go — prueba que los espejos se consultan EN PARALELO.
//
// Por qué importa: en serie, un espejo lento (o caído) sumaba su timeout al
// del siguiente, así que con dos espejos el rescate podía pasarse del
// presupuesto entero (5s) y el usuario oía silencio aunque el segundo tuviera
// el FLAC al instante. Estos tests fijan que:
//   - gana el espejo MÁS RÁPIDO, no el primero de la lista;
//   - la cascada de formatos sigue siendo estricta (FLAC antes que MP3);
//   - con TODOS los espejos colgados se corta en el presupuesto, no se espera
//     a que terminen.
package flacrescue

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

// TestEspejosEnParaleloGanaElRapido: el espejo lento está PRIMERO en la lista y
// el rápido segundo; el resultado tiene que ser el rápido y en tiempo de rápido.
func TestEspejosEnParaleloGanaElRapido(t *testing.T) {
	lento := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		select {
		case <-r.Context().Done():
			return
		case <-time.After(1500 * time.Millisecond):
		}
		w.Header().Set("Content-Type", "audio/flac")
		_, _ = w.Write([]byte("lento"))
	}))
	defer lento.Close()

	rapido := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "audio/flac")
		_, _ = w.Write([]byte("rapido"))
	}))
	defer rapido.Close()

	c := NewClient()
	c.SetSettings(map[string]string{"mirrors": lento.URL + "," + rapido.URL, "format": "FLAC"})

	inicio := time.Now()
	url, err := c.GetStreamURL("USUM72500857", "flac")
	transcurrido := time.Since(inicio)
	if err != nil {
		t.Fatalf("debía resolver con el espejo rápido: %v", err)
	}
	if !strings.Contains(url, rapido.URL) {
		t.Fatalf("ganó %q: tenía que ganar el espejo RÁPIDO (%s)", url, rapido.URL)
	}
	if transcurrido > 900*time.Millisecond {
		t.Fatalf("tardó %s: esperó al espejo lento (en paralelo tiene que ganar el rápido)", transcurrido)
	}
	t.Logf("espejos en paralelo: ganó el rápido en %s (el lento tarda 1.5s)", transcurrido.Round(time.Millisecond))
}

// TestCascadaSigueSiendoSerial: dentro de un formato los espejos van en
// paralelo, pero el orden de la CASCADA (FLAC antes que MP3) no se toca: es la
// calidad la que manda, y en paralelo todos los espejos dan el mismo formato.
func TestCascadaSigueSiendoSerial(t *testing.T) {
	var pedidos []string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		formato := formatoPedido(r)
		pedidos = append(pedidos, formato)
		if formato != "MP3_320" {
			w.WriteHeader(http.StatusServiceUnavailable)
			_, _ = w.Write([]byte(`{"error":"no hay FLAC"}`))
			return
		}
		w.Header().Set("Content-Type", "audio/mpeg")
		_, _ = w.Write([]byte("audio"))
	}))
	defer srv.Close()

	c := NewClient()
	c.SetSettings(map[string]string{"mirrors": srv.URL, "format": "FLAC"})

	if _, err := c.GetStreamURL("USUM72500857", "flac"); err != nil {
		t.Fatalf("debía degradar a MP3_320: %v", err)
	}
	// Un espejo prueba DOS contratos por formato (/track/ y /stream/), así que
	// los pedidos de FLAC son varios: lo que se fija es el ORDEN de la cascada
	// (ningún MP3 antes de agotar el FLAC).
	primerMP3, ultimoFLAC := -1, -1
	for i, f := range pedidos {
		if f == "MP3_320" && primerMP3 < 0 {
			primerMP3 = i
		}
		if f == "FLAC" {
			ultimoFLAC = i
		}
	}
	if len(pedidos) == 0 || pedidos[0] != "FLAC" || primerMP3 < 0 {
		t.Fatalf("orden de la cascada = %v, se esperaba FLAC → MP3_320", pedidos)
	}
	if primerMP3 < ultimoFLAC {
		t.Fatalf("se pidió MP3 ANTES de agotar FLAC: %v", pedidos)
	}
}

// TestEspejosColgadosCortanEnElPresupuesto: con todos los espejos colgados no se
// espera a que se rindan, se corta en el presupuesto y el llamador sigue.
func TestEspejosColgadosCortanEnElPresupuesto(t *testing.T) {
	colgado := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		select {
		case <-r.Context().Done():
			return
		case <-time.After(30 * time.Second):
		}
	}))
	defer colgado.Close()
	defer colgado.CloseClientConnections()

	c := NewClient()
	c.SetSettings(map[string]string{"mirrors": colgado.URL, "format": "FLAC"})

	inicio := time.Now()
	if url, err := c.GetStreamURL("USUM72500857", "flac"); err == nil {
		t.Fatalf("devolvió %q con el espejo colgado", url)
	}
	transcurrido := time.Since(inicio)
	if transcurrido > presupuestoTotal+700*time.Millisecond {
		t.Fatalf("tardó %s, por encima del presupuesto %s", transcurrido, presupuestoTotal)
	}
	t.Logf("espejo colgado: cortó en %s (presupuesto %s)", transcurrido.Round(10*time.Millisecond), presupuestoTotal)
}
