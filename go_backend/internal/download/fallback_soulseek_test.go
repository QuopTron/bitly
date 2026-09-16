// fallback_soulseek_test.go — fija que Soulseek PARTICIPA del rescate, y que lo
// hace por el único camino que puede: la DESCARGA.
//
// Por qué existe: Soulseek es la única red de catálogo comercial a la que se
// entra sin invitación, sin pago y sin dar datos personales, y sus archivos son
// FLAC reales. Pero su protocolo es peer-to-peer, así que NO puede servir un
// stream: su GetStreamURL no existe y el audio lo trae DescargarAArchivo (el par
// que sube abre la conexión HACIA NOSOTROS). Eso deja dos formas silenciosas de
// perderlo, y este test las cubre:
//
//  1. que alguien lo devuelva a la carrera de streaming (donde no puede entregar
//     ni un byte y sólo gasta un turno del pool + una búsqueda P2P por canción);
//  2. que el orquestador de descargas lo filtre del orden (por ser un proveedor
//     nativo sin URL de stream) y entonces NUNCA se lo consulte, con el usuario
//     creyendo que "Soulseek no encuentra nada".
package download

import (
	"testing"

	"github.com/zarz/bitly/go_backend/internal/provider"
	"github.com/zarz/bitly/go_backend/internal/provider/soulseek"
)

// contieneNombre reporta si [nombres] incluye [buscado].
func contieneNombre(nombres []string, buscado string) bool {
	for _, n := range nombres {
		if n == buscado {
			return true
		}
	}
	return false
}

func TestSoulseekParticipaDelRescateDeDescarga(t *testing.T) {
	// 1) El orden preferido tiene que incluir a Soulseek (si no, la descarga
	//    nunca llega a su tier lossless) junto a Internet Archive, que es la otra
	//    fuente de FLAC sin sesión.
	for _, n := range []string{"soulseek", "internetarchive"} {
		if !contieneNombre(preferredStreamOrder, n) {
			t.Fatalf("%q no está en preferredStreamOrder: nunca participaría del rescate", n)
		}
	}

	// 2) Registrado, el orquestador tiene que conservarlo. construirOrdenFallback
	//    filtra lo que no puede aportar audio (catálogos de metadata, extensiones
	//    sin capacidad de descarga), así que este paso verifica que un proveedor
	//    nativo SIN GetStreamURL pero CON DescargarAArchivo sobreviva el filtro.
	reg := provider.NewRegistry()
	reg.Register(soulseek.NewClient("", ""))
	orden := construirOrdenFallback(reg, preferredStreamOrder)
	if !contieneNombre(orden, "soulseek") {
		t.Fatalf("construirOrdenFallback descartó soulseek: %v", orden)
	}

	// 3) Y el camino de intento tiene que ser el de descarga propia, no el que
	//    pide una URL: si esta precedencia se rompe, la descarga falla con
	//    "sin stream" en una fuente que sí tiene el archivo.
	if _, ok := interface{}(soulseek.NewClient("", "")).(descargadorPropio); !ok {
		t.Fatal("soulseek debe implementar descargadorPropio (DescargarAArchivo)")
	}
}
