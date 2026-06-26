package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
	"github.com/zarz/bitly/go_backend_bitly/internal/sources/core"
	deezer "github.com/zarz/bitly/go_backend_bitly/internal/sources/providers/deezer"
	qobuz "github.com/zarz/bitly/go_backend_bitly/internal/sources/providers/qobuz"
	tidal "github.com/zarz/bitly/go_backend_bitly/internal/sources/providers/tidal"
)

var autoInstallOnce sync.Once

var displayNameMap map[string]string
var displayNameOnce sync.Once

func buildDisplayNameMap() {
	displayNameMap = map[string]string{
		"deezer":       "Deezer",
		"qobuz":        "Qobuz",
		"tidal":        "Tidal",
		"apple-music":  "Apple Music",
		"soundcloud":   "SoundCloud",
	}
	if extStore == nil {
		return
	}
	reg, err := extStore.FetchRegistry(false)
	if err != nil || reg == nil {
		return
	}
	for _, ext := range reg.Extensions {
		name := ext.DisplayName
		if name == "" {
			name = ext.Name
		}
		displayNameMap[ext.ID] = name
	}
}

func getDisplayName(sourceID string) string {
	if name, ok := displayNameMap[sourceID]; ok {
		return name
	}
	// Fallback: capitalize and replace hyphens
	words := strings.FieldsFunc(sourceID, func(r rune) bool { return r == '-' || r == '_' })
	for i, w := range words {
		if len(w) > 0 {
			words[i] = strings.ToUpper(w[:1]) + w[1:]
		}
	}
	return strings.Join(words, " ")
}

type feedSectionResponse struct {
	Source      string     `json:"source"`
	DisplayName string     `json:"display_name"`
	Title       string     `json:"title"`
	Items       []feedItem `json:"items"`
}

var feedLocale string

func registerV2Feed(reg *rpc.Registry) {
	reg.Register("getHomeFeed", func(params map[string]interface{}) (interface{}, error) {
		ensureExtensionInit()
		ensureExtensionsDir()
		autoInstallOnce.Do(autoInstallExtensions)
		displayNameOnce.Do(buildDisplayNameMap)
		loadExtensionsOnDemand()

		// Read locale from params (optional, default "en")
		feedLocale = "en"
		if loc, ok := params["locale"].(string); ok && loc != "" {
			feedLocale = loc
		}

		var all []feedSectionResponse
		extSections := callExtensionFeeds()
		for _, s := range extSections {
			all = append(all, feedSectionResponse{
				Source: s.Source, DisplayName: getDisplayName(s.Source),
				Title: s.Title, Items: s.Items,
			})
		}
		builtinSections, _ := builtinHomeFeed()
		for _, s := range builtinSections {
			all = append(all, feedSectionResponse{
				Source: s.Source, DisplayName: getDisplayName(s.Source),
				Title: s.Title, Items: s.Items,
			})
		}
		if len(all) == 0 {
			log.Printf("[feed] no sections from any source")
			return "[]", nil
		}
		b, _ := json.Marshal(all)
		log.Printf("[feed] returning %d sections from %d sources", len(all), countUniqueSourceIDs(all))
		return string(b), nil
	})
}

func t(en, es string) string {
	if feedLocale == "es" {
		return es
	}
	return en
}

func countUniqueSourceIDs(sections []feedSectionResponse) int {
	seen := make(map[string]bool)
	for _, s := range sections {
		seen[s.Source] = true
	}
	return len(seen)
}

var knownExtensionIDs = []string{
	"spotify-web",
	"amazon",
	"apple-music",
	"soundcloud",
	"ytmusic-spotiflac",
	"deezer",
	"pandora",
	"qobuz-web",
	"tidal-web",
}

// autoInstallExtensions downloads and installs all missing extensions from the registry.
func autoInstallExtensions() {
	extDir := extManager.ExtensionsDir()
	if extDir == "" {
		log.Printf("[feed] auto-install: no extensions directory set, skipping")
		return
	}

	installed := 0
	for _, extID := range knownExtensionIDs {
		if extRuntime.IsLoaded(extID) {
			continue
		}

		// Check if already unpacked on disk
		diskPath := filepath.Join(extDir, extID, "index.js")
		if _, err := os.Stat(diskPath); err == nil {
			// Already on disk but not loaded — try loading now
			ext, err := extManager.LoadExtensionFromDir(filepath.Join(extDir, extID))
			if err != nil || ext == nil {
				log.Printf("[feed] auto-install: load from disk %s failed: %v", extID, err)
				continue
			}
			if err := extRuntime.LoadExtensionWithDirs(ext.ID, diskPath, ext.SourceDir, ext.DataDir, ext.Manifest); err != nil {
				log.Printf("[feed] auto-install: runtime load %s failed: %v", extID, err)
				continue
			}
			installed++
			log.Printf("[feed] auto-install: loaded %s from disk", extID)
			continue
		}

		// Not on disk — download from registry
		destPath := filepath.Join(extDir, extID+".bitly-ext")
		log.Printf("[feed] auto-install: downloading %s", extID)
		if err := extStore.DownloadExtension(extID, destPath); err != nil {
			log.Printf("[feed] auto-install: download %s failed: %v", extID, err)
			continue
		}

		extracted, err := extManager.LoadExtension(destPath)
		if err != nil {
			log.Printf("[feed] auto-install: install %s failed: %v", extID, err)
			continue
		}

		jsPath := filepath.Join(extracted.SourceDir, "index.js")
		if err := extRuntime.LoadExtensionWithDirs(extracted.ID, jsPath, extracted.SourceDir, extracted.DataDir, extracted.Manifest); err != nil {
			log.Printf("[feed] auto-install: runtime load %s failed: %v", extID, err)
			continue
		}

		installed++
		log.Printf("[feed] auto-install: installed %s", extID)
	}

	log.Printf("[feed] auto-install: installed/loaded %d extensions this session", installed)
}

// ensureExtensionsDir auto-detects and sets the extensions directory if not already set.
func ensureExtensionsDir() {
	extDir := extManager.ExtensionsDir()
	if extDir != "" {
		return // already set
	}

	// Try common locations
	candidates := []string{
		filepath.Join(".", "extensions"),
		filepath.Join(".", "assets", "extensions"),
		filepath.Join("..", "extensions"),
		filepath.Join("..", "assets", "extensions"),
	}

	for _, candidate := range candidates {
		abs, err := filepath.Abs(candidate)
		if err != nil {
			continue
		}
		info, err := os.Stat(abs)
		if err == nil && info.IsDir() {
			log.Printf("[feed] auto-detected extensions dir: %s", abs)
			extManager.SetDirectories(abs, filepath.Join(abs, "..", "ext_data"))
			return
		}
	}

	log.Printf("[feed] no extensions directory found (checked: %v)", candidates)
}

type feedItem struct {
	ID           string `json:"id,omitempty"`
	Type         string `json:"type,omitempty"`
	Name         string `json:"name,omitempty"`
	Artists      string `json:"artists,omitempty"`
	CoverURL     string `json:"cover_url,omitempty"`
	Source       string `json:"source,omitempty"`
	AlbumName    string `json:"album_name,omitempty"`
	AlbumID      string `json:"album_id,omitempty"`
	DurationMS   int64  `json:"duration_ms,omitempty"`
	ReleaseDate  string `json:"release_date,omitempty"`
	TotalTracks  int    `json:"total_tracks,omitempty"`
	Owner        string `json:"owner,omitempty"`
	ISRC         string `json:"isrc,omitempty"`
}

func callExtensionFeeds() []feedSectionResponse {
	loaded := extRuntime.ListLoaded()
	if len(loaded) == 0 {
		return nil
	}

	var all []feedSectionResponse
	for _, extID := range loaded {
		if !extRuntime.HasMethod(extID, "getHomeFeed") {
			continue
		}
		result, err := extRuntime.CallMethod(extID, "getHomeFeed")
		if err != nil || result == nil || result.RawJSON == "" {
			log.Printf("[feed] extension %q getHomeFeed failed: %v", extID, err)
			continue
		}
		var envelope struct {
			Success  bool            `json:"success"`
			Sections json.RawMessage `json:"sections"`
		}
		if err := json.Unmarshal([]byte(result.RawJSON), &envelope); err != nil {
			continue
		}
		if !envelope.Success || len(envelope.Sections) == 0 {
			continue
		}
		var rawSections []struct {
			Title string          `json:"title"`
			Items json.RawMessage `json:"items"`
		}
		if err := json.Unmarshal(envelope.Sections, &rawSections); err != nil {
			continue
		}
		for _, rs := range rawSections {
			var items []feedItem
			if err := json.Unmarshal(rs.Items, &items); err != nil || len(items) == 0 {
				continue
			}
			all = append(all, feedSectionResponse{
				Source: extID,
				Title:  rs.Title,
				Items:  items,
			})
		}
	}
	return all
}

func loadExtensionsOnDemand() int {
	extDir := extManager.ExtensionsDir()
	if extDir == "" {
		return 0
	}
	entries, err := os.ReadDir(extDir)
	if err != nil {
		return 0
	}
	loaded := 0
	for _, entry := range entries {
		if !entry.IsDir() || strings.HasPrefix(entry.Name(), ".") {
			continue
		}
		extID := entry.Name()
		if extRuntime.IsLoaded(extID) {
			continue
		}
		extPath := filepath.Join(extDir, extID, "index.js")
		if _, err := os.Stat(extPath); err != nil {
			continue
		}
		ext, err := extManager.LoadExtensionFromDir(filepath.Join(extDir, extID))
		if err != nil || ext == nil {
			log.Printf("[feed] on-demand: LoadExtensionFromDir %q failed: %v", extID, err)
			continue
		}
		if err := extRuntime.LoadExtensionWithDirs(ext.ID, extPath, ext.SourceDir, ext.DataDir, ext.Manifest); err != nil {
			log.Printf("[feed] on-demand: LoadExtensionWithDirs %q failed: %v", extID, err)
			continue
		}
		loaded++
		log.Printf("[feed] loaded extension %q on demand", extID)
	}
	return loaded
}

func builtinHomeFeed() ([]feedSectionResponse, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 25*time.Second)
	defer cancel()

	var (
		sections []feedSectionResponse
		mu       sync.Mutex
		wg       sync.WaitGroup
	)

	// ─── DEEZER (via client SDK) ──────────────────────────────
	wg.Add(1)
	go func() {
		defer wg.Done()
		s := fetchDeezerFeed(ctx)
		if len(s) > 0 {
			mu.Lock()
			sections = append(sections, s...)
			mu.Unlock()
		}
	}()

	// ─── DEEZER PUBLIC CHART API (no auth needed) ─────────────
	wg.Add(1)
	go func() {
		defer wg.Done()
		s := fetchDeezerPublicChart()
		if len(s) > 0 {
			mu.Lock()
			sections = append(sections, s...)
			mu.Unlock()
		}
	}()

	// ─── QOBUZ ─────────────────────────────────────────────────
	wg.Add(1)
	go func() {
		defer wg.Done()
		s := fetchQobuzFeed(ctx)
		if len(s) > 0 {
			mu.Lock()
			sections = append(sections, s...)
			mu.Unlock()
		}
	}()

	// ─── TIDAL ─────────────────────────────────────────────────
	wg.Add(1)
	go func() {
		defer wg.Done()
		s := fetchTidalFeed(ctx)
		if len(s) > 0 {
			mu.Lock()
			sections = append(sections, s...)
			mu.Unlock()
		}
	}()

	// ─── APPLE MUSIC RSS ───────────────────────────────────────
	wg.Add(1)
	go func() {
		defer wg.Done()
		s := fetchAppleMusicFeed(ctx)
		if len(s) > 0 {
			mu.Lock()
			sections = append(sections, s...)
			mu.Unlock()
		}
	}()

	// ─── SOUNDCLOUD (scraped client_id + search) ─────────────
	wg.Add(1)
	go func() {
		defer wg.Done()
		s := fetchSoundCloudFeed(ctx)
		if len(s) > 0 {
			mu.Lock()
			sections = append(sections, s...)
			mu.Unlock()
		}
	}()

	wg.Wait()

	if len(sections) > 0 {
		log.Printf("[feed] builtin: got %d sections from %d providers", len(sections), countUniqueSources(sections))
		return sections, nil
	}

	// ─── ULTIMO FALLBACK ──────────────────────────────────────
	log.Printf("[feed] all primary providers failed, trying qobuz single fallback")
	qs := fetchQobuzFallback(ctx)
	if len(qs) > 0 {
		return qs, nil
	}

	return sections, nil
}

// ═══════════════════════════════════════════════════════════════════
// DEEZER (via SDK)
// ═══════════════════════════════════════════════════════════════════

func fetchDeezerFeed(ctx context.Context) []feedSectionResponse {
	dz := deezer.GetClient()

	searches := []struct {
		query    string
		trackL   int
		artistL  int
		filter   string
		title    string
		itemType string
	}{
		{"pop", 8, 0, "", t("Trending Songs","Canciones Tendencias"), "track"},
		{"2026", 5, 0, "album", t("New Albums","Nuevos Lanzamientos"), "album"},
		{"Queen", 0, 8, "artist", t("Popular Artists","Artistas Populares"), "artist"},
		{"hits", 0, 0, "playlist", t("Featured Playlists","Playlists Destacadas"), "playlist"},
	}

	var sections []feedSectionResponse
	for _, s := range searches {
		result, err := dz.SearchAll(ctx, s.query, s.trackL, s.artistL, s.filter)
		if err != nil {
			log.Printf("[feed] deezer search %q failed: %v", s.query, err)
			continue
		}
		items := extractDeezerItems(result, s.itemType)
		if len(items) > 0 {
			sections = append(sections, feedSectionResponse{
				Source: "deezer",
				Title:  s.title,
				Items:  items,
			})
		}
	}

	return sections
}

func extractDeezerItems(result *core.SearchAllResult, itemType string) []feedItem {
	var items []feedItem
	switch itemType {
	case "track":
		for _, t := range result.Tracks {
			items = append(items, feedItem{
				ID:         t.SpotifyID,
				Type:       "track",
				Name:       t.Name,
				Artists:    t.Artists,
				CoverURL:   t.Images,
				AlbumName:  t.AlbumName,
				DurationMS: int64(t.DurationMS),
				ISRC:       t.ISRC,
			})
		}
	case "album":
		for _, a := range result.Albums {
			items = append(items, feedItem{
				ID:          a.ID,
				Type:        "album",
				Name:        a.Name,
				Artists:     a.Artists,
				CoverURL:    a.Images,
				ReleaseDate: a.ReleaseDate,
				TotalTracks: a.TotalTracks,
			})
		}
	case "artist":
		for _, a := range result.Artists {
			items = append(items, feedItem{
				ID:       a.ID,
				Type:     "artist",
				Name:     a.Name,
				CoverURL: a.Images,
			})
		}
	case "playlist":
		for _, p := range result.Playlists {
			items = append(items, feedItem{
				ID:          p.ID,
				Type:        "playlist",
				Name:        p.Name,
				Artists:     p.Owner,
				CoverURL:    p.Images,
				Owner:       p.Owner,
				TotalTracks: p.TotalTracks,
			})
		}
	}
	return items
}

// ═══════════════════════════════════════════════════════════════════
// DEEZER PUBLIC API (no auth — same as Android)
// ═══════════════════════════════════════════════════════════════════

func fetchDeezerPublicChart() []feedSectionResponse {
	client := &http.Client{Timeout: 10 * time.Second}
	defer client.CloseIdleConnections()

	resp, err := client.Get("https://api.deezer.com/chart/0")
	if err != nil {
		log.Printf("[feed] deezer chart api failed: %v", err)
		return nil
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil
	}

	var chart struct {
		Tracks struct {
			Data []struct {
				ID     int    `json:"id"`
				Title  string `json:"title"`
				Artist struct {
					Name string `json:"name"`
				} `json:"artist"`
				Album struct {
					Title       string `json:"title"`
					CoverMedium string `json:"cover_medium"`
				} `json:"album"`
			} `json:"data"`
		} `json:"tracks"`
		Albums struct {
			Data []struct {
				ID          int    `json:"id"`
				Title       string `json:"title"`
				Artist      struct {
					Name string `json:"name"`
				} `json:"artist"`
				CoverMedium string `json:"cover_medium"`
			} `json:"data"`
		} `json:"albums"`
		Artists struct {
			Data []struct {
				ID            int    `json:"id"`
				Name          string `json:"name"`
				PictureMedium string `json:"picture_medium"`
			} `json:"data"`
		} `json:"artists"`
		Playlists struct {
			Data []struct {
				ID            int    `json:"id"`
				Title         string `json:"title"`
				PictureMedium string `json:"picture_medium"`
				User          struct {
					Name string `json:"name"`
				} `json:"user"`
			} `json:"data"`
		} `json:"playlists"`
	}

	if err := json.Unmarshal(body, &chart); err != nil {
		log.Printf("[feed] deezer chart parse failed: %v", err)
		return nil
	}

	var sections []feedSectionResponse

	// Tracks
	if len(chart.Tracks.Data) > 0 {
		items := make([]feedItem, 0, len(chart.Tracks.Data))
		for _, t := range chart.Tracks.Data {
			items = append(items, feedItem{
				ID:        fmt.Sprintf("%d", t.ID),
				Type:      "track",
				Name:      t.Title,
				Artists:   t.Artist.Name,
				CoverURL:  t.Album.CoverMedium,
				AlbumName: t.Album.Title,
			})
		}
		sections = append(sections, feedSectionResponse{
			Source: "deezer",
			Title:  t("Trending Songs","Canciones Tendencias"),
			Items:  items,
		})
	}

	// Albums
	if len(chart.Albums.Data) > 0 {
		items := make([]feedItem, 0, len(chart.Albums.Data))
		for _, a := range chart.Albums.Data {
			items = append(items, feedItem{
				ID:       fmt.Sprintf("%d", a.ID),
				Type:     "album",
				Name:     a.Title,
				Artists:  a.Artist.Name,
				CoverURL: a.CoverMedium,
			})
		}
		sections = append(sections, feedSectionResponse{
			Source: "deezer",
			Title:  t("Popular Albums","Álbumes Populares"),
			Items:  items,
		})
	}

	// Artists
	if len(chart.Artists.Data) > 0 {
		items := make([]feedItem, 0, len(chart.Artists.Data))
		for _, a := range chart.Artists.Data {
			items = append(items, feedItem{
				ID:       fmt.Sprintf("%d", a.ID),
				Type:     "artist",
				Name:     a.Name,
				CoverURL: a.PictureMedium,
			})
		}
		sections = append(sections, feedSectionResponse{
			Source: "deezer",
			Title:  t("Top Artists","Artistas Top"),
			Items:  items,
		})
	}

	// Playlists
	if len(chart.Playlists.Data) > 0 {
		items := make([]feedItem, 0, len(chart.Playlists.Data))
		for _, p := range chart.Playlists.Data {
			items = append(items, feedItem{
				ID:       fmt.Sprintf("%d", p.ID),
				Type:     "playlist",
				Name:     p.Title,
				Artists:  p.User.Name,
				CoverURL: p.PictureMedium,
				Owner:    p.User.Name,
			})
		}
		sections = append(sections, feedSectionResponse{
			Source: "deezer",
			Title:  t("Featured Playlists","Playlists Destacadas"),
			Items:  items,
		})
	}

	return sections
}

// ═══════════════════════════════════════════════════════════════════
// QOBUZ
// ═══════════════════════════════════════════════════════════════════

func fetchQobuzFeed(ctx context.Context) []feedSectionResponse {
	qz := qobuz.GetClient()
	var sections []feedSectionResponse

	tracks, err := qz.SearchTracks("popular", 8)
	if err == nil && len(tracks) > 0 {
		items := make([]feedItem, 0, len(tracks))
		for _, t := range tracks {
			items = append(items, feedItem{
				ID:         t.ID,
				Type:       "track",
				Name:       t.Name,
				Artists:    t.Artists,
				CoverURL:   "",
				AlbumName:  t.AlbumName,
				DurationMS: int64(t.DurationMS),
				ISRC:       t.ISRC,
			})
		}
		sections = append(sections, feedSectionResponse{
			Source: "qobuz",
			Title:  t("Trending on Qobuz","Tendencias en Qobuz"),
			Items:  items,
		})
	}

	albums, err := qz.SearchTracks("new", 8)
	if err == nil && len(albums) > 0 {
		items := make([]feedItem, 0, len(albums))
		for _, t := range albums {
			items = append(items, feedItem{
				ID:         t.ID,
				Type:       "track",
				Name:       t.Name,
				Artists:    t.Artists,
				CoverURL:   "",
				AlbumName:  t.AlbumName,
				DurationMS: int64(t.DurationMS),
				ISRC:       t.ISRC,
			})
		}
		sections = append(sections, feedSectionResponse{
			Source: "qobuz",
			Title:  t("New on Qobuz","Novedades en Qobuz"),
			Items:  items,
		})
	}

	return sections
}

func fetchQobuzFallback(ctx context.Context) []feedSectionResponse {
	qz := qobuz.GetClient()
	tracks, err := qz.SearchTracks("popular", 10)
	if err != nil || len(tracks) == 0 {
		return nil
	}
	items := make([]feedItem, 0, len(tracks))
	for _, t := range tracks {
		items = append(items, feedItem{
			ID:         t.ID,
			Type:       "track",
			Name:       t.Name,
			Artists:    t.Artists,
			CoverURL:   "",
			AlbumName:  t.AlbumName,
			DurationMS: int64(t.DurationMS),
			ISRC:       t.ISRC,
		})
	}
	return []feedSectionResponse{{
		Source: "qobuz",
		Title:  t("Trending on Qobuz","Tendencias en Qobuz"),
		Items:  items,
	}}
}

// ═══════════════════════════════════════════════════════════════════
// TIDAL
// ═══════════════════════════════════════════════════════════════════

func fetchTidalFeed(ctx context.Context) []feedSectionResponse {
	td := tidal.GetClient()

	genres := []string{"pop", "rock", "electronic", "hip hop", "rnb", "latin", "jazz", "classical"}
	var allTracks []feedItem
	seen := make(map[string]bool)

	for _, genre := range genres {
		select {
		case <-ctx.Done():
			return nil
		default:
		}

		track, err := td.SearchText(genre)
		if err != nil || track == nil {
			continue
		}
		if track.ID == "" || seen[track.ID] {
			continue
		}
		seen[track.ID] = true
		allTracks = append(allTracks, feedItem{
			ID:       track.ID,
			Type:     "track",
			Name:     track.Name,
			Artists:  track.Artists,
			CoverURL: "",
		})
		if len(allTracks) >= 8 {
			break
		}
	}

	if len(allTracks) == 0 {
		return nil
	}

	return []feedSectionResponse{{
		Source: "tidal",
		Title:  t("Trending on Tidal","Tendencias en Tidal"),
		Items:  allTracks,
	}}
}

// ═══════════════════════════════════════════════════════════════════
// APPLE MUSIC RSS (public chart feed, no auth)
// ═══════════════════════════════════════════════════════════════════

type appleMusicFeedResponse struct {
	Feed struct {
		Results []struct {
			ID          string `json:"id"`
			Name        string `json:"name"`
			ArtistName  string `json:"artistName"`
			ArtworkURL  string `json:"artworkUrl100"`
		} `json:"results"`
	} `json:"feed"`
}

func fetchAppleMusicFeed(ctx context.Context) []feedSectionResponse {
	type feedType struct {
		path     string
		itemType string
		titleEn  string
		titleEs  string
	}

	types := []feedType{
		{"songs", "track", "Top Songs", "Canciones Top"},
		{"albums", "album", "Top Albums", "Álbumes Top"},
		{"music-videos", "track", "Top Music Videos", "Videos Musicales Top"},
	}

	client := &http.Client{Timeout: 15 * time.Second}
	defer client.CloseIdleConnections()

	var sections []feedSectionResponse
	for _, ft := range types {
		url := fmt.Sprintf("https://rss.applemarketingtools.com/api/v2/us/music/most-played/10/%s.json", ft.path)
		resp, err := client.Get(url)
		if err != nil {
			log.Printf("[feed] apple music %s failed: %v", ft.path, err)
			continue
		}
		body, err := io.ReadAll(resp.Body)
		resp.Body.Close()
		if err != nil {
			continue
		}
		var data appleMusicFeedResponse
		if err := json.Unmarshal(body, &data); err != nil || len(data.Feed.Results) == 0 {
			continue
		}
		items := make([]feedItem, 0, len(data.Feed.Results))
		for _, r := range data.Feed.Results {
			items = append(items, feedItem{
				ID: r.ID, Type: ft.itemType, Name: r.Name,
				Artists: r.ArtistName, CoverURL: r.ArtworkURL,
			})
		}
		sections = append(sections, feedSectionResponse{
			Source: "apple-music", Title: t(ft.titleEn, ft.titleEs), Items: items,
		})
	}

	return sections
}

// ═══════════════════════════════════════════════════════════════════
// SOUNDCLOUD (scraped client_id + search API)
// ═══════════════════════════════════════════════════════════════════

type soundCloudItem struct {
	Kind        string `json:"kind"`
	ID          int    `json:"id"`
	Title       string `json:"title"`
	PermalinkURL string `json:"permalink_url"`
	User        struct {
		Username string `json:"username"`
	} `json:"user"`
	ArtworkURL string `json:"artwork_url"`
}

type soundCloudSearchResponse struct {
	Collection []soundCloudItem `json:"collection"`
}

type genreDef struct {
	key   string
	label string
	labelEs string
}

func fetchSoundCloudFeed(ctx context.Context) []feedSectionResponse {
	clientID := getSoundCloudClientID(ctx)
	if clientID == "" {
		log.Printf("[feed] soundcloud: no client_id found")
		return nil
	}

	genres := []genreDef{
		{"pop", "Pop", "Pop"}, {"electronic", "Electronic", "Electrónica"},
		{"hip hop", "Hip Hop", "Hip Hop"}, {"rnb", "R&B", "R&B"},
		{"rock", "Rock", "Rock"}, {"latin", "Latin", "Latina"},
		{"jazz", "Jazz", "Jazz"},
	}

	var sections []feedSectionResponse
	seen := make(map[string]bool)

	for _, g := range genres {
		select {
		case <-ctx.Done():
			return sections
		default:
		}

		searchItems := soundCloudSearch(ctx, clientID, g.key, 6)
		var uniq []feedItem
		for _, it := range searchItems {
			if seen[it.ID] {
				continue
			}
			seen[it.ID] = true
			uniq = append(uniq, it)
		}
		if len(uniq) > 0 {
			label := g.label
			if feedLocale == "es" {
				label = g.labelEs
			}
			sections = append(sections, feedSectionResponse{
				Source: "soundcloud", Title: label, Items: uniq,
			})
		}
	}

	return sections
}

func getSoundCloudClientID(ctx context.Context) string {
	client := &http.Client{Timeout: 8 * time.Second}
	defer client.CloseIdleConnections()

	req, err := http.NewRequestWithContext(ctx, "GET", "https://soundcloud.com", nil)
	if err != nil {
		return ""
	}
	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
	resp, err := client.Do(req)
	if err != nil {
		return ""
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return ""
	}
	html := string(body)

	// Extract client_id from __sc_hydration's apiClient.id
	// Pattern: "apiClient","data":{"id":"XXXX"}
	idx := strings.Index(html, `"apiClient"`)
	if idx < 0 {
		return ""
	}
	// Find "id":" after apiClient
	dataStart := strings.Index(html[idx:], `"id":"`)
	if dataStart < 0 {
		return ""
	}
	dataStart += idx + 6 // skip past "id":" (6 chars)
	end := strings.Index(html[dataStart:], `"`)
	if end < 0 {
		return ""
	}
	return html[dataStart : dataStart+end]
}

func soundCloudSearch(ctx context.Context, clientID, query string, limit int) []feedItem {
	client := &http.Client{Timeout: 8 * time.Second}
	defer client.CloseIdleConnections()

	url := fmt.Sprintf("https://api-v2.soundcloud.com/search?q=%s&limit=%d&client_id=%s",
		url.QueryEscape(query), limit, url.QueryEscape(clientID))
	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		return nil
	}
	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
	resp, err := client.Do(req)
	if err != nil || resp.StatusCode != 200 {
		return nil
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil
	}
	var data soundCloudSearchResponse
	if err := json.Unmarshal(body, &data); err != nil {
		return nil
	}
	var items []feedItem
	for _, it := range data.Collection {
		itemType := it.Kind
		if itemType == "track" {
			itemType = "track"
		} else if itemType == "playlist" {
			itemType = "playlist"
		} else {
			continue // skip users and other types
		}
		coverURL := it.ArtworkURL
		if coverURL != "" {
			coverURL = strings.ReplaceAll(coverURL, "-large.jpg", "-t500x500.jpg")
		}
		artistName := it.User.Username
		if artistName == "" {
			artistName = it.Kind
		}
		items = append(items, feedItem{
			ID:       fmt.Sprintf("%d", it.ID),
			Type:     itemType,
			Name:     it.Title,
			Artists:  artistName,
			CoverURL: coverURL,
		})
	}
	return items
}

// ═══════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════

func countUniqueSources(sections []feedSectionResponse) int {
	seen := make(map[string]bool)
	for _, s := range sections {
		seen[s.Source] = true
	}
	return len(seen)
}
