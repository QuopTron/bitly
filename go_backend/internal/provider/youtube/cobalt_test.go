// Test del respaldo de descarga por cobalt: que se use SOLO cuando yt-dlp
// falla, que respete la instancia configurada (y el apagado), que mande la
// clave cuando la hay, y que no deje escribir fuera de la carpeta con un
// nombre malicioso. Todo contra un servidor de prueba local: ningún test
// sale a Internet.

package youtube

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync/atomic"
	"testing"
)

// estadoCobalt permite cambiar la respuesta de la instancia de prueba entre
// aserciones (y guarda la última cabecera de autorización recibida).
type estadoCobalt struct {
	status string // vacío = "tunnel"
	code   string // código de error cuando status = "error"
	nombre string // nombre sugerido del archivo
	auth   string // última Authorization recibida
}

// servidorCobalt arma una instancia de prueba junto con su estado y un
// contador de peticiones (para probar que apagado NO abre red).
func servidorCobalt(t *testing.T) (*httptest.Server, *estadoCobalt, *int32) {
	t.Helper()
	estado := &estadoCobalt{}
	var pedidos int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		atomic.AddInt32(&pedidos, 1)
		if r.URL.Path == "/archivo" {
			w.Header().Set("Content-Type", "audio/mp4")
			_, _ = w.Write([]byte("AUDIO-FALSO"))
			return
		}
		estado.auth = r.Header.Get("Authorization")
		w.Header().Set("Content-Type", "application/json")
		status := estado.status
		if status == "" {
			status = "tunnel"
		}
		respuesta := map[string]any{"status": status}
		if status == "error" {
			respuesta["error"] = map[string]any{"code": estado.code}
		} else {
			respuesta["url"] = "http://" + r.Host + "/archivo"
			respuesta["filename"] = estado.nombre
		}
		_ = json.NewEncoder(w).Encode(respuesta)
	}))
	t.Cleanup(srv.Close)
	return srv, estado, &pedidos
}

// clienteConYtDlpRoto arma un cliente cuyo yt-dlp no existe: así Download
// siempre cae al respaldo, que es lo que se quiere ejercitar.
func clienteConYtDlpRoto() *Client {
	return NewClient(filepath.Join(os.TempDir(), "yt-dlp-que-no-existe-bitly"))
}

func TestCobaltEsElRespaldoCuandoYtDlpFalla(t *testing.T) {
	srv, estado, _ := servidorCobalt(t)
	estado.nombre = "tema.m4a"

	cliente := clienteConYtDlpRoto()
	cliente.SetSettings(map[string]string{"cobalt": srv.URL})

	dir := t.TempDir()
	res, err := cliente.Download("dQw4w9WgXcQ", dir, "best")
	if err != nil {
		t.Fatalf("el respaldo debía entregar el archivo: %v", err)
	}
	datos, err := os.ReadFile(res.FilePath)
	if err != nil {
		t.Fatalf("no se pudo leer lo bajado: %v", err)
	}
	if string(datos) != "AUDIO-FALSO" {
		t.Fatalf("contenido inesperado: %q", string(datos))
	}
	// El nombre y la carpeta son los que el usuario espera.
	if filepath.Base(res.FilePath) != "tema.m4a" {
		t.Fatalf("nombre inesperado: %q", res.FilePath)
	}
	if filepath.Dir(res.FilePath) != dir {
		t.Fatalf("el archivo no quedó en la carpeta del usuario: %q", res.FilePath)
	}
}

func TestCobaltApagadoNoAbreRed(t *testing.T) {
	srv, _, pedidos := servidorCobalt(t)
	cliente := clienteConYtDlpRoto()

	// Sin instancia configurada: no se toca la red.
	_, err := cliente.Download("dQw4w9WgXcQ", t.TempDir(), "best")
	if err == nil {
		t.Fatal("sin instancia, la descarga debía fallar (yt-dlp no existe)")
	}
	if atomic.LoadInt32(pedidos) != 0 {
		t.Fatalf("apagado no debe abrir red: %d peticiones", atomic.LoadInt32(pedidos))
	}
	if strings.Contains(err.Error(), "cobalt") {
		t.Fatalf("el error no debe hablar de cobalt si está apagado: %v", err)
	}

	// Y con el ajuste en "off" tampoco, aunque la URL apunte a un servidor vivo.
	cliente.SetSettings(map[string]string{"cobalt": "off"})
	if _, err := cliente.Download("dQw4w9WgXcQ", t.TempDir(), "best"); err == nil {
		t.Fatal("con cobalt apagado la descarga debía fallar")
	}
	if atomic.LoadInt32(pedidos) != 0 {
		t.Fatalf("apagado por ajuste no debe abrir red: %d peticiones", atomic.LoadInt32(pedidos))
	}
	_ = srv
}

func TestCobaltMandaLaClaveYReportaElError(t *testing.T) {
	srv, estado, _ := servidorCobalt(t)
	estado.status = "error"
	estado.code = "error.api.link.invalid"

	cliente := clienteConYtDlpRoto()
	// La barra final se recorta: la instancia recibe una URL sana.
	cliente.SetSettings(map[string]string{"cobalt": srv.URL + "/", "cobalt_token": "clave-123"})

	_, err := cliente.Download("dQw4w9WgXcQ", t.TempDir(), "best")
	if err == nil {
		t.Fatal("la instancia devolvió error: la descarga debía fallar")
	}
	if estado.auth != "Api-Key clave-123" {
		t.Fatalf("no se mandó la clave de la instancia: %q", estado.auth)
	}
	// El motivo real de la instancia tiene que llegar al log del usuario.
	if !strings.Contains(err.Error(), "error.api.link.invalid") {
		t.Fatalf("el error debe traer el código de la instancia: %v", err)
	}
	if !strings.Contains(err.Error(), "respaldo cobalt") {
		t.Fatalf("el error debe decir que el respaldo se intentó: %v", err)
	}
}

func TestCobaltPideIntervencionNoSeUsa(t *testing.T) {
	srv, estado, _ := servidorCobalt(t)
	// "picker" es una instancia que pide elegir del lado del navegador: la
	// app no puede, así que el respaldo falla con motivo.
	estado.status = "picker"
	cliente := clienteConYtDlpRoto()
	cliente.SetSettings(map[string]string{"cobalt": srv.URL})

	if _, err := cliente.Download("dQw4w9WgXcQ", t.TempDir(), "best"); err == nil {
		t.Fatal("picker no puede entregar el archivo: debía fallar")
	}
}

func TestNombreSeguroCobalt(t *testing.T) {
	casos := []struct {
		nombre      string
		contentType string
		esperado    string
	}{
		{"tema.m4a", "audio/mp4", "tema.m4a"},
		// Una instancia ajena no puede escribir fuera de la carpeta.
		{"../../evil.sh", "audio/mp4", "abc.m4a"},
		{`..\..\evil.sh`, "audio/mp4", "abc.m4a"},
		{"", "audio/mpeg", "abc.mp3"},
		{"", "audio/ogg", "abc.opus"},
		{"", "audio/wav", "abc.wav"},
		{"", "application/octet-stream", "abc.m4a"},
	}
	for _, c := range casos {
		if got := nombreSeguroCobalt(c.nombre, c.contentType, "abc"); got != c.esperado {
			t.Errorf("nombreSeguroCobalt(%q, %q) = %q, se esperaba %q",
				c.nombre, c.contentType, got, c.esperado)
		}
	}
}
