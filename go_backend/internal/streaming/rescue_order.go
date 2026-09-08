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
	for _, name := range streamingProviders {
		p := reg.Get(name)
		if p == nil || neverStream[name] {
			continue
		}
		if ep, ok := p.(*provider.ExtensionProvider); ok && !ep.DownloadCapable() {
			continue
		}
		out = append(out, name)
		seen[name] = true
	}
	for _, name := range reg.Names() {
		if seen[name] || neverStream[name] || !esProviderStreaming(name) {
			continue
		}
		p := reg.Get(name)
		if ep, ok := p.(*provider.ExtensionProvider); ok && !ep.DownloadCapable() {
			continue
		}
		out = append(out, name)
	}
	return out
}

// rescueProviderOnce probes ONE provider for a playable stream, honoring the
