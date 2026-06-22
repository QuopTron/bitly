package core

import (
	"context"
	"errors"
	"testing"
)

// ---------------------------------------------------------------------------
// Mock implementations
// ---------------------------------------------------------------------------

type mockSearchProvider struct {
	id   string
	name string
}

func (m *mockSearchProvider) ID() string                       { return m.id }
func (m *mockSearchProvider) Name() string                     { return m.name }
func (m *mockSearchProvider) Search(_ string, _ int) ([]SearchResultItem, error) {
	return nil, nil
}

type mockDownloadProvider struct {
	id       string
	name     string
	download func(trackID, quality string) ([]byte, error)
}

func (m *mockDownloadProvider) ID() string   { return m.id }
func (m *mockDownloadProvider) Name() string { return m.name }
func (m *mockDownloadProvider) Download(trackID, quality string) ([]byte, error) {
	return m.download(trackID, quality)
}

type mockMetadataProvider struct {
	id   string
	name string
}

func (m *mockMetadataProvider) ID() string                                    { return m.id }
func (m *mockMetadataProvider) Name() string                                  { return m.name }
func (m *mockMetadataProvider) GetTrackMetadata(_ string) (interface{}, error) { return nil, nil }
func (m *mockMetadataProvider) GetAlbumMetadata(_ string) (interface{}, error) { return nil, nil }

type mockLyricsProvider struct {
	id   string
	name string
}

func (m *mockLyricsProvider) ID() string                                                  { return m.id }
func (m *mockLyricsProvider) Name() string                                                { return m.name }
func (m *mockLyricsProvider) FetchLyrics(_, _ string, _ float64) (interface{}, error)     { return nil, nil }

type mockAvailChecker struct {
	checkFn func(spotifyID, isrc string) (interface{}, error)
}

func (m *mockAvailChecker) CheckTrackAvailability(spotifyID, isrc string) (interface{}, error) {
	return m.checkFn(spotifyID, isrc)
}

type mockISRCResolver struct {
	resolveFn func(isrc string) (interface{}, error)
}

func (m *mockISRCResolver) ResolveByISRC(isrc string) (interface{}, error) {
	return m.resolveFn(isrc)
}

// ---------------------------------------------------------------------------
// CacheEntry
// ---------------------------------------------------------------------------

func TestCacheEntry_IsExpired(t *testing.T) {
	t.Run("nil receiver", func(t *testing.T) {
		var e *CacheEntry
		if e.IsExpired() {
			t.Error("expected false for nil receiver")
		}
	})

	t.Run("zero ExpiresAt", func(t *testing.T) {
		e := &CacheEntry{Data: "hello", ExpiresAt: 0}
		if e.IsExpired() {
			t.Error("expected false when ExpiresAt == 0")
		}
	})

	t.Run("non-zero ExpiresAt", func(t *testing.T) {
		e := &CacheEntry{Data: 42, ExpiresAt: 1000}
		if e.IsExpired() {
			t.Error("expected false (stub always returns false)")
		}
	})
}

// ---------------------------------------------------------------------------
// ProviderRegistry
// ---------------------------------------------------------------------------

func TestProviderRegistry_New(t *testing.T) {
	r := NewProviderRegistry()
	if r == nil {
		t.Fatal("NewProviderRegistry returned nil")
	}
	if len(r.searchProviders) != 0 {
		t.Error("expected empty searchProviders map")
	}
}

func TestProviderRegistry_SearchProvider(t *testing.T) {
	r := NewProviderRegistry()

	got := r.GetSearchProvider("nonexistent")
	if got != nil {
		t.Error("expected nil for unregistered provider")
	}

	p1 := &mockSearchProvider{id: "s1", name: "Search One"}
	p2 := &mockSearchProvider{id: "s2", name: "Search Two"}
	r.RegisterSearchProvider("s1", p1)
	r.RegisterSearchProvider("s2", p2)
	r.RegisterSearchProvider("s1", p2) // overwrite

	got = r.GetSearchProvider("s1")
	if got == nil {
		t.Fatal("expected non-nil after register")
	}
	if got.ID() != "s2" || got.Name() != "Search Two" {
		t.Errorf("expected s2/Search Two, got %s/%s", got.ID(), got.Name())
	}

	all := r.GetAllSearchProviders()
	if len(all) != 2 {
		t.Fatalf("expected 2 search providers, got %d", len(all))
	}
}

func TestProviderRegistry_DownloadProvider(t *testing.T) {
	r := NewProviderRegistry()

	got := r.GetDownloadProvider("nonexistent")
	if got != nil {
		t.Error("expected nil for unregistered provider")
	}

	d1 := &mockDownloadProvider{id: "d1", name: "Download One", download: func(_, _ string) ([]byte, error) {
		return []byte("data"), nil
	}}
	r.RegisterDownloadProvider("d1", d1)

	got = r.GetDownloadProvider("d1")
	if got == nil {
		t.Fatal("expected non-nil after register")
	}
	if got.ID() != "d1" || got.Name() != "Download One" {
		t.Errorf("expected d1/Download One, got %s/%s", got.ID(), got.Name())
	}

	data, err := got.Download("tid", "high")
	if err != nil {
		t.Errorf("unexpected error: %v", err)
	}
	if string(data) != "data" {
		t.Errorf("expected 'data', got '%s'", string(data))
	}

	all := r.GetAllDownloadProviders()
	if len(all) != 1 {
		t.Fatalf("expected 1 download provider, got %d", len(all))
	}
}

func TestProviderRegistry_MetadataProvider(t *testing.T) {
	r := NewProviderRegistry()

	m := &mockMetadataProvider{id: "m1", name: "Meta One"}
	r.RegisterMetadataProvider("m1", m)
	// no getter exported, but we can verify no panic and internal map works
	if len(r.metadataProviders) != 1 {
		t.Errorf("expected 1 metadata provider, got %d", len(r.metadataProviders))
	}
}

func TestProviderRegistry_LyricsProvider(t *testing.T) {
	r := NewProviderRegistry()

	l := &mockLyricsProvider{id: "l1", name: "Lyrics One"}
	r.RegisterLyricsProvider("l1", l)
	if len(r.lyricsProviders) != 1 {
		t.Errorf("expected 1 lyrics provider, got %d", len(r.lyricsProviders))
	}
}

func TestProviderRegistry_GetAllEmpty(t *testing.T) {
	r := NewProviderRegistry()

	if all := r.GetAllSearchProviders(); len(all) != 0 {
		t.Error("expected empty search providers")
	}
	if all := r.GetAllDownloadProviders(); len(all) != 0 {
		t.Error("expected empty download providers")
	}
}

func TestProviderRegistry_ConcurrencySafe(t *testing.T) {
	r := NewProviderRegistry()
	done := make(chan bool, 4)

	write := func() {
		r.RegisterSearchProvider("x", &mockSearchProvider{id: "x", name: "X"})
		done <- true
	}
	read := func() {
		_ = r.GetSearchProvider("x")
		done <- true
	}

	go write()
	go read()
	go write()
	go read()

	for range 4 {
		<-done
	}
}

// ---------------------------------------------------------------------------
// SourceSelector — SelectBestSource
// ---------------------------------------------------------------------------

func TestSourceSelector_SelectBestSource_WithAvailChecker(t *testing.T) {
	reg := NewProviderRegistry()
	sel := NewSourceSelector(reg, []string{"deezer", "tidal", "qobuz"})

	sel.SetAvailabilityChecker(&mockAvailChecker{
		checkFn: func(_, _ string) (interface{}, error) {
			return map[string]interface{}{
				"deezer":    true,
				"tidal":     false,
				"qobuz":     false,
				"deezer_id": "dz123",
			}, nil
		},
	})

	src, err := sel.SelectBestSource("track1", "isrc123", "high")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if src.Provider != "deezer" {
		t.Errorf("expected deezer, got %s", src.Provider)
	}
	if src.ProviderID != "dz123" {
		t.Errorf("expected providerID dz123, got %s", src.ProviderID)
	}
	if src.Quality != "high" {
		t.Errorf("expected quality high, got %s", src.Quality)
	}
	if src.Confidence != 0.85 {
		t.Errorf("expected confidence 0.85, got %f", src.Confidence)
	}
}

func TestSourceSelector_SelectBestSource_AvailCheckerSelectsByPriority(t *testing.T) {
	reg := NewProviderRegistry()
	sel := NewSourceSelector(reg, []string{"tidal", "qobuz", "deezer"})

	sel.SetAvailabilityChecker(&mockAvailChecker{
		checkFn: func(_, _ string) (interface{}, error) {
			return map[string]interface{}{
				"deezer":  true,
				"tidal":   true,
				"qobuz":   false,
				"tidal_id": "td999",
			}, nil
		},
	})

	src, err := sel.SelectBestSource("t1", "", "")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if src.Provider != "tidal" {
		t.Errorf("expected tidal (highest priority), got %s", src.Provider)
	}
}

func TestSourceSelector_SelectBestSource_AvailCheckerNoneAvailable(t *testing.T) {
	reg := NewProviderRegistry()
	sel := NewSourceSelector(reg, []string{"deezer", "tidal"})

	sel.SetAvailabilityChecker(&mockAvailChecker{
		checkFn: func(_, _ string) (interface{}, error) {
			return map[string]interface{}{
				"deezer": false,
				"tidal":  false,
			}, nil
		},
	})

	// falls through to no-avail path → first priority
	src, err := sel.SelectBestSource("t1", "", "high")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if src.Provider != "deezer" {
		t.Errorf("expected deezer (first in priority fallback), got %s", src.Provider)
	}
}

func TestSourceSelector_SelectBestSource_AvailCheckerReturnsNil(t *testing.T) {
	reg := NewProviderRegistry()
	sel := NewSourceSelector(reg, []string{"qobuz"})

	sel.SetAvailabilityChecker(&mockAvailChecker{
		checkFn: func(_, _ string) (interface{}, error) {
			return nil, nil
		},
	})

	src, err := sel.SelectBestSource("t1", "", "flac")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if src.Provider != "qobuz" {
		t.Errorf("expected qobuz, got %s", src.Provider)
	}
	if src.Quality != "flac" {
		t.Errorf("expected quality flac, got %s", src.Quality)
	}
}

func TestSourceSelector_SelectBestSource_AvailCheckerReturnsError(t *testing.T) {
	reg := NewProviderRegistry()
	sel := NewSourceSelector(reg, []string{"deezer"})

	sel.SetAvailabilityChecker(&mockAvailChecker{
		checkFn: func(_, _ string) (interface{}, error) {
			return nil, errors.New("check failed")
		},
	})

	src, err := sel.SelectBestSource("t1", "", "high")
	if err != nil {
		t.Fatalf("unexpected error on fallback: %v", err)
	}
	if src.Provider != "deezer" {
		t.Errorf("expected deezer fallback, got %s", src.Provider)
	}
}

func TestSourceSelector_SelectBestSource_WithISRCResolver(t *testing.T) {
	reg := NewProviderRegistry()
	sel := NewSourceSelector(reg, []string{"tidal", "deezer"})

	sel.SetISRCResolver(&mockISRCResolver{
		resolveFn: func(_ string) (interface{}, error) {
			return map[string]interface{}{
				"deezer_url": "https://deezer.com/track/1",
			}, nil
		},
	})

	src, err := sel.SelectBestSource("track1", "isrc_val", "")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if src.Provider != "deezer" {
		t.Errorf("expected deezer from ISRC resolve, got %s", src.Provider)
	}
	if src.ProviderID != "track1" {
		t.Errorf("expected providerID track1, got %s", src.ProviderID)
	}
	if src.Confidence != 0.7 {
		t.Errorf("expected confidence 0.7, got %f", src.Confidence)
	}
}

func TestSourceSelector_SelectBestSource_ISRCTidalURL(t *testing.T) {
	reg := NewProviderRegistry()
	sel := NewSourceSelector(reg, []string{"deezer", "tidal", "qobuz"})

	sel.SetISRCResolver(&mockISRCResolver{
		resolveFn: func(_ string) (interface{}, error) {
			return map[string]interface{}{
				"tidal_url": "https://tidal.com/track/99",
			}, nil
		},
	})

	src, err := sel.SelectBestSource("tid", "isrc_tidal", "hifi")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if src.Provider != "tidal" {
		t.Errorf("expected tidal from ISRC, got %s", src.Provider)
	}
	if src.Quality != "hifi" {
		t.Errorf("expected quality hifi, got %s", src.Quality)
	}
}

func TestSourceSelector_SelectBestSource_ISRCQobuzURL(t *testing.T) {
	reg := NewProviderRegistry()
	sel := NewSourceSelector(reg, []string{"deezer", "tidal", "qobuz"})

	sel.SetISRCResolver(&mockISRCResolver{
		resolveFn: func(_ string) (interface{}, error) {
			return map[string]interface{}{
				"qobuz_url": "https://qobuz.com/track/77",
			}, nil
		},
	})

	src, err := sel.SelectBestSource("qid", "isrc_q", "")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if src.Provider != "qobuz" {
		t.Errorf("expected qobuz from ISRC, got %s", src.Provider)
	}
}

func TestSourceSelector_SelectBestSource_ISRCFallsThroughWhenNoURL(t *testing.T) {
	reg := NewProviderRegistry()
	sel := NewSourceSelector(reg, []string{"tidal"})

	sel.SetISRCResolver(&mockISRCResolver{
		resolveFn: func(_ string) (interface{}, error) {
			return map[string]interface{}{}, nil
		},
	})

	src, err := sel.SelectBestSource("tid", "isrc_none", "medium")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if src.Provider != "tidal" {
		t.Errorf("expected tidal (priority fallback), got %s", src.Provider)
	}
	if src.Quality != "medium" {
		t.Errorf("expected quality medium, got %s", src.Quality)
	}
}

func TestSourceSelector_SelectBestSource_ISRCNonMap(t *testing.T) {
	reg := NewProviderRegistry()
	sel := NewSourceSelector(reg, []string{"deezer"})

	sel.SetISRCResolver(&mockISRCResolver{
		resolveFn: func(_ string) (interface{}, error) {
			return "not a map", nil
		},
	})

	src, err := sel.SelectBestSource("tid", "isrc_bad", "")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if src.Provider != "deezer" {
		t.Errorf("expected deezer fallback, got %s", src.Provider)
	}
}

func TestSourceSelector_SelectBestSource_ISRCError(t *testing.T) {
	reg := NewProviderRegistry()
	sel := NewSourceSelector(reg, []string{"deezer"})

	sel.SetISRCResolver(&mockISRCResolver{
		resolveFn: func(_ string) (interface{}, error) {
			return nil, errors.New("resolve error")
		},
	})

	src, err := sel.SelectBestSource("tid", "isrc_err", "")
	if err != nil {
		t.Fatalf("unexpected error on fallback: %v", err)
	}
	if src.Provider != "deezer" {
		t.Errorf("expected deezer fallback, got %s", src.Provider)
	}
}

func TestSourceSelector_SelectBestSource_AvailTakesPriorityOverISRC(t *testing.T) {
	reg := NewProviderRegistry()
	sel := NewSourceSelector(reg, []string{"deezer", "tidal"})

	sel.SetAvailabilityChecker(&mockAvailChecker{
		checkFn: func(_, _ string) (interface{}, error) {
			return map[string]interface{}{
				"deezer":   true,
				"deezer_id": "dz_avail",
			}, nil
		},
	})
	sel.SetISRCResolver(&mockISRCResolver{
		resolveFn: func(_ string) (interface{}, error) {
			return map[string]interface{}{
				"tidal_url": "https://tidal.com/track/1",
			}, nil
		},
	})

	src, err := sel.SelectBestSource("tid", "isrc", "")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if src.Provider != "deezer" {
		t.Errorf("expected deezer (avail checker runs first), got %s", src.Provider)
	}
	if src.ProviderID != "dz_avail" {
		t.Errorf("expected providerID dz_avail, got %s", src.ProviderID)
	}
}

func TestSourceSelector_SelectBestSource_EmptyPriorityDefaultsToDeezer(t *testing.T) {
	reg := NewProviderRegistry()
	sel := NewSourceSelector(reg, []string{})

	src, err := sel.SelectBestSource("tid", "", "low")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if src.Provider != "deezer" {
		t.Errorf("expected deezer default, got %s", src.Provider)
	}
	if src.ProviderID != "tid" {
		t.Errorf("expected providerID tid, got %s", src.ProviderID)
	}
	if src.Quality != "low" {
		t.Errorf("expected quality low, got %s", src.Quality)
	}
	if src.Confidence != 0.3 {
		t.Errorf("expected confidence 0.3, got %f", src.Confidence)
	}
}

// ---------------------------------------------------------------------------
// SourceSelector — bestFromAny (unexported helper)
// ---------------------------------------------------------------------------

func TestBestFromAny(t *testing.T) {
	t.Run("non-map returns nil", func(t *testing.T) {
		s := &SourceSelector{priority: []string{"deezer"}}
		if got := s.bestFromAny("string"); got != nil {
			t.Error("expected nil for non-map input")
		}
	})

	t.Run("picks available by priority order", func(t *testing.T) {
		s := &SourceSelector{priority: []string{"tidal", "deezer", "qobuz"}}
		avail := map[string]interface{}{
			"deezer": true, "tidal": true, "qobuz": false,
			"deezer_id": "dz1", "tidal_id": "td1",
		}
		got := s.bestFromAny(avail)
		if got == nil {
			t.Fatal("expected non-nil result")
		}
		if got.Provider != "tidal" {
			t.Errorf("expected tidal (first in priority among available), got %s", got.Provider)
		}
		if got.ProviderID != "td1" {
			t.Errorf("expected providerID td1, got %s", got.ProviderID)
		}
		if got.Confidence != 0.85 {
			t.Errorf("expected confidence 0.85, got %f", got.Confidence)
		}
	})

	t.Run("none available returns nil", func(t *testing.T) {
		s := &SourceSelector{priority: []string{"deezer", "tidal"}}
		avail := map[string]interface{}{
			"deezer": false, "tidal": false,
		}
		if got := s.bestFromAny(avail); got != nil {
			t.Error("expected nil when none available")
		}
	})
}

// ---------------------------------------------------------------------------
// SourceSelector — bestFromResolveResult (unexported helper)
// ---------------------------------------------------------------------------

func TestBestFromResolveResult(t *testing.T) {
	t.Run("non-map returns nil", func(t *testing.T) {
		s := &SourceSelector{}
		if got := s.bestFromResolveResult("tid", 42); got != nil {
			t.Error("expected nil for non-map")
		}
	})

	t.Run("deezer_url selected", func(t *testing.T) {
		s := &SourceSelector{}
		got := s.bestFromResolveResult("tid", map[string]interface{}{
			"deezer_url": "https://deezer.com/track/1",
		})
		if got == nil || got.Provider != "deezer" {
			t.Errorf("expected deezer, got %v", got)
		}
	})

	t.Run("tidal_url selected", func(t *testing.T) {
		s := &SourceSelector{}
		got := s.bestFromResolveResult("tid", map[string]interface{}{
			"tidal_url": "https://tidal.com/track/1",
		})
		if got == nil || got.Provider != "tidal" {
			t.Errorf("expected tidal, got %v", got)
		}
	})

	t.Run("qobuz_url selected", func(t *testing.T) {
		s := &SourceSelector{}
		got := s.bestFromResolveResult("tid", map[string]interface{}{
			"qobuz_url": "https://qobuz.com/track/1",
		})
		if got == nil || got.Provider != "qobuz" {
			t.Errorf("expected qobuz, got %v", got)
		}
	})

	t.Run("no matching URL returns nil", func(t *testing.T) {
		s := &SourceSelector{}
		got := s.bestFromResolveResult("tid", map[string]interface{}{
			"other": "value",
		})
		if got != nil {
			t.Error("expected nil when no URL found")
		}
	})
}

// ---------------------------------------------------------------------------
// bestQualityFor (unexported helper)
// ---------------------------------------------------------------------------

func TestBestQualityFor(t *testing.T) {
	tests := []struct {
		name     string
		requested string
		provider  string
		want     string
	}{
		{"valid requested quality flac", "flac", "deezer", "flac"},
		{"valid requested quality hifi", "hifi", "tidal", "hifi"},
		{"valid requested quality high", "high", "qobuz", "high"},
		{"valid requested quality medium", "medium", "deezer", "medium"},
		{"valid requested quality low", "low", "qobuz", "low"},
		{"invalid requested falls back to provider default", "ultra", "deezer", "flac"},
		{"empty requested deezer", "", "deezer", "flac"},
		{"empty requested tidal", "", "tidal", "hifi"},
		{"empty requested qobuz", "", "qobuz", "flac"},
		{"unknown provider default", "", "spotify", "high"},
		{"invalid requested unknown provider", "bogus", "unknown", "high"},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := bestQualityFor(tc.requested, tc.provider)
			if got != tc.want {
				t.Errorf("bestQualityFor(%q, %q) = %q, want %q", tc.requested, tc.provider, got, tc.want)
			}
		})
	}
}

// ---------------------------------------------------------------------------
// providerQualityRank
// ---------------------------------------------------------------------------

func TestProviderQualityRank(t *testing.T) {
	expected := map[string]int{
		"flac": 4, "hifi": 3, "high": 2, "medium": 1, "low": 0,
	}
	if len(providerQualityRank) != len(expected) {
		t.Errorf("providerQualityRank has %d entries, want %d", len(providerQualityRank), len(expected))
	}
	for k, v := range expected {
		if providerQualityRank[k] != v {
			t.Errorf("providerQualityRank[%q] = %d, want %d", k, providerQualityRank[k], v)
		}
	}
}

// ---------------------------------------------------------------------------
// Types construction
// ---------------------------------------------------------------------------

func TestSearchResultItemConstruction(t *testing.T) {
	item := SearchResultItem{
		ID: "id1", Title: "Song Title", Artist: "Artist Name",
		Album: "Album", Duration: 200000, ISRC: "isrc123",
		Source: "deezer", CoverURL: "https://example.com/cover.jpg",
	}
	if item.ID != "id1" || item.Title != "Song Title" || item.Artist != "Artist Name" {
		t.Error("SearchResultItem fields mismatch")
	}
	if item.Album != "Album" || item.Duration != 200000 {
		t.Error("SearchResultItem fields mismatch")
	}
	if item.ISRC != "isrc123" || item.Source != "deezer" || item.CoverURL != "https://example.com/cover.jpg" {
		t.Error("SearchResultItem fields mismatch")
	}
}

func TestTrackMetadataConstruction(t *testing.T) {
	tm := TrackMetadata{
		SpotifyID: "sp1", Name: "Track", Artists: "Artist",
		AlbumName: "Album", AlbumArtist: "Album Artist", AlbumID: "alb1",
		ArtistID: "art1", DurationMS: 180000, Images: "img.jpg",
		ReleaseDate: "2024-01-01", TrackNumber: 3, DiscNumber: 1,
		ExternalURL: "https://open.spotify.com/track/1", ISRC: "isrc999",
	}
	if tm.SpotifyID != "sp1" || tm.Name != "Track" || tm.Artists != "Artist" {
		t.Error("TrackMetadata fields mismatch")
	}
	if tm.DurationMS != 180000 || tm.ISRC != "isrc999" {
		t.Error("TrackMetadata fields mismatch")
	}
}

func TestExtTrackMetadataConstruction(t *testing.T) {
	et := ExtTrackMetadata{
		ID: "ext1", Name: "Ext Track", Artists: "Ext Artist",
		AlbumName: "Ext Album", DurationMS: 210000, TrackNumber: 5,
		ISRC: "isrc_ext", TidalID: "td_ext", QobuzID: "qb_ext", Source: "tidal",
	}
	if et.ID != "ext1" || et.Name != "Ext Track" || et.Artists != "Ext Artist" {
		t.Error("ExtTrackMetadata fields mismatch")
	}
	if et.Source != "tidal" || et.TidalID != "td_ext" || et.QobuzID != "qb_ext" {
		t.Error("ExtTrackMetadata fields mismatch")
	}
}

func TestSelectedSourceConstruction(t *testing.T) {
	ss := SelectedSource{
		Provider: "qobuz", ProviderID: "qb123", Quality: "flac",
		URL: "https://qobuz.com/dl/1", Confidence: 0.95,
	}
	if ss.Provider != "qobuz" || ss.ProviderID != "qb123" || ss.Quality != "flac" {
		t.Error("SelectedSource fields mismatch")
	}
	if ss.URL != "https://qobuz.com/dl/1" || ss.Confidence != 0.95 {
		t.Error("SelectedSource fields mismatch")
	}
}

func TestTrackAvailConstruction(t *testing.T) {
	ta := TrackAvail{
		Deezer: true, Tidal: false, Qobuz: true,
		DeezerID: "dz_avail", TidalID: "", QobuzID: "qb_avail",
	}
	if !ta.Deezer || ta.Tidal || !ta.Qobuz {
		t.Error("TrackAvail boolean fields mismatch")
	}
	if ta.DeezerID != "dz_avail" || ta.QobuzID != "qb_avail" {
		t.Error("TrackAvail ID fields mismatch")
	}
}

func TestSearchAllResultConstruction(t *testing.T) {
	r := SearchAllResult{
		Tracks: []TrackMetadata{
			{SpotifyID: "t1", Name: "Track 1", Artists: "A1", DurationMS: 100000},
		},
		Artists: []SearchArtistResult{
			{ID: "a1", Name: "Artist 1", Followers: 1000},
		},
		Albums: []SearchAlbumResult{
			{ID: "al1", Name: "Album 1", Artists: "A1", TotalTracks: 10},
		},
		Playlists: []SearchPlaylistResult{
			{ID: "p1", Name: "Playlist 1", Owner: "User1", TotalTracks: 20},
		},
	}
	if len(r.Tracks) != 1 || r.Tracks[0].Name != "Track 1" {
		t.Error("SearchAllResult tracks mismatch")
	}
	if len(r.Artists) != 1 || r.Artists[0].Name != "Artist 1" {
		t.Error("SearchAllResult artists mismatch")
	}
	if len(r.Albums) != 1 || r.Albums[0].TotalTracks != 10 {
		t.Error("SearchAllResult albums mismatch")
	}
	if len(r.Playlists) != 1 || r.Playlists[0].TotalTracks != 20 {
		t.Error("SearchAllResult playlists mismatch")
	}
}

// ---------------------------------------------------------------------------
// FallbackManager
// ---------------------------------------------------------------------------

func TestNewFallbackManager(t *testing.T) {
	reg := NewProviderRegistry()
	priority := []string{"deezer", "tidal"}

	fm := NewFallbackManager(reg, priority)
	if fm == nil {
		t.Fatal("NewFallbackManager returned nil")
	}
	if fm.registry != reg {
		t.Error("registry reference not stored")
	}
	if len(fm.priority) != 2 || fm.priority[0] != "deezer" {
		t.Error("priority not stored correctly")
	}
}

func TestFallbackManager_DownloadWithFallback(t *testing.T) {
	reg := NewProviderRegistry()
	deezerCalled := false
	tidalCalled := false

	reg.RegisterDownloadProvider("deezer", &mockDownloadProvider{
		id: "deezer", name: "Deezer",
		download: func(_, _ string) ([]byte, error) {
			deezerCalled = true
			return nil, errors.New("deezer failed")
		},
	})
	reg.RegisterDownloadProvider("tidal", &mockDownloadProvider{
		id: "tidal", name: "Tidal",
		download: func(_, _ string) ([]byte, error) {
			tidalCalled = true
			return []byte("tidal data"), nil
		},
	})

	fm := NewFallbackManager(reg, []string{"deezer", "tidal"})
	result, err := fm.DownloadWithFallback(context.Background(), "track123", "high")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !deezerCalled {
		t.Error("expected deezer to be tried first")
	}
	if !tidalCalled {
		t.Error("expected tidal to be tried second")
	}
	if result.Provider != "tidal" {
		t.Errorf("expected tidal to succeed, got %s", result.Provider)
	}
	if result.FilePath != "tidal data" {
		t.Errorf("expected file path 'tidal data', got '%s'", result.FilePath)
	}
	if result.Quality != "high" {
		t.Errorf("expected quality high, got %s", result.Quality)
	}
}

func TestFallbackManager_AllProvidersFail(t *testing.T) {
	reg := NewProviderRegistry()
	reg.RegisterDownloadProvider("deezer", &mockDownloadProvider{
		id: "deezer", name: "Deezer",
		download: func(_, _ string) ([]byte, error) {
			return nil, errors.New("fail")
		},
	})

	fm := NewFallbackManager(reg, []string{"deezer"})
	_, err := fm.DownloadWithFallback(context.Background(), "track123", "high")
	if err == nil {
		t.Fatal("expected error when all providers fail")
	}
}

func TestFallbackManager_SkipsNilProvider(t *testing.T) {
	reg := NewProviderRegistry()
	// Only register tidal, skip deezer
	reg.RegisterDownloadProvider("tidal", &mockDownloadProvider{
		id: "tidal", name: "Tidal",
		download: func(_, _ string) ([]byte, error) {
			return []byte("ok"), nil
		},
	})

	fm := NewFallbackManager(reg, []string{"deezer", "tidal"})
	result, err := fm.DownloadWithFallback(context.Background(), "t1", "")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if result.Provider != "tidal" {
		t.Errorf("expected tidal, got %s", result.Provider)
	}
}

func TestFallbackManager_EmptyDataFromProvider(t *testing.T) {
	reg := NewProviderRegistry()
	reg.RegisterDownloadProvider("deezer", &mockDownloadProvider{
		id: "deezer", name: "Deezer",
		download: func(_, _ string) ([]byte, error) {
			return []byte{}, nil
		},
	})
	reg.RegisterDownloadProvider("tidal", &mockDownloadProvider{
		id: "tidal", name: "Tidal",
		download: func(_, _ string) ([]byte, error) {
			return []byte("real data"), nil
		},
	})

	fm := NewFallbackManager(reg, []string{"deezer", "tidal"})
	result, err := fm.DownloadWithFallback(context.Background(), "t1", "")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if result.Provider != "tidal" {
		t.Errorf("expected tidal fallback when deezer returned empty data, got %s", result.Provider)
	}
}

// ---------------------------------------------------------------------------
// SourceManager
// ---------------------------------------------------------------------------

func TestNewSourceManager(t *testing.T) {
	reg := NewProviderRegistry()
	sm := NewSourceManager(reg)
	if sm == nil {
		t.Fatal("NewSourceManager returned nil")
	}
	if sm.registry != reg {
		t.Error("registry not stored")
	}
	if len(sm.priority) != 3 {
		t.Errorf("expected 3 priority entries, got %d", len(sm.priority))
	}
	if sm.priority[0] != "deezer" {
		t.Errorf("expected first priority deezer, got %s", sm.priority[0])
	}
}

func TestSourceManager_Initialize(t *testing.T) {
	sm := NewSourceManager(NewProviderRegistry())
	if err := sm.Initialize(); err != nil {
		t.Errorf("Initialize returned error: %v", err)
	}
}

func TestSourceManager_GetSetPriority(t *testing.T) {
	sm := NewSourceManager(NewProviderRegistry())

	got := sm.GetPriority()
	if len(got) != 3 {
		t.Fatalf("expected 3 priorities, got %d", len(got))
	}

	newPrio := []string{"qobuz", "tidal"}
	sm.SetPriority(newPrio)
	got = sm.GetPriority()
	if len(got) != 2 || got[0] != "qobuz" || got[1] != "tidal" {
		t.Errorf("priority not updated, got %v", got)
	}
}

func TestSourceManager_GetRegistry(t *testing.T) {
	reg := NewProviderRegistry()
	sm := NewSourceManager(reg)

	if sm.GetRegistry() != reg {
		t.Error("GetRegistry returned different registry")
	}
}

func TestSourceManager_RegisterProviders(t *testing.T) {
	reg := NewProviderRegistry()
	sm := NewSourceManager(reg)
	called := false

	sm.RegisterProviders(func(r *ProviderRegistry) {
		called = true
		if r != reg {
			t.Error("registrar received wrong registry")
		}
	})

	if !called {
		t.Error("registrar was not called")
	}
}

// ---------------------------------------------------------------------------
// ExtAlbumMetadata / ExtArtistMetadata
// ---------------------------------------------------------------------------

func TestExtAlbumMetadataConstruction(t *testing.T) {
	album := ExtAlbumMetadata{
		ID: "alb_ext", Name: "Ext Album", Artists: "Ext Artist",
		ArtistID: "art_ext",
		Tracks: []ExtTrackMetadata{
			{ID: "et1", Name: "Ext Track 1", Artists: "Ext Artist", DurationMS: 200000},
		},
		CoverURL: "https://example.com/cover.jpg", ReleaseDate: "2024-06-01", TotalTracks: 1,
	}
	if album.ID != "alb_ext" || album.Name != "Ext Album" {
		t.Error("ExtAlbumMetadata fields mismatch")
	}
	if len(album.Tracks) != 1 || album.Tracks[0].ID != "et1" {
		t.Error("ExtAlbumMetadata tracks mismatch")
	}
	if album.TotalTracks != 1 || album.CoverURL == "" {
		t.Error("ExtAlbumMetadata fields mismatch")
	}
}

func TestExtArtistMetadataConstruction(t *testing.T) {
	a := ExtArtistMetadata{
		ID: "art_ext", Name: "Ext Artist", ImageURL: "https://example.com/artist.jpg",
	}
	if a.ID != "art_ext" || a.Name != "Ext Artist" || a.ImageURL == "" {
		t.Error("ExtArtistMetadata fields mismatch")
	}
}

// ---------------------------------------------------------------------------
// Detail types
// ---------------------------------------------------------------------------

func TestAlbumResponsePayload(t *testing.T) {
	p := AlbumResponsePayload{
		AlbumInfo: AlbumInfoMetadata{Name: "Test Album", TotalTracks: 5},
		TrackList: []AlbumTrackMetadata{
			{SpotifyID: "t1", Name: "Track 1", DurationMS: 180000},
		},
	}
	if p.AlbumInfo.Name != "Test Album" || p.AlbumInfo.TotalTracks != 5 {
		t.Error("AlbumInfo fields mismatch")
	}
	if len(p.TrackList) != 1 || p.TrackList[0].SpotifyID != "t1" {
		t.Error("TrackList mismatch")
	}
}

func TestArtistResponsePayload(t *testing.T) {
	p := ArtistResponsePayload{
		ArtistInfo: ArtistInfoMetadata{ID: "a1", Name: "Artist 1", Followers: 500},
		Albums: []ArtistAlbumMetadata{
			{ID: "alb1", Name: "Album 1", TotalTracks: 10},
		},
	}
	if p.ArtistInfo.Name != "Artist 1" || p.ArtistInfo.Followers != 500 {
		t.Error("ArtistInfo fields mismatch")
	}
	if len(p.Albums) != 1 || p.Albums[0].TotalTracks != 10 {
		t.Error("Albums mismatch")
	}
}

func TestPlaylistResponsePayload(t *testing.T) {
	p := PlaylistResponsePayload{
		PlaylistInfo: PlaylistInfoMetadata{},
		TrackList: []AlbumTrackMetadata{
			{SpotifyID: "t1", Name: "Track 1"},
		},
	}
	p.PlaylistInfo.Tracks.Total = 1
	p.PlaylistInfo.Owner.DisplayName = "OwnerName"

	if p.PlaylistInfo.Tracks.Total != 1 {
		t.Error("PlaylistInfo.Tracks.Total mismatch")
	}
	if p.PlaylistInfo.Owner.DisplayName != "OwnerName" {
		t.Error("PlaylistInfo.Owner.DisplayName mismatch")
	}
	if len(p.TrackList) != 1 {
		t.Error("TrackList length mismatch")
	}
}

func TestTrackResponse(t *testing.T) {
	tr := TrackResponse{
		Track: TrackMetadata{SpotifyID: "sp1", Name: "Track", Artists: "A", DurationMS: 200000},
	}
	if tr.Track.SpotifyID != "sp1" || tr.Track.Name != "Track" {
		t.Error("TrackResponse fields mismatch")
	}
}

// ---------------------------------------------------------------------------
// ProviderRegistrar type
// ---------------------------------------------------------------------------

func TestProviderRegistrar(t *testing.T) {
	reg := NewProviderRegistry()
	var fn ProviderRegistrar = func(r *ProviderRegistry) {
		r.RegisterSearchProvider("test", &mockSearchProvider{id: "test", name: "Test"})
	}
	fn(reg)
	if reg.GetSearchProvider("test") == nil {
		t.Error("ProviderRegistrar did not register provider")
	}
}

// ---------------------------------------------------------------------------
// DownloadResult
// ---------------------------------------------------------------------------

func TestDownloadResult(t *testing.T) {
	dr := DownloadResult{
		FilePath: "/tmp/file.mp3", Provider: "deezer", Quality: "flac", Format: "mp3",
	}
	if dr.FilePath != "/tmp/file.mp3" || dr.Provider != "deezer" {
		t.Error("DownloadResult fields mismatch")
	}
	if dr.Quality != "flac" || dr.Format != "mp3" {
		t.Error("DownloadResult fields mismatch")
	}
}
