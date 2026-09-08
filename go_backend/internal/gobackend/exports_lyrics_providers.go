package gobackend

import (
	"github.com/zarz/bitly/go_backend/internal/lyrics"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

// wireExtensionLyricsProviders appends one lyrics.Provider per extension that
// exports fetchLyrics (the SpotiFLAC lyrics_provider contract). Extension
// providers are appended AFTER the built-ins (lrclib/genius) so the common
// case stays instant; when built-ins miss, a signed-in extension (e.g. Apple
// Music with a Media User Token) can still deliver word-level Apple karaoke.
func wireExtensionLyricsProviders(client *lyrics.Client, reg *provider.Registry) {
	if client == nil || reg == nil {
		return
	}
	for _, p := range reg.All() {
		ep, ok := p.(*provider.ExtensionProvider)
		if !ok || !ep.HasLyricsProvider() {
			continue
		}
		name := p.Name()
		client.AddProvider(lyrics.NewFuncProvider(name, func(trackName, artistName string, durationMs int) (*lyrics.Lyrics, error) {
			return ep.FetchLyrics(trackName, artistName, durationMs)
		}))
	}
}
