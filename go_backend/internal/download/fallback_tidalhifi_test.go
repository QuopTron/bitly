// fallback_tidalhifi_test.go — fija que el canal "Tidal HiFi" PARTICIPA del
// rescate de descarga, y por el único camino que puede.
//
// Por qué existe: Tidal HiFi es catálogo DISTINTO al de Qobuz y entrega FLAC
// real (16/44.1 y 24 bits) sin cuenta y sin captcha — su audio llega por
// descarga segmentada, por eso su GetStreamURL devuelve error a propósito. Eso
// deja dos formas silenciosas de perderlo, y este test las cubre:
//
//  1. que el orquestador lo filtre del orden (por ser un proveedor nativo SIN
//     URL de stream) y entonces NUNCA se lo consulte: el usuario pediría FLAC,
//     habría una fuente que lo tiene, y la app bajaría un re-subido de YouTube
//     creyendo que no había nada mejor;
//  2. que quede después de YouTube en el orden, con lo que un pedido sin
//     pérdida se resolvería con audio con pérdida antes de intentarlo.
package download

import (
	"testing"

	"github.com/zarz/bitly/go_backend/internal/provider"
	"github.com/zarz/bitly/go_backend/internal/provider/tidalhifi"
)

func TestTidalHiFiParticipaDelRescateDeDescarga(t *testing.T) {
	// 1) El orden preferido tiene que incluir el canal: es de las fuentes que
	//    entregan sin pérdida sin sesión, junto a flac-rescue / Soulseek /
	//    Internet Archive.
	if !contieneNombre(preferredStreamOrder, "tidal-hifi") {
		t.Fatal("tidal-hifi no está en preferredStreamOrder: nunca participaría del rescate")
	}

	// 2) Y tiene que ir ANTES de YouTube: con calidad sin pérdida, un FLAC de
	//    Tidal es mejor que un re-subido, así que el orden no puede dejarlo
	//    para después del atajo con pérdida.
	idxTidal := indiceEn(preferredStreamOrder, "tidal-hifi")
	idxYT := indiceEn(preferredStreamOrder, "youtube")
	if idxYT >= 0 && idxTidal > idxYT {
		t.Fatalf("tidal-hifi (pos %d) quedó después de youtube (pos %d)", idxTidal, idxYT)
	}

	// 3) Registrado, el orquestador tiene que conservarlo: construirOrdenFallback
	//    filtra lo que no puede aportar audio (catálogos de metadata, extensiones
	//    sin capacidad de descarga), así que este paso verifica que un proveedor
	//    nativo SIN URL de stream pero CON DescargarAArchivo sobreviva el filtro.
	reg := provider.NewRegistry()
	reg.Register(tidalhifi.NewClient())
	orden := construirOrdenFallback(reg, preferredStreamOrder)
	if !contieneNombre(orden, "tidal-hifi") {
		t.Fatalf("construirOrdenFallback descartó tidal-hifi: %v", orden)
	}

	// 4) Y el camino de intento tiene que ser el de descarga propia: si se
	//    tomara el nativo, la descarga fallaría con "el audio llega en
	//    segmentos" en una fuente que sí tiene el archivo.
	if _, ok := interface{}(tidalhifi.NewClient()).(descargadorPropio); !ok {
		t.Fatal("tidal-hifi debe implementar descargadorPropio (DescargarAArchivo)")
	}
}

// indiceEn devuelve la posición de [buscado] en [nombres], o -1.
func indiceEn(nombres []string, buscado string) int {
	for i, n := range nombres {
		if n == buscado {
			return i
		}
	}
	return -1
}
