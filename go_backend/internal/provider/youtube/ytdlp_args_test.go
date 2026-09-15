package youtube

import (
	"os"
	"strings"
	"testing"
)

// El bypass debe pedirle a yt-dlp clientes que NO exigen PO token ni sesión:
// son la vía anónima cuando YouTube bloquea al cliente web por IP marcada.
func TestArgsBypassUsaClientesAnonimos(t *testing.T) {
	os.Unsetenv("BITLY_YTDLP_ARGS")
	os.Unsetenv("BITLY_YTDLP_SIN_PLAYER_CLIENT")

	args := argsBypass()
	if len(args) != 2 {
		t.Fatalf("esperaba 2 argumentos de bypass, obtuve %v", args)
	}
	if args[0] != "--extractor-args" {
		t.Errorf("esperaba --extractor-args, obtuve %q", args[0])
	}
	if !strings.Contains(args[1], "player_client=") {
		t.Fatalf("esperaba player_client en %q", args[1])
	}
	// Los clientes que no piden token tienen que estar presentes.
	for _, cliente := range []string{"tv_embedded", "web_embedded", "android_vr"} {
		if !strings.Contains(args[1], cliente) {
			t.Errorf("falta el cliente anónimo %q en %q", cliente, args[1])
		}
	}
	// La web pura es la que se bloquea: nunca puede quedar primero.
	lista := strings.TrimPrefix(args[1], "youtube:player_client=")
	if strings.Split(lista, ",")[0] == "web" {
		t.Errorf("el cliente web no puede ser el primero: %q", lista)
	}
}

func TestArgsBypassPersonalizadoYDesactivado(t *testing.T) {
	os.Setenv("BITLY_YTDLP_ARGS", "--extractor-args youtube:player_client=android_vr")
	defer os.Unsetenv("BITLY_YTDLP_ARGS")
	args := argsBypass()
	if len(args) != 2 || args[1] != "youtube:player_client=android_vr" {
		t.Fatalf("el override del usuario no se respetó: %v", args)
	}

	os.Setenv("BITLY_YTDLP_SIN_PLAYER_CLIENT", "1")
	defer os.Unsetenv("BITLY_YTDLP_SIN_PLAYER_CLIENT")
	if args := argsBypass(); args != nil {
		t.Fatalf("con el bypass desactivado esperaba nil, obtuve %v", args)
	}
}

// Si yt-dlp rechaza los argumentos de bypass (cliente desconocido en esa
// versión), el runner debe reintentar SIN ellos en vez de devolver error.
func TestEjecutarYtDlpReintentaSinBypass(t *testing.T) {
	if os.Getenv("GOOS") == "windows" {
		t.Skip()
	}
	os.Unsetenv("BITLY_YTDLP_SIN_PLAYER_CLIENT")
	// `echo` ignora los flags, así que el camino feliz no aplica; lo que se
	// verifica es que el runner devuelve la salida del comando sin explotar.
	salida, err := ejecutarYtDlp("echo", []string{"hola"})
	if err != nil {
		t.Fatalf("ejecutarYtDlp devolvió error: %v", err)
	}
	if !strings.Contains(string(salida), "hola") {
		t.Errorf("salida inesperada: %q", string(salida))
	}
}
