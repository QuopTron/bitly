package availability

import (
	"context"
	"testing"

	"github.com/zarz/bitly/go_backend_bitly/internal/sources/core"
)

func TestISRCResolutionResultAllFields(t *testing.T) {
	r := &ISRCResolutionResult{
		ISRC:       "USABC1234567",
		TidalURL:   "https://tidal.com/track/1",
		QobuzURL:   "https://qobuz.com/track/2",
		DeezerURL:  "https://deezer.com/track/3",
		SpotifyURL: "https://open.spotify.com/track/4",
		Provider:   "deezer_songlink",
	}
	if r.ISRC != "USABC1234567" {
		t.Errorf("ISRC = %q, want %q", r.ISRC, "USABC1234567")
	}
	if r.TidalURL != "https://tidal.com/track/1" {
		t.Errorf("TidalURL = %q", r.TidalURL)
	}
	if r.QobuzURL != "https://qobuz.com/track/2" {
		t.Errorf("QobuzURL = %q", r.QobuzURL)
	}
	if r.DeezerURL != "https://deezer.com/track/3" {
		t.Errorf("DeezerURL = %q", r.DeezerURL)
	}
	if r.SpotifyURL != "https://open.spotify.com/track/4" {
		t.Errorf("SpotifyURL = %q", r.SpotifyURL)
	}
	if r.Provider != "deezer_songlink" {
		t.Errorf("Provider = %q", r.Provider)
	}
}

func TestISRCResolutionResultEmpty(t *testing.T) {
	r := &ISRCResolutionResult{ISRC: "USABC1234567"}
	if r.TidalURL != "" {
		t.Errorf("TidalURL = %q, want empty", r.TidalURL)
	}
	if r.QobuzURL != "" {
		t.Errorf("QobuzURL = %q, want empty", r.QobuzURL)
	}
	if r.DeezerURL != "" {
		t.Errorf("DeezerURL = %q, want empty", r.DeezerURL)
	}
	if r.SpotifyURL != "" {
		t.Errorf("SpotifyURL = %q, want empty", r.SpotifyURL)
	}
	if r.Provider != "" {
		t.Errorf("Provider = %q, want empty", r.Provider)
	}
}

func TestLinkResolverEmptyPriority(t *testing.T) {
	lr := &LinkResolver{
		resolverPriority: []string{},
	}
	result, err := lr.ResolveByISRC("USABC1234567")
	if err != nil {
		t.Errorf("ResolveByISRC returned error: %v", err)
	}
	if result == nil {
		t.Fatal("ResolveByISRC returned nil")
	}
	if result.ISRC != "USABC1234567" {
		t.Errorf("ISRC = %q, want %q", result.ISRC, "USABC1234567")
	}
	if result.Provider != "" {
		t.Errorf("Provider = %q, want empty", result.Provider)
	}
	if result.DeezerURL != "" || result.TidalURL != "" || result.QobuzURL != "" {
		t.Error("empty priority resolver should return result with no URLs")
	}
}

func TestLinkResolverNilHTTPClient(t *testing.T) {
	lr := &LinkResolver{
		resolverPriority: []string{},
	}
	result, err := lr.ResolveByISRC("XYZ")
	if err != nil {
		t.Errorf("ResolveByISRC returned error: %v", err)
	}
	if result == nil {
		t.Fatal("ResolveByISRC returned nil")
	}
	if result.ISRC != "XYZ" {
		t.Errorf("ISRC = %q, want %q", result.ISRC, "XYZ")
	}
}

func TestGetLinkResolver(t *testing.T) {
	lr := GetLinkResolver()
	if lr == nil {
		t.Fatal("GetLinkResolver() returned nil")
	}
	if lr.httpClient == nil {
		t.Error("GetLinkResolver().httpClient is nil")
	}
	if len(lr.resolverPriority) == 0 {
		t.Error("resolverPriority is empty")
	}
}

func TestGetLinkResolverSingleton(t *testing.T) {
	lr1 := GetLinkResolver()
	lr2 := GetLinkResolver()
	if lr1 != lr2 {
		t.Error("GetLinkResolver() returned different instances")
	}
}

func TestGetLinkResolverPriority(t *testing.T) {
	lr := GetLinkResolver()
	if len(lr.resolverPriority) != 2 {
		t.Fatalf("resolverPriority has %d entries, want 2", len(lr.resolverPriority))
	}
	if lr.resolverPriority[0] != "songstats" {
		t.Errorf("priority[0] = %q, want %q", lr.resolverPriority[0], "songstats")
	}
	if lr.resolverPriority[1] != "deezer_songlink" {
		t.Errorf("priority[1] = %q, want %q", lr.resolverPriority[1], "deezer_songlink")
	}
}

func TestLinkResolverPriorityOrdering(t *testing.T) {
	lr := &LinkResolver{
		resolverPriority: []string{"unregistered_alpha", "unregistered_beta"},
	}

	result, err := lr.ResolveByISRC("USABC1234567")
	if err != nil {
		t.Errorf("ResolveByISRC returned error: %v", err)
	}
	if result == nil {
		t.Fatal("ResolveByISRC returned nil")
	}
	if result.ISRC != "USABC1234567" {
		t.Errorf("ISRC = %q", result.ISRC)
	}
}

func TestLinkResolverCustomPriority(t *testing.T) {
	lr := &LinkResolver{
		resolverPriority: []string{"unknown_resolver"},
	}

	result, err := lr.ResolveByISRC("TEST123")
	if err != nil {
		t.Errorf("ResolveByISRC returned error: %v", err)
	}
	if result == nil {
		t.Fatal("ResolveByISRC returned nil")
	}
	if result.ISRC != "TEST123" {
		t.Errorf("ISRC = %q, want %q", result.ISRC, "TEST123")
	}
	if result.Provider != "" {
		t.Errorf("Provider = %q, want empty for unknown resolver", result.Provider)
	}
}

func TestNewClient(t *testing.T) {
	c := NewClient()
	if c == nil {
		t.Fatal("NewClient() returned nil")
	}
	if c.client == nil {
		t.Error("NewClient().client is nil")
	}
	if c.isrcSearcher != nil {
		t.Error("NewClient().isrcSearcher should be nil initially")
	}
}

func TestNewClientSingleton(t *testing.T) {
	c1 := NewClient()
	c2 := NewClient()
	if c1 != c2 {
		t.Error("NewClient() returned different instances")
	}
}

func TestNewIDHSClient(t *testing.T) {
	c := NewIDHSClient()
	if c == nil {
		t.Fatal("NewIDHSClient() returned nil")
	}
	if c.client == nil {
		t.Error("NewIDHSClient().client is nil")
	}
}

func TestNewIDHSClientSingleton(t *testing.T) {
	c1 := NewIDHSClient()
	c2 := NewIDHSClient()
	if c1 != c2 {
		t.Error("NewIDHSClient() returned different instances")
	}
}

func TestClientSetISRCSearcher(t *testing.T) {
	c := NewClient()
	c.SetISRCSearcher(nil)
	if c.isrcSearcher != nil {
		t.Error("SetISRCSearcher(nil) should set isrcSearcher to nil")
	}

	mockSearcher := &mockISRCSearcher{}
	c.SetISRCSearcher(mockSearcher)
	if c.isrcSearcher == nil {
		t.Error("SetISRCSearcher should set isrcSearcher")
	}
}

type mockISRCSearcher struct{}

func (m *mockISRCSearcher) SearchByISRC(_ context.Context, _ string) (*core.TrackMetadata, error) {
	return nil, nil
}

func TestPlatformLinkConstruction(t *testing.T) {
	pl := platformLink{URL: "https://example.com/track"}
	if pl.URL != "https://example.com/track" {
		t.Errorf("URL = %q", pl.URL)
	}
}

func TestPlatformLinkEmpty(t *testing.T) {
	pl := platformLink{}
	if pl.URL != "" {
		t.Errorf("URL = %q, want empty", pl.URL)
	}
}
