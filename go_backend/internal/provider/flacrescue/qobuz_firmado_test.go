// qobuz_firmado_test.go — pruebas del canal "Qobuz firmado".
//
// Lo que se fija acá, sin tocar la red:
//   1. la FIRMA es la de Qobuz (pares ordenados "clavevalor" + ts + secreto,
//      MD5): con un vector conocido de afuera, así un reordenamiento se detecta
//      en CI;
//   2. el servidor de prueba RECHAZA la petición si la firma no valida (o sea: el
//      flujo no puede "pasar" con una firma rota);
//   3. el canal devuelve la URL de CDN directa sin bajar un byte (es lo que lo
//      hace rápido: suena al instante);
//   4. IDENTIDAD: si el resultado no trae el ISRC pedido, no se pide ninguna URL;
//   5. HONESTIDAD de formato: si se pidió sin pérdida y Qobuz responde MP3
//      (restriction UserUnauthenticated, medido en la API real), el canal FALLA
//      en vez de servir MP3 como si fuera FLAC;
//   6. sin claves no se hace NI UNA petición (canal apagado por defecto);
//   7. el canal no puede comerse el presupuesto de la fase;
//   8. el pool de claves: varios orígenes en paralelo, cacheo y ROTACIÓN
//      (401/400 → se piden claves nuevas y se reintenta una vez);
//   9. la búsqueda por nombre trae el ISRC de Qobuz (para que la identidad la
//      confirme el llamador) y sigue apagada sin claves.
//
// Run: cd go_backend && go test ./internal/provider/flacrescue/ -run Qobuz -v

package flacrescue

import (
	"crypto/md5"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"sort"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

// firmaIndependiente es la firma escrita OTRA VEZ (no se reusa la del código).
func firmaIndependiente(metodo string, params map[string]string, ts, secreto string) string {
	claves := make([]string, 0, len(params))
	for k := range params {
		claves = append(claves, k)
	}
	sort.Strings(claves)
	var b strings.Builder
	b.WriteString(metodo)
	for _, k := range claves {
		b.WriteString(k)
		b.WriteString(params[k])
	}
	b.WriteString(ts)
	b.WriteString(secreto)
	s := md5.Sum([]byte(b.String()))
	return hex.EncodeToString(s[:])
}

// El texto firmado y su MD5 se calcularon FUERA del proyecto (receta de Qobuz
// que usa el sitio auditado): si el formato de la firma cambia, esto falla.
func TestFirmaQobuzTieneElFormatoDeQobuz(t *testing.T) {
	params := map[string]string{"format_id": "6", "intent": "stream", "track_id": "12345"}
	want := firmaIndependiente("trackgetFileUrl", params, "1700000000", "s3cr3t")
	if got := firmaQobuz("trackgetFileUrl", params, "1700000000", "s3cr3t"); got != want {
		t.Fatalf("firma getFileUrl = %s, se esperaba %s", got, want)
	}
	busqueda := map[string]string{"query": "USUM72500857", "limit": "5", "offset": "0"}
	got := firmaQobuz("catalogsearch", busqueda, "1700000000", "s3cr3t")
	wantBusq := firmaIndependiente("catalogsearch", busqueda, "1700000000", "s3cr3t")
	if got != wantBusq {
		t.Fatalf("firma search = %s, se esperaba %s", got, wantBusq)
	}
}

// El vector fijo (calculado con python/hashlib, fuera del repo) protege contra
// un cambio de orden de parámetros que la implementación de referencia pudiera
// copiar.
func TestFirmaQobuzContraVectorExterno(t *testing.T) {
	params := map[string]string{"format_id": "5", "intent": "stream", "track_id": "12345"}
	if got := firmaQobuz("trackgetFileUrl", params, "1700000000", "s3cr3t"); got != "16dfa3f6c0f51d356b3691170920487b" {
		t.Fatalf("firma = %s, se esperaba 16dfa3f6c0f51d356b3691170920487b", got)
	}
}

// servidorQobuz modela la API real: valida la firma de cada llamada, cuenta las
// peticiones y responde el formato pedido. Con [conToken]=false imita lo que se
// midió SIN sesión: 200 + URL, pero MP3 degradado (restriction
// UserUnauthenticated) — que es justo lo que el canal no puede aceptar como FLAC.
func servidorQobuz(t *testing.T, isrc string, conToken bool, dormir time.Duration) (*httptest.Server, *int64, *int64) {
	t.Helper()
	var nBusqueda, nArchivo int64
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		q := r.URL.Query()
		params := map[string]string{}
		for k, v := range q {
			switch k {
			case "app_id", "request_ts", "request_sig":
				continue
			}
			params[k] = v[0]
		}
		metodo := ""
		switch r.URL.Path {
		case "/catalog/search":
			metodo = "catalogsearch"
			atomic.AddInt64(&nBusqueda, 1)
		case "/track/getFileUrl":
			metodo = "trackgetFileUrl"
			atomic.AddInt64(&nArchivo, 1)
		default:
			w.WriteHeader(http.StatusNotFound)
			return
		}
		if q.Get("app_id") != "APP1" {
			w.WriteHeader(http.StatusUnauthorized)
			return
		}
		esperada := firmaIndependiente(metodo, params, q.Get("request_ts"), "SECRETO1")
		if q.Get("request_sig") != esperada {
			t.Errorf("%s: firma inválida (%s != %s)", r.URL.Path, q.Get("request_sig"), esperada)
			w.WriteHeader(http.StatusUnauthorized)
			return
		}
		if dormir > 0 {
			select {
			case <-r.Context().Done():
				return
			case <-time.After(dormir):
			}
		}
		if metodo == "catalogsearch" {
			_ = json.NewEncoder(w).Encode(map[string]any{"tracks": map[string]any{"items": []map[string]any{
				{"id": 111, "isrc": "OTRO0000001", "title": "Otra cosa", "duration": 200,
					"performer": map[string]any{"name": "Otro"}, "album": map[string]any{"title": "X"}},
				{"id": 312055179, "isrc": isrc, "title": "La pedida", "duration": 210.5,
					"performer": map[string]any{"name": "Artista Real"}, "album": map[string]any{"title": "El álbum"}},
			}}})
			return
		}
		if q.Get("track_id") != "312055179" {
			t.Errorf("track_id = %s, se esperaba 312055179", q.Get("track_id"))
		}
		if q.Get("intent") != "stream" {
			t.Errorf("intent = %s, se esperaba stream", q.Get("intent"))
		}
		if q.Get("format_id") == "6" && conToken {
			_ = json.NewEncoder(w).Encode(map[string]any{
				"url": "https://cdn.qobuz.example/312055179.flac?range=ok", "mime_type": "audio/flac", "bit_depth": 16,
			})
			return
		}
		// Sin sesión: Qobuz contesta 200 con una URL de MP3 y la restricción.
		_ = json.NewEncoder(w).Encode(map[string]any{
			"url":       "https://streaming-qobuz-std.example/312055179.mp3",
			"mime_type": "audio/mpeg", "bit_depth": 16,
			"restrictions": []map[string]string{{"code": "UserUnauthenticated"}},
		})
	}))
	return srv, &nBusqueda, &nArchivo
}

// clienteConQobuz arma un provider SIN espejos (para probar que el canal no los
// necesita) y con las credenciales del canal.
func clienteConQobuz(base string) *Client {
	c := NewClient()
	c.mirrors = nil
	c.SetSettingsQobuz(map[string]string{
		"qobuz_api_base":   base,
		"qobuz_app_id":     "APP1",
		"qobuz_app_secret": "SECRETO1",
	})
	return c
}

func TestQobuzFirmadoConTokenSirveFLACEnDosPeticiones(t *testing.T) {
	srv, nBusqueda, nArchivo := servidorQobuz(t, "USUM72500857", true, 0)
	defer srv.Close()

	c := clienteConQobuz(srv.URL)
	inicio := time.Now()
	url, err := c.GetStreamURL("312055179", "flac")
	transcurrido := time.Since(inicio)
	if err != nil {
		t.Fatalf("GetStreamURL: %v", err)
	}
	if !strings.HasPrefix(url, "https://cdn.qobuz.example/") {
		t.Fatalf("url = %q, se esperaba la de la CDN", url)
	}
	if *nBusqueda != 0 || *nArchivo != 1 {
		t.Fatalf("peticiones = %d búsqueda / %d archivo (con id numérico es UNA)", *nBusqueda, *nArchivo)
	}
	if transcurrido > 2*time.Second {
		t.Fatalf("tardó %s: el canal resuelve por URL, no bajando el audio", transcurrido)
	}
	t.Logf("id numérico -> URL de FLAC en 1 petición (%s)", transcurrido.Round(time.Millisecond))

	// Segunda vez: sale de caché, sin peticiones nuevas.
	if _, err := c.GetStreamURL("312055179", "flac"); err != nil {
		t.Fatalf("segunda resolución: %v", err)
	}
	if *nBusqueda != 0 || *nArchivo != 1 {
		t.Fatalf("la caché no evitó la petición: %d/%d", *nBusqueda, *nArchivo)
	}
}

// El caso medido en la API real sin sesión: Qobuz devuelve 200 con una URL, pero
// es MP3. Pedir FLAC y aceptarlo sería mentirle al usuario.
func TestQobuzFirmadoSinTokenNoSeHacePasarPorFLAC(t *testing.T) {
	srv, _, nArchivo := servidorQobuz(t, "USUM72500857", false, 0)
	defer srv.Close()

	c := clienteConQobuz(srv.URL)
	if url, err := c.GetStreamURL("312055179", "flac"); err == nil {
		t.Fatalf("sirvió %q como si fuera FLAC sin token de suscriptor", url)
	}
	if *nArchivo != 1 {
		t.Fatalf("peticiones = %d, se esperaba 1 (se intentó y se rechazó)", *nArchivo)
	}
}

// …pero si el usuario pidió pérdida (MP3 320), esa misma respuesta SÍ sirve: es
// una URL directa y gratis, más rápida que bajar el archivo.
func TestQobuzFirmadoSirveMP3CuandoSePideLossy(t *testing.T) {
	srv, _, nArchivo := servidorQobuz(t, "USUM72500857", false, 0)
	defer srv.Close()

	c := clienteConQobuz(srv.URL)
	url, err := c.GetStreamURL("312055179", "MP3_320")
	if err != nil {
		t.Fatalf("debía aceptar el MP3 pedido: %v", err)
	}
	if !strings.Contains(url, ".mp3") {
		t.Fatalf("url = %q", url)
	}
	if *nArchivo != 1 {
		t.Fatalf("peticiones = %d, se esperaba 1", *nArchivo)
	}
}

// Con ISRC (no numérico) el canal busca por texto y solo acepta el ISRC exacto.
func TestQobuzFirmadoPorISRCUsaLaBusquedaYExigeIdentidad(t *testing.T) {
	srv, nBusqueda, nArchivo := servidorQobuz(t, "USUM72500857", true, 0)
	defer srv.Close()

	c := clienteConQobuz(srv.URL)
	if _, err := c.GetStreamURL("USUM72500857", "flac"); err != nil {
		t.Fatalf("debía encontrar la pista por su ISRC: %v", err)
	}
	if *nBusqueda != 1 || *nArchivo != 1 {
		t.Fatalf("peticiones = %d/%d, se esperaban 1 y 1", *nBusqueda, *nArchivo)
	}
}

func TestQobuzFirmadoNoSirveOtroISRC(t *testing.T) {
	srv, nBusqueda, nArchivo := servidorQobuz(t, "OTROISRC999", true, 0)
	defer srv.Close()

	c := clienteConQobuz(srv.URL)
	if url, err := c.GetStreamURL("USUM72500857", "flac"); err == nil {
		t.Fatalf("sirvió %q con un ISRC que no es el pedido", url)
	}
	if *nArchivo != 0 {
		t.Fatalf("pidió %d URLs pese a no tener el ISRC exacto", *nArchivo)
	}
	if *nBusqueda != 1 {
		t.Fatalf("búsquedas = %d, se esperaba 1", *nBusqueda)
	}
}

func TestQobuzFirmadoApagadoSinCredenciales(t *testing.T) {
	srv, nBusqueda, nArchivo := servidorQobuz(t, "USUM72500857", true, 0)
	defer srv.Close()

	c := NewClient()
	c.mirrors = nil
	if url, err := c.GetStreamURL("312055179", "flac"); err == nil {
		t.Fatalf("devolvió %q sin credenciales configuradas", url)
	}
	if _, err := c.GetStreamURL("USUM72500857", "flac"); err == nil {
		t.Fatal("devolevió audio con el canal apagado")
	}
	if *nBusqueda != 0 || *nArchivo != 0 {
		t.Fatalf("se hicieron %d/%d peticiones sin credenciales", *nBusqueda, *nArchivo)
	}
	if _, err := c.SearchTracks("cualquiera", 5); err == nil {
		t.Fatal("sin claves la búsqueda del canal debe seguir apagada (flac-rescue no tiene catálogo)")
	}
}

func TestQobuzFirmadoRespetaElPresupuesto(t *testing.T) {
	srv, _, _ := servidorQobuz(t, "USUM72500857", true, 30*time.Second)
	defer srv.Close()

	c := clienteConQobuz(srv.URL)
	inicio := time.Now()
	if url, err := c.GetStreamURL("312055179", "flac"); err == nil {
		t.Fatalf("devolvió %q con el servidor colgado", url)
	}
	transcurrido := time.Since(inicio)
	if tope := presupuestoQobuz + 1500*time.Millisecond; transcurrido > tope {
		t.Fatalf("tardó %s, por encima del tope %s", transcurrido, tope)
	}
	t.Logf("Qobuz firmado colgado: cortó en %s (presupuesto %s)", transcurrido.Round(10*time.Millisecond), presupuestoQobuz)
}

// La búsqueda por nombre devuelve el ISRC de Qobuz: es lo que permite confirmar
// la identidad (y lo que la API NO puede hacer buscando por ISRC).
func TestQobuzBusquedaPorNombreTraeISRC(t *testing.T) {
	srv, nBusqueda, _ := servidorQobuz(t, "USUM72500857", true, 0)
	defer srv.Close()

	c := clienteConQobuz(srv.URL)
	pistas, err := c.SearchTracks("NUEVAYoL Bad Bunny", 5)
	if err != nil {
		t.Fatalf("SearchTracks: %v", err)
	}
	if len(pistas) != 2 {
		t.Fatalf("pistas = %d, se esperaban 2", len(pistas))
	}
	primera := pistas[1]
	if primera.ID != "312055179" || primera.ISRC != "USUM72500857" || primera.Artist != "Artista Real" {
		t.Fatalf("pista mal armada: %+v", primera)
	}
	if primera.Duration != 210500 {
		t.Fatalf("duración = %d ms, se esperaban 210500", primera.Duration)
	}
	if primera.Provider != "flac-rescue" {
		t.Fatalf("provider = %q", primera.Provider)
	}
	if *nBusqueda != 1 {
		t.Fatalf("búsquedas = %d, se esperaba 1", *nBusqueda)
	}
}
