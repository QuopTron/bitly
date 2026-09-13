package streaming

import "github.com/zarz/bitly/go_backend/internal/provider"

// streamingProviderOrder returns the streaming providers that are actually
// registered, best-first — the same effective order the download orchestrator
// uses (exact sources first: deezer/qobuz/tidal/amazon, then youtube/ytmusic,
// with soundcloud's loose name-search last). Unlike [streamingProviders] it
// reflects the live registry (extension-loaded names), so a registered
// source is never skipped and a missing one is never probed.
func ordenProvidersStreaming(reg *provider.Registry) []string {
	if reg == nil {
		return nil
	}
	var out []string
	seen := map[string]bool{}
	neverStream := map[string]bool{
		"musicbrainz": true,
		"spotify":     true,
		"apple":       true,
	}
	agregar := func(nombres []string) {
		for _, name := range nombres {
			if seen[name] || neverStream[name] {
				continue
			}
			p := reg.Get(name)
			if p == nil {
				continue
			}
			if ep, ok := p.(*provider.ExtensionProvider); ok && !ep.DownloadCapable() {
				continue
			}
			out = append(out, name)
			seen[name] = true
		}
	}

	// 1) Grabación EXACTA (por ISRC): es lo primero que se intenta.
	agregar(proveedoresExactos)
	// 2) El resto de los proveedores de streaming, saltando a propósito los
	//    re-subidos (se agregan después).
	resto := make([]string, 0, len(streamingProviders))
	for _, name := range streamingProviders {
		if esProveedorReSubido(name) {
			continue
		}
		resto = append(resto, name)
	}
	agregar(resto)
	// 3) Re-subidos (YouTube / YouTube Music / SoundCloud): último recurso, para
	//    que una fuente exacta siempre tenga su turno antes que ellos.
	agregar(proveedoresReSubidos)
	// 4) Cualquier otra extensión registrada que sepa streamear.
	for _, name := range reg.Names() {
		if seen[name] || neverStream[name] || !esProviderStreaming(name) {
			continue
		}
		agregar([]string{name})
	}
	return out
}

// rescueProviderOnce probes ONE provider for a playable stream, honoring the
