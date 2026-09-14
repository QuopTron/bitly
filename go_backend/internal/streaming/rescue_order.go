package streaming

import "github.com/zarz/bitly/go_backend/internal/provider"

// ordenProvidersStreaming devuelve las fuentes de AUDIO registradas, en el
// orden de proveedoresAudio.
//
// Qué cambió y por qué: antes esta lista se armaba con streamingProviders
// (todos los que saben streamear, catálogos incluidos) y filtraba por
// DownloadCapable. Eso metía en la carrera a spotify-web/qobuz-web/tidal-web/
// amazon/apple-music, que sin sesión firmada no pueden resolver una URL: en el
// emulador eso significaba que la fase exacta gastaba 1,5-5,8s (y hasta 6,4s en
// otros temas) devolviendo nada, retrasando el turno del re-subido que SÍ tenía
// el audio (ytmusic-spotiflac), y ocupando slots del pool de workers.
//
// Decisión de producto: los catálogos sirven para BUSCAR (identidad, ISRC, ids
// cross-proveedor), no para streamear. El audio sale de YouTube —sí o sí— y,
// cuando se pidió sin pérdida, de Internet Archive / Soulseek / flac-rescue.
// Ver proveedoresAudio en play_types.go.
//
// Se sigue filtrando por DownloadCapable(): una extensión registrada que no
// sabe resolver audio no puede aportar un stream, y sondearla solo cuesta un
// turno del pool.
func ordenProvidersStreaming(reg *provider.Registry) []string {
	if reg == nil {
		return nil
	}
	out := make([]string, 0, len(proveedoresAudio))
	for _, name := range proveedoresAudio {
		p := reg.Get(name)
		if p == nil {
			continue
		}
		if ep, ok := p.(*provider.ExtensionProvider); ok && !ep.DownloadCapable() {
			continue
		}
		out = append(out, name)
	}
	return out
}

// rescueProviderOnce probes ONE provider for a playable stream, honoring the
