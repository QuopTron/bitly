package lyrics

import (
	"regexp"
	"strings"
	"sync"
)

const (
	ProviderLRCLIB     = "lrclib"
	ProviderNetease    = "netease"
	ProviderMusixmatch = "musixmatch"
	ProviderAppleMusic = "apple_music"
	ProviderQQMusic    = "qqmusic"
	ProviderSpotify    = "spotify"
	ProviderDeezer     = "deezer"
	ProviderYouTube    = "youtube"
	ProviderKugou      = "kugou"
	ProviderGenius     = "genius"
)

var DefaultLyricsProviders = []string{
	ProviderLRCLIB,
	ProviderAppleMusic,
}

var (
	lyricsProvidersMu sync.RWMutex
	lyricsProviders   []string

	lyricsFetchOptionsMu sync.RWMutex
	lyricsFetchOptions   = LyricsFetchOptions{
		MultiPersonWordByWord: true,
	}
)

func SetLyricsProviderOrder(providers []string) {
	lyricsProvidersMu.Lock()
	defer lyricsProvidersMu.Unlock()

	if len(providers) == 0 {
		lyricsProviders = nil
		return
	}

	validNames := map[string]bool{
		ProviderLRCLIB:     true,
		ProviderNetease:    true,
		ProviderMusixmatch: true,
		ProviderAppleMusic: true,
		ProviderQQMusic:    true,
		ProviderSpotify:    true,
		ProviderDeezer:     true,
		ProviderYouTube:    true,
		ProviderKugou:      true,
		ProviderGenius:     true,
	}

	var valid []string
	for _, p := range providers {
		normalized := strings.ToLower(strings.TrimSpace(p))
		if validNames[normalized] {
			valid = append(valid, normalized)
		}
	}
	lyricsProviders = valid
}

func GetLyricsProviderOrder() []string {
	lyricsProvidersMu.RLock()
	defer lyricsProvidersMu.RUnlock()
	if len(lyricsProviders) == 0 {
		return DefaultLyricsProviders
	}
	result := make([]string, len(lyricsProviders))
	copy(result, lyricsProviders)
	return result
}

func GetAvailableLyricsProviders() []map[string]interface{} {
	return []map[string]interface{}{
		{"id": ProviderLRCLIB, "name": "LRCLIB", "has_proxy_dependency": false, "description": "Open-source synced lyrics database"},
		{"id": ProviderNetease, "name": "Netease", "has_proxy_dependency": true, "description": "NetEase Cloud Music lyrics"},
		{"id": ProviderMusixmatch, "name": "Musixmatch", "has_proxy_dependency": true, "description": "Musixmatch lyrics"},
		{"id": ProviderAppleMusic, "name": "Apple Music", "has_proxy_dependency": true, "description": "Apple Music synced lyrics"},
		{"id": ProviderQQMusic, "name": "QQ Music", "has_proxy_dependency": true, "description": "QQ Music lyrics"},
		{"id": ProviderSpotify, "name": "Spotify", "has_proxy_dependency": true, "description": "Spotify synced lyrics"},
		{"id": ProviderDeezer, "name": "Deezer", "has_proxy_dependency": true, "description": "Deezer lyrics"},
		{"id": ProviderYouTube, "name": "YouTube", "has_proxy_dependency": true, "description": "YouTube lyrics"},
		{"id": ProviderKugou, "name": "Kugou", "has_proxy_dependency": true, "description": "Kugou lyrics"},
		{"id": ProviderGenius, "name": "Genius", "has_proxy_dependency": true, "description": "Genius lyrics"},
	}
}

func SetLyricsFetchOptions(opts LyricsFetchOptions) {
	opts.MusixmatchLanguage = strings.ToLower(strings.TrimSpace(opts.MusixmatchLanguage))
	opts.MusixmatchLanguage = regexp.MustCompile(`[^a-z0-9\-_]`).ReplaceAllString(opts.MusixmatchLanguage, "")
	if len(opts.MusixmatchLanguage) > 16 {
		opts.MusixmatchLanguage = opts.MusixmatchLanguage[:16]
	}

	lyricsFetchOptionsMu.Lock()
	defer lyricsFetchOptionsMu.Unlock()
	changed := lyricsFetchOptions != opts
	lyricsFetchOptions = opts
	if changed {
		globalLyricsCache.ClearAll()
	}
}

func GetLyricsFetchOptions() LyricsFetchOptions {
	lyricsFetchOptionsMu.RLock()
	defer lyricsFetchOptionsMu.RUnlock()
	return lyricsFetchOptions
}
