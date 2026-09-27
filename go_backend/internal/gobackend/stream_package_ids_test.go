// stream_package_ids_test.go — El pedido de streaming debe derivar los ids
// cross-proveedor que no trae, igual que la descarga.
//
// Qué se cuida: la app manda `preferredProvider` + `trackID` y, para ítems de
// feed/búsqueda, los ids cross-proveedor van vacíos. Sin derivarlos, un ítem de
// Tidal/Deezer/Qobuz/Spotify no puede rescatar la grabación EXACTA por
// identidad en otra fuente y cae a una búsqueda por nombre. La descarga ya lo
// hacía (orchestrator_trackid.go); acá se fija que el STREAMING haga lo mismo
// en el borde del RPC, antes de StreamQuick/RescueStreamURL.
package gobackend

import (
	"encoding/json"
	"os"
	"strings"
	"testing"
)

func TestPedidoDeStreamingDerivaIDsCrossDelFeed(t *testing.T) {
	casos := []struct {
		nombre       string
		payload      string
		espSP, espDZ string
		espTD, espQZ string
	}{
		{
			nombre:  "tidal-web: el id numérico pasa a tidalId",
			payload: `{"preferredProvider":"tidal-web","trackID":"123456","quality":"high","trackName":"X","artistName":"Y"}`,
			espTD:   "123456",
		},
		{
			nombre:  "deezer: el id numérico pasa a deezerId",
			payload: `{"preferredProvider":"deezer","trackID":"3733293352","quality":"high","trackName":"X","artistName":"Y"}`,
			espDZ:   "3733293352",
		},
		{
			nombre:  "spotify-web: el id de 22 pasa a spotifyId",
			payload: `{"preferredProvider":"spotify-web","trackID":"6XbtvPmIpyCbjuT0e8cQtp","quality":"high","trackName":"X","artistName":"Y"}`,
			espSP:   "6XbtvPmIpyCbjuT0e8cQtp",
		},
		{
			nombre:  "qobuz-web: el id numérico pasa a qobuzId",
			payload: `{"preferredProvider":"qobuz-web","trackID":"98765","quality":"high","trackName":"X","artistName":"Y"}`,
			espQZ:   "98765",
		},
		{
			nombre:  "apple-music (id propio numérico) NO inventa un id cross",
			payload: `{"preferredProvider":"apple-music","trackID":"6814997425","quality":"high","trackName":"X","artistName":"Y"}`,
		},
		{
			nombre:  "un id ya presente no se pisa",
			payload: `{"preferredProvider":"deezer","trackID":"111","deezerId":"222","quality":"high","trackName":"X","artistName":"Y"}`,
			espDZ:   "222",
		},
	}
	for _, c := range casos {
		t.Run(c.nombre, func(t *testing.T) {
			var p streamPackageParams
			if err := json.Unmarshal([]byte(c.payload), &p); err != nil {
				t.Fatalf("payload ilegible: %v", err)
			}
			p.derivarIDsCross()
			if p.SpotifyID != c.espSP || p.DeezerID != c.espDZ || p.TidalID != c.espTD || p.QobuzID != c.espQZ {
				t.Fatalf("ids derivados = (sp=%q dz=%q td=%q qz=%q); se esperaba (sp=%q dz=%q td=%q qz=%q)",
					p.SpotifyID, p.DeezerID, p.TidalID, p.QobuzID, c.espSP, c.espDZ, c.espTD, c.espQZ)
			}
		})
	}
}

// TestGetStreamPackageDerivaAntesDeResolver es una guarda de FORMA: GetStreamPackage
// tiene que llamar a derivarIDsCross() DESPUÉS de decodificar el payload (si la
// llamada se pierde, la derivación existe pero no se usa y el bug vuelve en
// silencio).
func TestGetStreamPackageDerivaAntesDeResolver(t *testing.T) {
	crudo, err := os.ReadFile("stream_package.go")
	if err != nil {
		t.Fatalf("no se pudo leer stream_package.go: %v", err)
	}
	if !strings.Contains(string(crudo), "params.derivarIDsCross()") {
		t.Error("GetStreamPackage ya no deriva los ids cross-proveedor del pedido (params.derivarIDsCross())")
	}
}
