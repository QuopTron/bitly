package streaming

import (
	"errors"
	"sync"
	"testing"
	"time"
)

// errSesionFria representa el fallo transitorio que el reintento del cliente
// tiene que poder volver a preguntar.
var errSesionFria = errors.New("sesión fría")

// conMemoStreamURL enciende la caché de URLs para el test y la apaga al
// terminar (la suite arranca con ella apagada, ver main_test.go). También
// vacía la caché antes y después: una entrada de otro test no puede colarse.
func conMemoStreamURL(t *testing.T) {
	t.Helper()
	limpiarMemoStreamURL()
	MemoStreamURL(true)
	t.Cleanup(func() {
		MemoStreamURL(false)
		limpiarMemoStreamURL()
	})
}

// TestStreamURLMemoReutilizaElExito: la misma identidad resuelta dos veces
// paga UNA sola ida al proveedor. Cada vuelta era una firma de sesión y una
// petición de red más, y las fases del rescate vuelven a preguntar lo mismo
// que ya contestó la fase anterior.
func TestStreamURLMemoReutilizaElExito(t *testing.T) {
	conMemoStreamURL(t)

	llamadas := 0
	p := &stubProvider{name: "memo-exito", resolve: func() (string, error) {
		llamadas++
		return "http://cdn/una.flac", nil
	}}

	primera, err := PedirStreamURL(p, "track-1", "high")
	if err != nil || primera == "" {
		t.Fatalf("primera petición: url=%q err=%v", primera, err)
	}
	segunda, err := PedirStreamURL(p, "track-1", "high")
	if err != nil || segunda != primera {
		t.Fatalf("segunda petición: url=%q err=%v", segunda, err)
	}
	if llamadas != 1 {
		t.Errorf("GetStreamURL llamado %d veces, se esperaba 1 (la segunda sale de la caché)", llamadas)
	}
}

// TestStreamURLMemoNoRetieneErrores es la garantía del reintento del cliente:
// un tap que vuelve a pedir el mismo track 400 ms después (sesión fría,
// proveedor recién enfriado) tiene que llegar AL PROVEEDOR, no a un eco del
// primer fallo. Por eso solo se memorizan los éxitos.
func TestStreamURLMemoNoRetieneErrores(t *testing.T) {
	conMemoStreamURL(t)

	llamadas := 0
	p := &stubProvider{name: "memo-error", resolve: func() (string, error) {
		llamadas++
		return "", errSesionFria
	}}

	if _, err := PedirStreamURL(p, "track-2", "high"); err == nil {
		t.Fatal("se esperaba el error del proveedor")
	}
	if _, err := PedirStreamURL(p, "track-2", "high"); err == nil {
		t.Fatal("el reintento también debía ver el error")
	}
	if llamadas != 2 {
		t.Errorf("GetStreamURL llamado %d veces, se esperaba 2 (los errores no se memorizan)", llamadas)
	}
}

// TestStreamURLMemoComparteLaPeticionEnVuelo: dos resoluciones idénticas que
// corren a la vez comparten UNA llamada. Es el caso de un tap que entra
// mientras el prefetch del mismo track todavía resolvía.
func TestStreamURLMemoComparteLaPeticionEnVuelo(t *testing.T) {
	conMemoStreamURL(t)

	var (
		mu       sync.Mutex
		llamadas int
		entrando = make(chan struct{})
		suelto   = make(chan struct{})
	)
	p := &stubProvider{name: "memo-vuelo", resolve: func() (string, error) {
		mu.Lock()
		llamadas++
		primer := llamadas == 1
		mu.Unlock()
		if primer {
			close(entrando)
		}
		<-suelto
		return "http://cdn/compartida.flac", nil
	}}

	const concurrentes = 4
	var (
		wg      sync.WaitGroup
		muURL   sync.Mutex
		urls    []string
		errores int
	)
	// La primera goroutine entra y queda esperada dentro del proveedor; las
	// demás se lanzan recién cuando ya está en vuelo.
	wg.Add(1)
	go func() {
		defer wg.Done()
		u, err := PedirStreamURL(p, "track-3", "high")
		muURL.Lock()
		defer muURL.Unlock()
		if err != nil {
			errores++
		}
		urls = append(urls, u)
	}()
	<-entrando

	for i := 0; i < concurrentes-1; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			u, err := PedirStreamURL(p, "track-3", "high")
			muURL.Lock()
			defer muURL.Unlock()
			if err != nil {
				errores++
			}
			urls = append(urls, u)
		}()
	}
	time.Sleep(50 * time.Millisecond) // que todas lleguen al single-flight
	close(suelto)
	wg.Wait()

	mu.Lock()
	total := llamadas
	mu.Unlock()
	if total != 1 {
		t.Errorf("GetStreamURL llamado %d veces con %d resoluciones idénticas en vuelo, se esperaba 1", total, concurrentes)
	}
	if errores != 0 || len(urls) != concurrentes {
		t.Fatalf("resultados: %d urls, %d errores", len(urls), errores)
	}
	for _, u := range urls {
		if u != "http://cdn/compartida.flac" {
			t.Errorf("url inesperada: %q", u)
		}
	}
}

// TestStreamURLMemoSeparaPorCalidad: la caché es por proveedor+identidad+CALIDAD.
// Mezclarlas devolvería un FLAC donde se pidió MP3 (o al revés).
func TestStreamURLMemoSeparaPorCalidad(t *testing.T) {
	conMemoStreamURL(t)

	resoluciones := 0
	p := &stubProvider{name: "memo-calidad", resolve: func() (string, error) {
		resoluciones++
		return "http://cdn/" + string(rune('a'+resoluciones)) + ".bin", nil
	}}
	pedir := func(q string) string {
		u, err := PedirStreamURL(p, "track-4", q)
		if err != nil {
			t.Fatalf("calidad %s: %v", q, err)
		}
		return u
	}

	flac := pedir("flac")
	alta := pedir("high")
	if flac == alta {
		t.Errorf("calidades distintas devolvieron la misma URL: %q", flac)
	}
	if got := pedir("flac"); got != flac {
		t.Errorf("la segunda vez por flac devolvió %q, se esperaba %q", got, flac)
	}
	if resoluciones != 2 {
		t.Errorf("GetStreamURL resuelto %d veces, se esperaba 2 (una por calidad)", resoluciones)
	}
}

// TestOlvidarStreamURLVuelveAPedir es la salida de emergencia: cuando el
// llamador rechaza la URL (un clip de muestra), la entrada se tira y el
// próximo pedido le vuelve a preguntar al proveedor.
func TestOlvidarStreamURLVuelveAPedir(t *testing.T) {
	conMemoStreamURL(t)

	llamadas := 0
	p := &stubProvider{name: "memo-olvidar", resolve: func() (string, error) {
		llamadas++
		return "http://cdn/clip.wav", nil
	}}

	if _, err := PedirStreamURL(p, "track-5", "high"); err != nil {
		t.Fatalf("primera: %v", err)
	}
	olvidarStreamURL("memo-olvidar", "track-5", "high")
	if _, err := PedirStreamURL(p, "track-5", "high"); err != nil {
		t.Fatalf("después de olvidar: %v", err)
	}
	if llamadas != 2 {
		t.Errorf("GetStreamURL llamado %d veces, se esperaba 2 (olvidar la entrada obliga a volver a preguntar)", llamadas)
	}
}

// TestMemoApagadaPasaDirecto es el estado por defecto de la suite: con la
// caché apagada cada llamada llega al proveedor, sin memorizar nada. Sin esta
// garantía un test que cuente llamadas no sabría si está midiendo al
// proveedor o a la caché.
func TestMemoApagadaPasaDirecto(t *testing.T) {
	llamadas := 0
	p := &stubProvider{name: "memo-apagada", resolve: func() (string, error) {
		llamadas++
		return "http://cdn/directa.flac", nil
	}}

	for i := 0; i < 3; i++ {
		if _, err := PedirStreamURL(p, "track-6", "high"); err != nil {
			t.Fatalf("petición %d: %v", i+1, err)
		}
	}
	if llamadas != 3 {
		t.Errorf("GetStreamURL llamado %d veces con la caché apagada, se esperaba 3", llamadas)
	}
}
