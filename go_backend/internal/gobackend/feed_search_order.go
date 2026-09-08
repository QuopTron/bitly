package gobackend

import "github.com/zarz/bitly/go_backend/internal/provider"

// orderedSearchProviders returns providers ordered for a "Todas" search:
// el manifest primary búsqueda extension primero (SpotiFLAC's// defaultSearchExtension — our deezer), then every other registered provider.
// This lets el sequential búsqueda abajo try el mejor source primero y solo// fall through when it returns nothing (e.g. deezer rate-limited), instead of
// firing every search API in parallel and tripping 429s on each keystroke.
func providersBusquedaOrdenados() []provider.Provider {
	if reg == nil {
		return nil
	}
	all := reg.All()
	primary := map[string]bool{}
	for _, e := range bundledExts {
		if e.Search.Primary {
			primary[e.ID] = true
		}
	}
	ordered := make([]provider.Provider, 0, len(all))
	seen := map[string]bool{}
	add := func(p provider.Provider) {
		if p == nil || seen[p.Name()] {
			return
		}
		seen[p.Name()] = true
		ordered = append(ordered, p)
	}
	for _, p := range all {
		if primary[p.Name()] {
			add(p)
		}
	}
	for _, p := range all {
		if !primary[p.Name()] {
			add(p)
		}
	}
	return ordered
}

// searchAllSourceBest searches every provider IN PARALLEL (with a global
// timeout) and returns the combined results from ALL of them, each capped at
// [limit]. A rate-limited (cooled) source is skipped fast. The Flutter side
// groups the returned items by source, so a "Todas" search shows every
// extension's results in its own section instead of only the primary source's
