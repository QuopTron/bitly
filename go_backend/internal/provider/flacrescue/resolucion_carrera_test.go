// resolucion_carrera_test.go — Fija la CARRERA DE CANALES del rescate.
//
// Por qué importa: la resolución recorría los canales en SERIE (Qobuz firmado →
// stash → arcod → espejos), así que el tiempo era la SUMA de sus presupuestos
// —hasta ~17s con los canales encendidos— aunque la fuente que sí tenía el audio
// respondiera en 300ms. Estos tests fijan que:
//   - gana el canal MÁS RÁPIDO y no se espera a los lentos;
//   - un resultado CON pérdida espera una gracia corta a que llegue el sin
//     pérdida (la calidad no se pierde por correr en paralelo);
//   - esa espera se suelta apenas no queda nadie capaz de dar algo mejor;
//   - y en el camino real (GetStreamURL) los espejos ya no esperan a que un
//     canal lento termine de fallar.
//
// Nunca sale a Internet: todo va contra servidores de prueba.
package flacrescue

import (
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

// canalFalso arma un canal de la carrera con una demora y un resultado fijos.
func canalFalso(nombre string, grado int, demora time.Duration, url string, perdida bool, err error) canalRescate {
	return canalRescate{
		nombre:     nombre,
		grado:      grado,
		sinPerdida: !perdida,
		correr: func() (string, bool, error) {
			time.Sleep(demora)
			return url, perdida, err
		},
	}
}

// politicaDeCalidad es la que usa el rescate cuando se pide sin pérdida.
func politicaDeCalidad() politicaEspera {
	return politicaEspera{
		conPerdida:     graciaRescateLossless,
		porPreferencia: graciaRescatePreferencia,
	}
}

// TestCarreraGanaElCanalMasRapido: con pedido CON pérdida no se espera a nadie
// (política vacía), aunque el otro canal tenga más preferencia.
func TestCarreraGanaElCanalMasRapido(t *testing.T) {
	inicio := time.Now()
	url, fuente, err := carreraDeCanales([]canalRescate{
		canalFalso("lento", gradoSinPerdida, 1500*time.Millisecond, "https://cdn/flac", false, nil),
		canalFalso("rapido", gradoEspejos, 0, "https://cdn/mp3", true, nil),
	}, politicaEspera{})
	transcurrido := time.Since(inicio)

	if err != nil {
		t.Fatalf("debía resolver con el rápido: %v", err)
	}
	if fuente != "rapido" || url != "https://cdn/mp3" {
		t.Fatalf("ganó %q (%q)", url, fuente)
	}
	if transcurrido > 700*time.Millisecond {
		t.Fatalf("tardó %s: esperó al canal lento en vez de correr en paralelo", transcurrido)
	}
}

// TestCarreraRetieneLoConPerdidaPorElFLAC: con gracia pedida, un resultado con
// pérdida espera a que llegue el sin pérdida que está en vuelo.
func TestCarreraRetieneLoConPerdidaPorElFLAC(t *testing.T) {
	inicio := time.Now()
	url, fuente, err := carreraDeCanales([]canalRescate{
		canalFalso("espejos", gradoEspejos, 100*time.Millisecond, "https://cdn/mp3", true, nil),
		canalFalso("arcod", gradoSinPerdida, 700*time.Millisecond, "https://cdn/flac", false, nil),
	}, politicaDeCalidad())
	transcurrido := time.Since(inicio)

	if err != nil {
		t.Fatalf("debía resolver: %v", err)
	}
	if fuente != "arcod" || url != "https://cdn/flac" {
		t.Fatalf("ganó %q (%q): el FLAC tenía que esperarse", url, fuente)
	}
	if transcurrido < 600*time.Millisecond {
		t.Fatalf("tardó %s: no esperó el FLAC que venía en camino", transcurrido)
	}
}

// TestCarreraSueltaLoRetenidoCuandoNoQuedaNadieMejor: la espera se corta apenas
// el canal mejor dice que no tiene nada (no se paga la gracia completa).
func TestCarreraSueltaLoRetenidoCuandoNoQuedaNadieMejor(t *testing.T) {
	inicio := time.Now()
	url, fuente, err := carreraDeCanales([]canalRescate{
		canalFalso("espejos", gradoEspejos, 100*time.Millisecond, "https://cdn/mp3", true, nil),
		canalFalso("arcod", gradoSinPerdida, 250*time.Millisecond, "", false, errors.New("arcod: sin cuentas")),
	}, politicaDeCalidad())
	transcurrido := time.Since(inicio)

	if err != nil {
		t.Fatalf("el espejo tenía audio: %v", err)
	}
	if fuente != "espejos" {
		t.Fatalf("ganó %q", fuente)
	}
	if transcurrido > 800*time.Millisecond {
		t.Fatalf("tardó %s: esperó la gracia entera por un canal que ya había fallado", transcurrido)
	}
	_ = url
}

// TestCarreraDevuelveLoRetenidoAlVencerseLaGracia: si el canal mejor tarda más
// que la gracia, lo retenido gana igual (no se pierde la canción).
func TestCarreraDevuelveLoRetenidoAlVencerseLaGracia(t *testing.T) {
	inicio := time.Now()
	_, fuente, err := carreraDeCanales([]canalRescate{
		canalFalso("espejos", gradoEspejos, 50*time.Millisecond, "https://cdn/mp3", true, nil),
		canalFalso("arcod", gradoSinPerdida, 3*time.Second, "https://cdn/flac", false, nil),
	}, politicaEspera{conPerdida: 300 * time.Millisecond, porPreferencia: 300 * time.Millisecond})
	transcurrido := time.Since(inicio)

	if err != nil {
		t.Fatalf("debía devolver lo retenido: %v", err)
	}
	if fuente != "espejos" {
		t.Fatalf("ganó %q: se venció la gracia y tenía que ganar el retenido", fuente)
	}
	if transcurrido > 1500*time.Millisecond {
		t.Fatalf("tardó %s: no puede esperar al segundo canal", transcurrido)
	}
}

// TestCarreraSinNadaDevuelveElError: cuando ningún canal entrega audio, el error
// sale (y no se queda esperando el techo).
func TestCarreraSinNadaDevuelveElError(t *testing.T) {
	inicio := time.Now()
	_, _, err := carreraDeCanales([]canalRescate{
		canalFalso("a", gradoSinPerdida, 100*time.Millisecond, "", false, errors.New("a: nada")),
		canalFalso("b", gradoEspejos, 200*time.Millisecond, "", false, errors.New("b: nada")),
	}, politicaDeCalidad())
	transcurrido := time.Since(inicio)

	if err == nil {
		t.Fatal("debía fallar")
	}
	if !strings.Contains(err.Error(), "nada") {
		t.Fatalf("el error no explica la causa: %v", err)
	}
	if transcurrido > 1200*time.Millisecond {
		t.Fatalf("tardó %s: se quedó esperando de más", transcurrido)
	}
}

// TestCarreraNoAceptaUnExitoSinURL fija la defensa contra el fallo SILENCIOSO: un
// canal que contesta "sin error" pero sin enlace no puede ganar la carrera —el
// llamador lo tomaría por un stream y el reproductor se quedaría mudo—.
func TestCarreraNoAceptaUnExitoSinURL(t *testing.T) {
	url, fuente, err := carreraDeCanales([]canalRescate{
		canalFalso("vacio", gradoCredenciales, 0, "", false, nil),
		canalFalso("bueno", gradoEspejos, 50*time.Millisecond, "https://cdn/flac", false, nil),
	}, politicaDeCalidad())
	if err != nil {
		t.Fatalf("el canal bueno tenía el audio: %v", err)
	}
	if fuente != "bueno" || url != "https://cdn/flac" {
		t.Fatalf("ganó %q (%q): un vacío no puede pasar por stream", url, fuente)
	}
}

// Y si el ÚNICO canal contesta vacío, la carrera FALLA: nunca devuelve "" como si
// fuera un éxito (el llamador lo cachearía y el usuario oiría silencio).
func TestCarreraConSoloVaciosFalla(t *testing.T) {
	url, fuente, err := carreraDeCanales([]canalRescate{
		canalFalso("vacio", gradoCredenciales, 0, "", false, nil),
	}, politicaDeCalidad())
	if err == nil {
		t.Fatalf("devolvió %q (%q) como si hubiera audio", url, fuente)
	}
	if !strings.Contains(err.Error(), "sin enlace de audio") {
		t.Fatalf("el error no explica el motivo: %v", err)
	}
}

// TestEspejosCorrenJuntoAlCanalLento es el caso REAL que motivó la carrera: un
// canal sin pérdida que tarda (o cuelga) y unos espejos que responden al
// instante. Antes los espejos esperaban a que el canal lento agotara su
// presupuesto (3-4s); ahora el audio sale en cuanto el espejo contesta.
func TestEspejosCorrenJuntoAlCanalLento(t *testing.T) {
	colgado := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		select {
		case <-r.Context().Done():
			return
		case <-time.After(30 * time.Second):
		}
	}))
	defer colgado.Close()
	defer colgado.CloseClientConnections()

	espejo := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "audio/flac")
		_, _ = w.Write([]byte("fLaC"))
	}))
	defer espejo.Close()

	// arcod encendido contra el servidor que nunca contesta (en el TestMain del
	// paquete viene apagado).
	c := clienteArcod(colgado)
	c.SetSettings(map[string]string{"mirrors": espejo.URL, "format": "FLAC"})

	inicio := time.Now()
	url, fuente, err := c.resolverPorISRC("USUM72500857", []string{"FLAC"})
	transcurrido := time.Since(inicio)

	if err != nil {
		t.Fatalf("los espejos tenían el FLAC: %v", err)
	}
	if fuente != nombreEspejos {
		t.Fatalf("ganó %q (%q)", url, fuente)
	}
	if !strings.Contains(url, espejo.URL) {
		t.Fatalf("URL inesperada: %q", url)
	}
	// El canal lento no llegó ni a su primer tiempo de espera: los espejos
	// contestan al instante y no se espera a nadie más (los dos entregan sin
	// pérdida, así que la única espera posible es la de preferencia, corta).
	if transcurrido > 900*time.Millisecond {
		t.Fatalf("tardó %s: esperó al canal lento antes de probar los espejos", transcurrido)
	}
	t.Logf("carrera: los espejos ganaron en %s con arcod en vuelo", transcurrido.Round(time.Millisecond))
}

// TestElFLACGanaAlMP3AunqueLlegueDespués: la calidad no se pierde por correr en
// paralelo. El espejo tiene MP3 al instante y arcod el FLAC medio segundo
// después: gana el FLAC.
func TestElFLACGanaAlMP3AunqueLlegueDespues(t *testing.T) {
	espejo := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if formatoPedido(r) == "FLAC" {
			w.WriteHeader(http.StatusServiceUnavailable)
			_, _ = w.Write([]byte(`{"error":"no hay FLAC"}`))
			return
		}
		w.Header().Set("Content-Type", "audio/mpeg")
		_, _ = w.Write([]byte("audio"))
	}))
	defer espejo.Close()

	// arcod de prueba: contesta como el sitio real pero con demora, así obliga a
	// la carrera a decidir (el de los otros tests contesta al instante).
	lento := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch {
		case r.URL.Path == "/api/v2/guest/rate-limit":
			_, _ = w.Write([]byte(`{"remaining":999999,"isLimited":false}`))
		case r.URL.Path == "/api/get-music":
			_, _ = w.Write([]byte(jsonCatalogoArcod))
		case strings.HasPrefix(r.URL.Path, "/api/player/stream/"):
			time.Sleep(600 * time.Millisecond)
			_, _ = w.Write([]byte(jsonStreamArcod))
		default:
			t.Errorf("petición inesperada: %s", r.URL.Path)
		}
	}))
	defer lento.Close()

	c := clienteArcod(lento)
	c.SetSettings(map[string]string{"mirrors": espejo.URL, "format": "FLAC"})

	url, fuente, err := c.resolverPorISRC("QMFMF2447055", []string{"FLAC"})
	if err != nil {
		t.Fatalf("debía resolver: %v", err)
	}
	if fuente != nombreArcod {
		t.Fatalf("ganó %q (%q): el FLAC tenía que esperarse al MP3", url, fuente)
	}
	if !strings.Contains(url, "/v2/stream/play") {
		t.Fatalf("URL inesperada: %q", url)
	}
}
