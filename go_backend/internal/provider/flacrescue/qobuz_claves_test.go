// qobuz_claves_test.go — pruebas del POOL DE CLAVES del canal Qobuz firmado.
//
// Por qué importa: los app_secret de Qobuz rotan, y los orígenes que los
// publican se caen o cambian de forma. Sin estas garantías el canal quedaría
// "encendido" pero sin poder resolver nada, o peor: pidiendo claves en CADA
// canción (una petición extra por reproducción).
//
// Se fija que:
//  1. las claves se cachean (dos reproducciones = un solo pedido de claves);
//  2. ante un 400/401 de Qobuz se descartan, se piden de nuevo y se reintenta
//     UNA vez (rotación) — y la resolución termina bien;
//  3. con varios orígenes, gana el primero que sirve algo utilizable, y uno
//     caído no retrasa al otro (van en paralelo);
//  4. un origen que devuelve basura NO enciende el canal (ni una petición).
package flacrescue

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"
	"time"
)

// servidorClaves publica {appId, appSecret} y cuenta cuántas veces se lo pidió.
// [pares] se entrega en orden: el último se repite si se pide más veces.
func servidorClaves(pares ...[2]string) (*httptest.Server, *int64) {
	var n int64
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		i := int(atomic.AddInt64(&n, 1)) - 1
		if i >= len(pares) {
			i = len(pares) - 1
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]string{
			"appId": pares[i][0], "appSecret": pares[i][1],
		})
	}))
	return srv, &n
}

// clienteConOrigenDeClaves arma el provider SIN claves a mano y con el origen
// indicado (el mismo camino que usa un usuario que pega la URL).
func clienteConOrigenDeClaves(apiBase, keysURL string) *Client {
	c := NewClient()
	c.mirrors = nil
	c.SetSettingsQobuz(map[string]string{
		"qobuz_api_base": apiBase,
		"qobuz_keys_url": keysURL,
	})
	return c
}

func TestClavesDelOrigenSeCachean(t *testing.T) {
	api, _, _ := servidorQobuz(t, "USUM72500857", true, 0)
	defer api.Close()
	claves, nClaves := servidorClaves([2]string{"APP1", "SECRETO1"})
	defer claves.Close()

	c := clienteConOrigenDeClaves(api.URL, claves.URL)
	for i := 0; i < 2; i++ {
		if _, err := c.GetStreamURL("312055179", "flac"); err != nil {
			t.Fatalf("resolución %d: %v", i+1, err)
		}
	}
	if *nClaves != 1 {
		t.Fatalf("pedidos de claves = %d, se esperaba 1 (la segunda tiene que salir de caché)", *nClaves)
	}
}

// El caso real: el proveedor rota su app_secret y Qobuz empieza a responder 401.
// El canal tiene que pedir claves nuevas y reintentar, no quedarse muerto.
func TestClavesRotanAnteUnRechazoDeFirma(t *testing.T) {
	api, _, nArchivo := servidorQobuz(t, "USUM72500857", true, 0)
	defer api.Close()
	// Primero publica un par viejo (la API lo rechaza con 401), después el bueno.
	claves, nClaves := servidorClaves([2]string{"VIEJO", "SVIEJO"}, [2]string{"APP1", "SECRETO1"})
	defer claves.Close()

	c := clienteConOrigenDeClaves(api.URL, claves.URL)
	url, err := c.GetStreamURL("312055179", "flac")
	if err != nil {
		t.Fatalf("debía recuperarse de la rotación: %v", err)
	}
	if url == "" {
		t.Fatal("sin url")
	}
	if *nClaves != 2 {
		t.Fatalf("pedidos de claves = %d, se esperaban 2 (una por la rotación)", *nClaves)
	}
	if *nArchivo != 2 {
		t.Fatalf("peticiones a la API = %d, se esperaban 2 (la rechazada + la buena)", *nArchivo)
	}
	t.Logf("rotación: 2 pedidos de claves y la resolución terminó OK")
}

// Varios orígenes: se prueban en paralelo y gana el que sirve claves buenas.
func TestVariosOrigenesDeClavesEnParalelo(t *testing.T) {
	api, _, _ := servidorQobuz(t, "USUM72500857", true, 0)
	defer api.Close()

	// El primero devuelve HTML (no JSON): se descarta solo.
	basura := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html")
		_, _ = w.Write([]byte("<html>no soy una API</html>"))
	}))
	defer basura.Close()

	lento := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		select {
		case <-r.Context().Done():
			return
		case <-time.After(3 * time.Second):
		}
		_ = json.NewEncoder(w).Encode(map[string]string{"appId": "LENTO", "appSecret": "S"})
	}))
	defer lento.Close()

	claves, _ := servidorClaves([2]string{"APP1", "SECRETO1"})
	defer claves.Close()

	c := clienteConOrigenDeClaves(api.URL, basura.URL+","+lento.URL+","+claves.URL)
	inicio := time.Now()
	if _, err := c.GetStreamURL("312055179", "flac"); err != nil {
		t.Fatalf("debía usar el origen bueno: %v", err)
	}
	if transcurrido := time.Since(inicio); transcurrido > 1500*time.Millisecond {
		t.Fatalf("tardó %s: esperó al origen lento en vez de usar el que ya había respondido", transcurrido)
	}
	t.Logf("3 orígenes (basura, lento, bueno): resolvió en %s", time.Since(inicio).Round(time.Millisecond))
}

// Un origen que publica claves VENCIDAS (JSON válido, pero Qobuz las rechaza) no
// puede ganarle la carrera al que sí sirve: si ganara, cada reproducción fallaría
// hasta que alguien pegue claves nuevas a mano.
func TestOrigenConClavesMuertasNoGanaLaCarrera(t *testing.T) {
	api, _, nArchivo := servidorQobuz(t, "USUM72500857", true, 0)
	defer api.Close()

	muerto, nMuerto := servidorClaves([2]string{"MUERTO", "SVIEJO"})
	defer muerto.Close()
	bueno, nBueno := servidorClaves([2]string{"APP1", "SECRETO1"})
	defer bueno.Close()

	c := clienteConOrigenDeClaves(api.URL, muerto.URL+","+bueno.URL)
	url, err := c.GetStreamURL("312055179", "flac")
	if err != nil {
		t.Fatalf("debía usar el par válido: %v", err)
	}
	if url == "" {
		t.Fatal("sin url")
	}
	if *nArchivo != 1 {
		t.Fatalf("peticiones a getFileUrl = %d, se esperaba 1 (las claves muertas no se usan)", *nArchivo)
	}
	if *nMuerto != 1 || *nBueno != 1 {
		t.Fatalf("orígenes consultados = %d/%d, se esperaba 1 y 1", *nMuerto, *nBueno)
	}
	t.Logf("claves muertas descartadas por la validación: solo se usó el par que Qobuz acepta")
}

// Si el chequeo de claves falla por un hipo de Qobuz (5xx/timeout) no se tira el
// par: se usa igual y el llamador decide. Un chequeo no puede ser más exigente
// que la reproducción misma.
func TestParSinValidarSeUsaSiElChequeoFalla(t *testing.T) {
	var nArchivo int64
	api := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/catalog/search" {
			w.WriteHeader(http.StatusServiceUnavailable) // Qobuz con hipo
			return
		}
		if r.URL.Query().Get("app_id") != "APP1" {
			w.WriteHeader(http.StatusUnauthorized)
			return
		}
		atomic.AddInt64(&nArchivo, 1)
		_ = json.NewEncoder(w).Encode(map[string]any{
			"url": "https://cdn.qobuz.example/x.flac", "mime_type": "audio/flac", "bit_depth": 16,
		})
	}))
	defer api.Close()

	claves, _ := servidorClaves([2]string{"APP1", "SECRETO1"})
	defer claves.Close()

	c := clienteConOrigenDeClaves(api.URL, claves.URL)
	if _, err := c.GetStreamURL("312055179", "flac"); err != nil {
		t.Fatalf("el par se descartó solo porque la validación no pudo correr: %v", err)
	}
	if nArchivo != 1 {
		t.Fatalf("getFileUrl = %d, se esperaba 1", nArchivo)
	}
}

// Un origen que devuelve basura no puede encender el canal: sin claves válidas,
// cero peticiones a la API.
func TestOrigenDeClavesBasuraNoEnciendeElCanal(t *testing.T) {
	api, nBusqueda, nArchivo := servidorQobuz(t, "USUM72500857", true, 0)
	defer api.Close()
	basura := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(`{"hola":"mundo"}`))
	}))
	defer basura.Close()

	c := clienteConOrigenDeClaves(api.URL, basura.URL)
	if url, err := c.GetStreamURL("312055179", "flac"); err == nil {
		t.Fatalf("devolvió %q con un origen de claves inválido", url)
	}
	if *nBusqueda != 0 || *nArchivo != 0 {
		t.Fatalf("hizo %d/%d peticiones sin claves válidas", *nBusqueda, *nArchivo)
	}
}

// El parseo de orígenes: comas, saltos de línea y espacios; lo que no sea URL se
// descarta en silencio.
func TestParseoDeOrigenesDeClaves(t *testing.T) {
	got := parseOrigenesClaves("https://a.example/keys, https://b.example/keys\nhttps://a.example/keys\nno-es-url")
	if len(got) != 2 || got[0] != "https://a.example/keys" || got[1] != "https://b.example/keys" {
		t.Fatalf("orígenes = %v", got)
	}
	// Sin nada configurado se usan los orígenes de fábrica: el usuario no
	// tiene que pegar credenciales para que el canal funcione.
	previos := defaultKeysURLs
	defaultKeysURLs = []string{"https://fabrica.example/keys"}
	t.Cleanup(func() { defaultKeysURLs = previos })
	porDefecto := parseOrigenesClaves("   ")
	if len(porDefecto) != 1 || porDefecto[0] != "https://fabrica.example/keys" {
		t.Fatalf("sin configurar se esperaban los orígenes de fábrica, llegó %v", porDefecto)
	}
	// Y si la app no trae ninguno, queda vacío (canal apagado, sin red).
	defaultKeysURLs = nil
	if len(parseOrigenesClaves("   ")) != 0 {
		t.Fatal("sin orígenes de fábrica, una cadena vacía no debe producir orígenes")
	}
}
