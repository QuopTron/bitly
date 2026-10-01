package flacrescue

// stash_relay_test.go — Fija el CONTRATO del canal stash-relay contra un
// servidor local: la firma HMAC exacta, la config cacheada, el reintento tras
// un 401 (rotación de clave), el rechazo de un pedido con pérdida y el rechazo
// de una URL sin `etsp`.
//
// Por qué importa: el relay es de un TERCERO y su contrato es exacto —un byte
// distinto en el mensaje firmado y responde 401—. El test recomputa el HMAC con
// el formato de referencia del proyecto (auth.js) para que la firma no se
// valide "contra sí misma".
//
// Nunca sale a Internet.

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"
	"time"
)

const (
	claveStashPrueba = "55d63668c70e1e10c016cd0dbdbff710ba1f3d011957270e02b2e962490dd8c6"
	urlStashPrueba   = "https://streaming-qobuz-std.akamaized.net/file?uid=1&eid=312055179&fmt=6&etsp=1999999999&hmac=abc"
	// trackStashPrueba es un id de pista NUMÉRICO de Qobuz: así la resolución no
	// necesita el catálogo firmado (ni claves) para llegar al mint.
	trackStashPrueba = "312055179"
)

// cabecerasStash es lo que el test necesita recordar de cada mint.
type cabecerasStash struct {
	version, install, ts, auth, track, formato string
}

// relayPrueba imita al relay de Stash: publica su config y atiende el mint.
type relayPrueba struct {
	srv     *httptest.Server
	mu      sync.Mutex
	clave   string
	cfgHits int
	mints   int
	// sinFirma cuenta los pedidos al MINT que llegan SIN `X-Stash-Auth`: son los
	// de calentamiento (ver calentarMint), que no pueden gastar cupo. Se separan
	// de [mints] para que los asserts de "no gastó un mint" sigan diciendo algo.
	sinFirma int
	ultimo   cabecerasStash
	// mintFn permite a cada test desviar la respuesta (401, 404, URL rara…).
	mintFn func(*relayPrueba, http.ResponseWriter, *http.Request)
	// urlResp es la URL que devuelve el mint por defecto.
	urlResp string
}

func nuevoRelayPrueba(t *testing.T, clave string) *relayPrueba {
	t.Helper()
	rp := &relayPrueba{clave: clave, urlResp: urlStashPrueba}
	rp.srv = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/lossless.json":
			rp.mu.Lock()
			rp.cfgHits++
			clave := rp.clave
			rp.mu.Unlock()
			w.Header().Set("content-type", "application/json")
			fmt.Fprintf(w, `{"v":1,"relays":[{"base":%q,"priority":1}],"relay_key":%q}`, rp.srv.URL, clave)
		case "/v1/qobuz/file":
			if r.Header.Get("X-Stash-Auth") == "" {
				// Calentamiento: se rechaza (como haría el relay de verdad) sin
				// contarlo como mint.
				rp.mu.Lock()
				rp.sinFirma++
				rp.mu.Unlock()
				w.WriteHeader(http.StatusUnauthorized)
				fmt.Fprint(w, `{"error":"unauthorized"}`)
				return
			}
			rp.mu.Lock()
			rp.mints++
			rp.ultimo = cabecerasStash{
				version: r.Header.Get("X-Stash-Version"),
				install: r.Header.Get("X-Stash-Install"),
				ts:      r.Header.Get("X-Stash-Ts"),
				auth:    r.Header.Get("X-Stash-Auth"),
				track:   r.URL.Query().Get("track_id"),
				formato: r.URL.Query().Get("format_id"),
			}
			fn := rp.mintFn
			rp.mu.Unlock()
			if fn != nil {
				fn(rp, w, r)
				return
			}
			w.Header().Set("content-type", "application/json")
			fmt.Fprintf(w, `{"url":%q,"format_id":6,"bit_depth":16,"sample_rate":44100}`, rp.urlResp)
		default:
			http.NotFound(w, r)
		}
	}))
	t.Cleanup(rp.srv.Close)
	return rp
}

// clienteStash arma un cliente con el canal encendido apuntando al servidor.
func clienteStash(t *testing.T, rp *relayPrueba) *Client {
	t.Helper()
	c := NewClient()
	c.stashActivo = true
	c.stashConfigURL = rp.srv.URL + "/lossless.json"
	return c
}

// firmaDeReferencia recalcula el HMAC como lo hace el relay (auth.js), sin usar
// firmarStash, para que la comparación no sea circular.
func firmaDeReferencia(clave, install, track, formato, ts string) string {
	mac := hmac.New(sha256.New, []byte(clave))
	fmt.Fprintf(mac, "%s:%s:%s:%s", install, track, formato, ts)
	return hex.EncodeToString(mac.Sum(nil))
}

func TestStashRelayMinteaConLaFirmaDelContrato(t *testing.T) {
	rp := nuevoRelayPrueba(t, claveStashPrueba)
	cliente := clienteStash(t, rp)

	enlace, err := cliente.resolverStashRelay(trackStashPrueba, "FLAC")
	if err != nil {
		t.Fatalf("debería resolver: %v", err)
	}
	if enlace != urlStashPrueba {
		t.Fatalf("enlace inesperado: %q", enlace)
	}
	u := rp.ultimo
	if u.version != "1" {
		t.Fatalf("X-Stash-Version mal: %q", u.version)
	}
	if u.track != trackStashPrueba || u.formato != stashFormatoFLAC {
		t.Fatalf("query mal: track=%q formato=%q", u.track, u.formato)
	}
	// El mensaje firmado es "<install>:<track_id>:<format_id>:<ts>".
	if esperado := firmaDeReferencia(claveStashPrueba, u.install, u.track, u.formato, u.ts); u.auth != esperado {
		t.Fatalf("firma HMAC distinta del contrato:\n got %s\n esp %s", u.auth, esperado)
	}
}

// TestStashRelayComparteElMintEnVuelo: las DOS fases del rescate (la exacta
// por ISRC y la búsqueda por nombre) llegan al relay con el MISMO id a la vez.
// Sin el vuelo compartido el relay recibía dos mints del mismo track y, como
// cada mint varía con su carga, la reproducción esperaba al más lento —medido
// en el ZTE real: el id entregado en 5,0s y otra vez en 5,4s, con 8,1s de tap—.
// Acá se fija que, con el mismo track, solo sale UN mint y las dos
// resoluciones reciben el enlace.
func TestStashRelayComparteElMintEnVuelo(t *testing.T) {
	rp := nuevoRelayPrueba(t, claveStashPrueba)
	// El mint se queda colgado hasta que el test lo libera: así el segundo
	// pedido llega mientras el primero sigue EN VUELO y puede engancharse.
	liberar := make(chan struct{})
	entro := make(chan struct{}, 2)
	rp.mintFn = func(rp *relayPrueba, w http.ResponseWriter, r *http.Request) {
		entro <- struct{}{}
		<-liberar
		w.Header().Set("content-type", "application/json")
		fmt.Fprintf(w, `{"url":%q,"format_id":6,"bit_depth":16,"sample_rate":44100}`, urlStashPrueba)
	}
	cliente := clienteStash(t, rp)
	cfg, err := cliente.configStash(false)
	if err != nil {
		t.Fatalf("config: %v", err)
	}

	type resultado struct {
		enlace string
		err    error
	}
	primero := make(chan resultado, 1)
	go func() {
		enlace, err := cliente.mintearStashCompartido(cfg, trackStashPrueba, stashFormatoFLAC)
		primero <- resultado{enlace, err}
	}()
	select {
	case <-entro:
	case <-time.After(2 * time.Second):
		t.Fatal("el primer mint nunca llegó al relay")
	}
	// El primero sigue colgado: el segundo pedido tiene que engancharse a él.
	segundo := make(chan resultado, 1)
	go func() {
		enlace, err := cliente.mintearStashCompartido(cfg, trackStashPrueba, stashFormatoFLAC)
		segundo <- resultado{enlace, err}
	}()
	// Margen para que el segundo llegue a la puerta del vuelo antes de liberar
	// (el primero está colgado, así que no hay mint que se adelante).
	time.Sleep(100 * time.Millisecond)

	select {
	case <-entro:
		t.Fatal("el mismo track se minteó DOS veces en paralelo")
	default:
	}
	close(liberar)

	for i, ch := range []chan resultado{primero, segundo} {
		r := <-ch
		if r.err != nil {
			t.Fatalf("resolución %d falló: %v", i, r.err)
		}
		if r.enlace != urlStashPrueba {
			t.Fatalf("resolución %d: enlace inesperado %q", i, r.enlace)
		}
	}
	rp.mu.Lock()
	mints := rp.mints
	rp.mu.Unlock()
	if mints != 1 {
		t.Fatalf("debe salir UN solo mint por track: %d", mints)
	}
}

func TestStashRelayCacheaLaConfig(t *testing.T) {
	rp := nuevoRelayPrueba(t, claveStashPrueba)
	cliente := clienteStash(t, rp)

	for i := 0; i < 3; i++ {
		if _, err := cliente.resolverStashRelay(trackStashPrueba, "FLAC"); err != nil {
			t.Fatalf("resolución %d: %v", i, err)
		}
	}
	rp.mu.Lock()
	cfgHits, mints := rp.cfgHits, rp.mints
	rp.mu.Unlock()
	if cfgHits != 1 {
		t.Fatalf("la config debería pedirse una sola vez: %d", cfgHits)
	}
	if mints != 3 {
		t.Fatalf("cada resolución pide su mint: %d", mints)
	}
}

func TestStashRelayReintentaTrasRotarLaClave(t *testing.T) {
	const claveNueva = "1111111111111111111111111111111111111111111111111111111111111111"
	rp := nuevoRelayPrueba(t, "clave-vieja")
	// El primer mint responde 401 y rota la clave: la app debe recargar la config
	// y reintentar UNA vez, ya con la clave nueva.
	rp.mintFn = func(rp *relayPrueba, w http.ResponseWriter, r *http.Request) {
		rp.mu.Lock()
		visto := rp.ultimo
		rotar := rp.clave != claveNueva
		if rotar {
			rp.clave = claveNueva
		}
		rp.mu.Unlock()
		if _, ok := r.Header["X-Stash-Auth"]; !ok {
			t.Errorf("el mint debe ir firmado")
		}
		_ = visto
		if rotar {
			w.WriteHeader(http.StatusUnauthorized)
			fmt.Fprint(w, `{"error":"unauthorized"}`)
			return
		}
		w.Header().Set("content-type", "application/json")
		fmt.Fprintf(w, `{"url":%q,"format_id":6,"bit_depth":16,"sample_rate":44100}`, urlStashPrueba)
	}
	cliente := clienteStash(t, rp)

	enlace, err := cliente.resolverStashRelay(trackStashPrueba, "FLAC")
	if err != nil {
		t.Fatalf("debería recuperarse del 401: %v", err)
	}
	if enlace != urlStashPrueba {
		t.Fatalf("enlace inesperado: %q", enlace)
	}
	rp.mu.Lock()
	cfgHits, mints := rp.cfgHits, rp.mints
	rp.mu.Unlock()
	if cfgHits != 2 {
		t.Fatalf("el 401 debe forzar UNA recarga de config: %d", cfgHits)
	}
	if mints != 2 {
		t.Fatalf("debe haber un solo reintento: %d", mints)
	}
}

func TestStashRelayNoSirveConPerdida(t *testing.T) {
	rp := nuevoRelayPrueba(t, claveStashPrueba)
	cliente := clienteStash(t, rp)

	if _, err := cliente.resolverStashRelay(trackStashPrueba, "MP3_320"); err == nil {
		t.Fatal("un pedido con pérdida no puede usar el relay (es solo lossless)")
	}
	rp.mu.Lock()
	defer rp.mu.Unlock()
	if rp.mints != 0 || rp.cfgHits != 0 {
		t.Fatalf("no debería tocar la red: mints=%d cfg=%d", rp.mints, rp.cfgHits)
	}
}

func TestStashRelayRechazaURLSinEtsp(t *testing.T) {
	rp := nuevoRelayPrueba(t, claveStashPrueba)
	// Una URL sin `etsp` haría fallar el stream en silencio: el canal la rechaza.
	rp.urlResp = "https://cdn.example/x.flac"
	cliente := clienteStash(t, rp)

	if _, err := cliente.resolverStashRelay(trackStashPrueba, "FLAC"); err == nil {
		t.Fatal("una URL sin vencimiento (etsp) no puede darse por buena")
	}
}

func TestStashRelay404EsFallo(t *testing.T) {
	rp := nuevoRelayPrueba(t, claveStashPrueba)
	rp.mintFn = func(rp *relayPrueba, w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNotFound)
		fmt.Fprint(w, `{"error":"not_available"}`)
	}
	cliente := clienteStash(t, rp)

	if _, err := cliente.resolverStashRelay(trackStashPrueba, "FLAC"); err == nil {
		t.Fatal("un 404 del relay no puede contar como éxito")
	}
}

func TestStashRelayApagadoNoTocaLaRed(t *testing.T) {
	rp := nuevoRelayPrueba(t, claveStashPrueba)
	cliente := clienteStash(t, rp)
	cliente.stashActivo = false

	if _, err := cliente.resolverStashRelay(trackStashPrueba, "FLAC"); err == nil {
		t.Fatal("con el canal apagado no debería resolver")
	}
	rp.mu.Lock()
	defer rp.mu.Unlock()
	if rp.mints != 0 || rp.cfgHits != 0 {
		t.Fatalf("apagado no debe tocar la red: mints=%d cfg=%d", rp.mints, rp.cfgHits)
	}
}

func TestAjusteStashEnciendeYApaga(t *testing.T) {
	cliente := NewClient()
	cliente.aplicarAjusteStash(map[string]string{claveStashRelay: "off"})
	if cliente.stashEncendido() {
		t.Fatal("\"off\" debe apagar el canal")
	}
	cliente.aplicarAjusteStash(map[string]string{claveStashRelay: "https://mi-relay.example/lossless.json"})
	if !cliente.stashEncendido() {
		t.Fatal("una URL debe encender el canal")
	}
	if cliente.stashConfigURL != "https://mi-relay.example/lossless.json" {
		t.Fatalf("config mal aplicada: %q", cliente.stashConfigURL)
	}
}

// TestPrecalentarRelayCalientaElMint: el precalentado tiene que despertar el
// Worker del MINT, no solo traer la config. Son Workers DISTINTOS (la config en
// el tipjar, el mint en el relay) y medido en el tap real el primer mint en
// frío tardó 8 s —se comió su techo y perdió la carrera—, mientras que en
// caliente tarda ~1 s. Con el relay como único canal sin pérdida vivo, eso es la
// diferencia entre un FLAC en 1,6 s y un re-subido en 8,8 s.
//
// Y el calentamiento NO puede gastar un mint: el cupo es de un tercero y
// limitado, así que va sin firma (el relay lo rechaza igual, pero el isolate
// arranca).
func TestPrecalentarRelayCalientaElMint(t *testing.T) {
	rp := nuevoRelayPrueba(t, claveStashPrueba)
	cliente := clienteStash(t, rp)

	cliente.precalentarStashRelay() // sale en segundo plano

	esperarHasta(t, 2*time.Second, func() bool {
		rp.mu.Lock()
		defer rp.mu.Unlock()
		return rp.cfgHits >= 1 && rp.sinFirma >= 1
	})

	rp.mu.Lock()
	mints, sinFirma := rp.mints, rp.sinFirma
	rp.mu.Unlock()
	if sinFirma == 0 {
		t.Fatal("el precalentado no tocó la ruta del mint: en frío el mint se come su techo")
	}
	if mints != 0 {
		t.Fatalf("el calentamiento no puede gastar un mint del cupo: %d", mints)
	}
}

// esperarHasta espera (con tope) a que [cond] se cumpla. Existe porque el
// precalentado sale en una goroutine y sin esto el test sería una carrera.
func esperarHasta(t *testing.T, tope time.Duration, cond func() bool) {
	t.Helper()
	fin := time.Now().Add(tope)
	for time.Now().Before(fin) {
		if cond() {
			return
		}
		time.Sleep(5 * time.Millisecond)
	}
	t.Fatalf("la condición no se cumplió en %s", tope)
}
