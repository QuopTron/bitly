package flacrescue

// resolucion_formato_test.go — Fija con qué FORMATO se le habla a cada canal,
// que es lo que decide si el canal sin pérdida participa de la resolución.
//
// Por qué importa (medido en el emulador): el relay es SOLO sin pérdida, así que
// con la calidad de la reproducción en MP3 contestaba "solo sirve sin pérdida" y
// quedaba afuera de la carrera. La fase de identificadores gastaba entonces su
// presupuesto entero sin stream y recién la búsqueda por nombre —que le pide
// FLAC— encontraba la canción 2,4 s después. Un FLAC sirve para un pedido con
// pérdida: suena mejor, no peor.
//
// Regla de la cascada: manda la calidad de AJUSTES; lo que pide cada
// reproducción y los demás niveles entran después como respaldo.
//
// Nunca sale a Internet: los espejos (que sí son red) se apagan en cada test.

import (
	"net/http"
	"strings"
	"testing"
	"time"
)

// clienteRescateOffline arma el cliente con el relay encendido y SIN espejos: la
// única fuente capaz de entregar audio es el relay, que apunta al servidor local.
func clienteRescateOffline(t *testing.T, rp *relayPrueba) *Client {
	t.Helper()
	c := clienteStash(t, rp)
	// Los espejos por defecto son servicios reales: apagarlos mantiene el test
	// offline (el paquete es offline por contrato, ver testmain_test.go).
	c.mirrors = nil
	return c
}

func formatosDe(t *testing.T, c *Client) string {
	t.Helper()
	return strings.Join(c.calidadAFormatos(), ",")
}

// TestCascadaMandaLaCalidadDeAjustes: la cascada sale de la calidad de Ajustes
// (primero) y sigue con el resto de los niveles del mejor al más compatible. No
// lleva ningún nivel pedido como parámetro a propósito: el pedido se respeta por
// canal (ver `mejor` en resolverPorISRC) y meterlo en la cascada partía la caché
// en varias claves por canción.
func TestCascadaMandaLaCalidadDeAjustes(t *testing.T) {
	casos := []struct {
		nombre   string
		config   string
		esperado string
	}{
		// Con FLAC configurado, el canal sin pérdida SIEMPRE está en la cascada:
		// era justo el bug que se comía el relay.
		{"FLAC configurado", "FLAC", "FLAC,MP3_320,MP3_128"},
		// "sin configurar" se comporta como FLAC (es el default de fábrica).
		{"sin configurar", "", "FLAC,MP3_320,MP3_128"},
		// Con un Ajuste con pérdida, ese nivel manda pero los otros siguen ahí
		// como respaldo: un FLAC es mejor que el silencio.
		{"320 configurado", "MP3_320", "MP3_320,FLAC,MP3_128"},
		{"128 configurado", "MP3_128", "MP3_128,FLAC,MP3_320"},
	}
	for _, caso := range casos {
		t.Run(caso.nombre, func(t *testing.T) {
			c := NewClient()
			c.mu.Lock()
			c.formato = caso.config
			c.mu.Unlock()
			if got := formatosDe(t, c); got != caso.esperado {
				t.Fatalf("cascada = %q, se esperaba %q", got, caso.esperado)
			}
		})
	}
}

// TestUnaClaveDeCachePorCancion: la cascada no depende del nivel pedido, así que
// la clave de caché es una sola por canción. Antes "high" daba una cascada y
// "flac" otra, y el streaming prueba hasta SIETE niveles por fuente
// (high → 3 → 192 → mp3 → 128 → low → flac): el mismo ISRC pagaba la carrera de
// canales varias veces por reproducción (medido: 4,9s en la fase de
// identificadores + 2,4s en la de nombre). Con una sola clave, la segunda
// consulta la contesta la caché — y el fallo, que se recuerda 60s, también.
func TestUnaClaveDeCachePorCancion(t *testing.T) {
	rp := nuevoRelayPrueba(t, claveStashPrueba)
	c := clienteRescateOffline(t, rp)

	// El streaming arranca la cascada de calidades por "high" y a "flac" llega
	// último: dos niveles con los que ANTES se pedía la canción dos veces.
	if _, err := c.GetStreamURL(trackStashPrueba, "high"); err != nil {
		t.Fatalf("primer pedido (high): %v", err)
	}
	if _, err := c.GetStreamURL(trackStashPrueba, "flac"); err != nil {
		t.Fatalf("segundo pedido (flac): %v", err)
	}

	rp.mu.Lock()
	defer rp.mu.Unlock()
	if rp.mints != 1 {
		t.Fatalf("la misma canción con dos calidades pagó %d resoluciones; debe pagar 1 (la segunda sale de caché)", rp.mints)
	}
}

// TestRescateConPerdidaUsaElRelay: pedido MP3_320 con el usuario configurado en
// FLAC (el default) → el relay SÍ participa y entrega su FLAC. Antes este mismo
// caso devolvía "flac-rescue: stash-relay: solo sirve sin pérdida".
func TestRescateConPerdidaUsaElRelay(t *testing.T) {
	rp := nuevoRelayPrueba(t, claveStashPrueba)
	c := clienteRescateOffline(t, rp)

	if got := c.formatoPreferido(); got != "FLAC" {
		t.Fatalf("premisa del test: el formato configurado debe ser FLAC, es %q", got)
	}

	url, err := c.GetStreamURL(trackStashPrueba, "MP3_320")
	if err != nil {
		t.Fatalf("un pedido con pérdida no puede quedarse sin el canal sin pérdida: %v", err)
	}
	if url != urlStashPrueba {
		t.Fatalf("url inesperada: %q", url)
	}
	rp.mu.Lock()
	formato := rp.ultimo.formato
	mints := rp.mints
	rp.mu.Unlock()
	if mints != 1 {
		t.Fatalf("el relay debería haberse usado una vez: %d mints", mints)
	}
	// Y se le pidió SU formato, no el del pedido: es el único que entiende.
	if formato != stashFormatoFLAC {
		t.Fatalf("al relay hay que pedirle FLAC, se le pidió %q", formato)
	}
}

// TestRescateSinPerdidaSigueUsandoElRelay: la regresión obvia — un pedido sin
// pérdida ya funcionaba y debe seguir funcionando.
func TestRescateSinPerdidaSigueUsandoElRelay(t *testing.T) {
	rp := nuevoRelayPrueba(t, claveStashPrueba)
	c := clienteRescateOffline(t, rp)

	url, err := c.GetStreamURL(trackStashPrueba, "FLAC")
	if err != nil {
		t.Fatalf("pedido sin pérdida: %v", err)
	}
	if url != urlStashPrueba {
		t.Fatalf("url inesperada: %q", url)
	}
}

// TestRescateConAhorroDeDatosUsaElRelayComoRespaldo: con MP3_128 configurado a
// propósito, el nivel pedido va primero, pero si ninguna fuente con pérdida
// entrega audio el canal sin pérdida es un respaldo válido (un FLAC es mejor
// que el silencio). Lo que NO puede pasar es que quede afuera por formato.
func TestRescateConAhorroDeDatosUsaElRelayComoRespaldo(t *testing.T) {
	rp := nuevoRelayPrueba(t, claveStashPrueba)
	c := clienteRescateOffline(t, rp)
	c.mu.Lock()
	c.formato = "MP3_128"
	c.mu.Unlock()

	url, err := c.GetStreamURL(trackStashPrueba, "MP3_128")
	if err != nil {
		t.Fatalf("sin fuentes con pérdida, el respaldo sin pérdida debe resolver: %v", err)
	}
	if url != urlStashPrueba {
		t.Fatalf("url inesperada: %q", url)
	}
	rp.mu.Lock()
	defer rp.mu.Unlock()
	if rp.ultimo.formato != stashFormatoFLAC {
		t.Fatalf("al relay se le pide FLAC: %q", rp.ultimo.formato)
	}
}

// TestRelayOcupadoSePausaSolo: un 503 del relay lo deja en pausa y durante esa
// pausa NO se vuelve a tocar la red. Sin esto, cada fase de cada carrera
// reintentaba el mint contra un relay ocupado (es lo que se midió en el tap del
// emulador: un 503 por carrera, ocupando turnos de worker).
func TestRelayOcupadoSePausaSolo(t *testing.T) {
	// El reintento corto existe (ver reintentoRelayEspera): acá el relay sigue
	// ocupado, así que el reintento también falla y la pausa tiene que quedar.
	antes := reintentoRelayEspera
	reintentoRelayEspera = time.Millisecond
	t.Cleanup(func() { reintentoRelayEspera = antes })

	rp := nuevoRelayPrueba(t, claveStashPrueba)
	rp.mu.Lock()
	rp.mintFn = func(_ *relayPrueba, w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusServiceUnavailable)
		_, _ = w.Write([]byte(`{"error":"busy"}`))
	}
	rp.mu.Unlock()
	c := clienteRescateOffline(t, rp)

	if _, err := c.resolverStashRelay(trackStashPrueba, "FLAC"); err == nil {
		t.Fatal("un 503 no puede contar como éxito")
	}
	if !c.relayPausado() {
		t.Fatal("un 503 debe dejar el canal en pausa")
	}

	rp.mu.Lock()
	trasElIntento := rp.mints
	rp.mu.Unlock()
	if trasElIntento != 2 {
		t.Fatalf("un 503 rápido se reintenta UNA vez: %d mints", trasElIntento)
	}

	// Aunque el relay se recupere, la pausa manda: no se toca la red.
	rp.mu.Lock()
	rp.mintFn = nil
	rp.mu.Unlock()
	if _, err := c.resolverStashRelay(trackStashPrueba, "FLAC"); err == nil {
		t.Fatal("en pausa debe devolver error, no un enlace")
	}
	rp.mu.Lock()
	defer rp.mu.Unlock()
	if rp.mints != trasElIntento {
		t.Fatalf("en pausa no se puede volver a pedir el mint: %d mints", rp.mints)
	}
}

// TestRelayOcupadoSeRecuperaConElReintento: el caso que se midió en el ZTE real
// —el relay contestaba 503 a los ~1s y el canal quedaba 20s afuera, cayendo la
// reproducción al respaldo (YouTube ~11s)— tiene que resolverse con UN reintento
// corto, sin pausa y sin perder robustez: si el reintento también falla, la pausa
// queda igual (ver TestRelayOcupadoSePausaSolo).
func TestRelayOcupadoSeRecuperaConElReintento(t *testing.T) {
	antes := reintentoRelayEspera
	reintentoRelayEspera = time.Millisecond
	t.Cleanup(func() { reintentoRelayEspera = antes })

	rp := nuevoRelayPrueba(t, claveStashPrueba)
	rp.mu.Lock()
	primerIntento := true
	rp.mintFn = func(_ *relayPrueba, w http.ResponseWriter, _ *http.Request) {
		rp.mu.Lock()
		primero := primerIntento
		primerIntento = false
		rp.mu.Unlock()
		if primero {
			w.WriteHeader(http.StatusServiceUnavailable)
			_, _ = w.Write([]byte(`{"error":"busy"}`))
			return
		}
		w.Header().Set("content-type", "application/json")
		_, _ = w.Write([]byte(`{"url":"` + urlStashPrueba + `","format_id":6,"bit_depth":16,"sample_rate":44100}`))
	}
	rp.mu.Unlock()
	c := clienteRescateOffline(t, rp)

	enlace, err := c.resolverStashRelay(trackStashPrueba, "FLAC")
	if err != nil {
		t.Fatalf("un 503 transitorio debe recuperarse con el reintento: %v", err)
	}
	if enlace != urlStashPrueba {
		t.Fatalf("enlace inesperado: %q", enlace)
	}
	if c.relayPausado() {
		t.Fatal("si el reintento sirvió, el canal NO puede quedar en pausa")
	}
}

// TestRescateAgotadoSoloConTodosLosCanalesCaidos: el cortocircuito solo dispara
// cuando NINGÚN canal puede entregar audio. Con un canal sano la carrera corre
// como siempre, así que el cortocircuito no puede esconder un FLAC disponible.
func TestRescateAgotadoSoloConTodosLosCanalesCaidos(t *testing.T) {
	rp := nuevoRelayPrueba(t, claveStashPrueba)
	c := clienteRescateOffline(t, rp) // relay local (sano), sin espejos, arcod apagado

	if c.rescateAgotado() {
		t.Fatal("con el relay sano el rescate NO está agotado")
	}
	c.pausarRelay()
	if !c.rescateAgotado() {
		t.Fatal("relay en pausa y sin espejos: el rescate está agotado")
	}
	// Un espejo configurado y no marcado vuelve a habilitar el rescate.
	c.mu.Lock()
	c.mirrors = []string{"https://espejo.test"}
	c.mu.Unlock()
	if c.rescateAgotado() {
		t.Fatal("con un espejo vivo no puede considerarse agotado")
	}
}

// TestQobuzSinSesionCuentaComoCanalCaido: tener claves NO alcanza. Medido en el
// dispositivo real —claves del Worker inyectadas, sin sesión premium— el canal
// solo devolvía una muestra de 30s y se pagaba entero en cada carrera (2,7s).
func TestQobuzSinSesionCuentaComoCanalCaido(t *testing.T) {
	rp := nuevoRelayPrueba(t, claveStashPrueba)
	c := clienteRescateOffline(t, rp)
	c.mu.Lock()
	c.qobuzAppID, c.qobuzSecreto = "app", "secreto"
	c.mu.Unlock()
	c.pausarRelay()

	if c.rescateAgotado() {
		t.Fatal("con credenciales de Qobuz y sin la marca, el canal cuenta como sano")
	}
	c.marcarQobuzSinSesion()
	if !c.rescateAgotado() {
		t.Fatal("una cuenta que no puede servir la canción no es un canal sano")
	}
	// Credenciales nuevas (otra cuenta, quizá con suscriptor) borran la marca.
	c.olvidarQobuzSinSesion()
	if c.rescateAgotado() {
		t.Fatal("credenciales nuevas deben volver a habilitar el canal")
	}
}

// TestTodosLosCanalesCaidosNoPaganLaCarrera: con todos los canales caídos la
// resolución no corre la carrera, no toca la red y falla al instante. Es el
// ahorro medido en el tap: el relay gastaba 2,3s buscando el id de Qobuz para un
// mint que iba a contestar 503, y ese turno hacía falta para la fuente que suena.
func TestTodosLosCanalesCaidosNoPaganLaCarrera(t *testing.T) {
	rp := nuevoRelayPrueba(t, claveStashPrueba)
	c := clienteRescateOffline(t, rp)
	c.pausarRelay()

	inicio := time.Now()
	if _, err := c.GetStreamURL(trackStashPrueba, "FLAC"); err == nil {
		t.Fatal("sin canales sanos no puede haber enlace")
	}
	if d := time.Since(inicio); d > 250*time.Millisecond {
		t.Fatalf("el cortocircuito tardó %s; no debe tocar la red", d)
	}
	rp.mu.Lock()
	defer rp.mu.Unlock()
	if rp.mints != 0 {
		t.Fatalf("con todos los canales caídos no se pide ni un mint: %d", rp.mints)
	}
}
