package providers

import (
	"testing"

	"github.com/zarz/bitly/go_backend_bitly/internal/sources/core"
)

// Compile-time interface checks.
var (
	_ core.SearchProvider    = (*deezerSearchAdapter)(nil)
	_ core.SearchProvider    = (*tidalSearchAdapter)(nil)
	_ core.SearchProvider    = (*qobuzSearchAdapter)(nil)
	_ core.MetadataProvider  = (*deezerMetadataAdapter)(nil)
	_ core.MetadataProvider  = (*tidalMetadataAdapter)(nil)
	_ core.MetadataProvider  = (*qobuzMetadataAdapter)(nil)
	_ core.DownloadProvider  = (*deezerDownloadAdapter)(nil)
	_ core.DownloadProvider  = (*tidalDownloadAdapter)(nil)
	_ core.DownloadProvider  = (*qobuzDownloadAdapter)(nil)
)

type adapterInfo struct {
	id   string
	name string
}

func expectedSearchAdapters() map[string]adapterInfo {
	return map[string]adapterInfo{
		"deezer": {id: "deezer", name: "Deezer"},
		"tidal":  {id: "tidal", name: "Tidal"},
		"qobuz":  {id: "qobuz", name: "Qobuz"},
	}
}

func expectedMetadataAdapters() map[string]adapterInfo {
	return map[string]adapterInfo{
		"deezer": {id: "deezer", name: "Deezer"},
		"tidal":  {id: "tidal", name: "Tidal"},
		"qobuz":  {id: "qobuz", name: "Qobuz"},
	}
}

func expectedDownloadAdapters() map[string]adapterInfo {
	return map[string]adapterInfo{
		"deezer": {id: "deezer", name: "Deezer"},
		"tidal":  {id: "tidal", name: "Tidal"},
		"qobuz":  {id: "qobuz", name: "Qobuz"},
	}
}

func TestSearchAdapterIdentity(t *testing.T) {
	adapters := map[string]core.SearchProvider{
		"deezer": &deezerSearchAdapter{},
		"tidal":  &tidalSearchAdapter{},
		"qobuz":  &qobuzSearchAdapter{},
	}
	expected := expectedSearchAdapters()

	for key, p := range adapters {
		want, ok := expected[key]
		if !ok {
			t.Errorf("unexpected adapter key %q", key)
			continue
		}
		if got := p.ID(); got != want.id {
			t.Errorf("%s adapter ID() = %q; want %q", key, got, want.id)
		}
		if got := p.Name(); got != want.name {
			t.Errorf("%s adapter Name() = %q; want %q", key, got, want.name)
		}
	}
}

func TestMetadataAdapterIdentity(t *testing.T) {
	adapters := map[string]core.MetadataProvider{
		"deezer": &deezerMetadataAdapter{},
		"tidal":  &tidalMetadataAdapter{},
		"qobuz":  &qobuzMetadataAdapter{},
	}
	expected := expectedMetadataAdapters()

	for key, p := range adapters {
		want, ok := expected[key]
		if !ok {
			t.Errorf("unexpected adapter key %q", key)
			continue
		}
		if got := p.ID(); got != want.id {
			t.Errorf("%s metadata adapter ID() = %q; want %q", key, got, want.id)
		}
		if got := p.Name(); got != want.name {
			t.Errorf("%s metadata adapter Name() = %q; want %q", key, got, want.name)
		}
	}
}

func TestDownloadAdapterIdentity(t *testing.T) {
	adapters := map[string]core.DownloadProvider{
		"deezer": &deezerDownloadAdapter{},
		"tidal":  &tidalDownloadAdapter{},
		"qobuz":  &qobuzDownloadAdapter{},
	}
	expected := expectedDownloadAdapters()

	for key, p := range adapters {
		want, ok := expected[key]
		if !ok {
			t.Errorf("unexpected adapter key %q", key)
			continue
		}
		if got := p.ID(); got != want.id {
			t.Errorf("%s download adapter ID() = %q; want %q", key, got, want.id)
		}
		if got := p.Name(); got != want.name {
			t.Errorf("%s download adapter Name() = %q; want %q", key, got, want.name)
		}
	}
}

func TestRegisterAllBuiltin(t *testing.T) {
	registry := core.NewProviderRegistry()
	RegisterAllBuiltin(registry)

	searchProviders := registry.GetAllSearchProviders()
	if len(searchProviders) != 3 {
		t.Errorf("GetAllSearchProviders() returned %d providers; want 3", len(searchProviders))
	}

	downloadProviders := registry.GetAllDownloadProviders()
	if len(downloadProviders) != 3 {
		t.Errorf("GetAllDownloadProviders() returned %d providers; want 3", len(downloadProviders))
	}

	expectedSearch := expectedSearchAdapters()
	for _, p := range searchProviders {
		want, ok := expectedSearch[p.ID()]
		if !ok {
			t.Errorf("unexpected search provider ID %q registered", p.ID())
			continue
		}
		if p.Name() != want.name {
			t.Errorf("search provider %q Name() = %q; want %q", p.ID(), p.Name(), want.name)
		}
	}

	expectedDownload := expectedDownloadAdapters()
	for _, p := range downloadProviders {
		want, ok := expectedDownload[p.ID()]
		if !ok {
			t.Errorf("unexpected download provider ID %q registered", p.ID())
			continue
		}
		if p.Name() != want.name {
			t.Errorf("download provider %q Name() = %q; want %q", p.ID(), p.Name(), want.name)
		}
	}

	// Verify each expected provider is retrievable by ID.
	for id := range expectedSearch {
		if got := registry.GetSearchProvider(id); got == nil {
			t.Errorf("GetSearchProvider(%q) returned nil", id)
		}
	}
	for id := range expectedDownload {
		if got := registry.GetDownloadProvider(id); got == nil {
			t.Errorf("GetDownloadProvider(%q) returned nil", id)
		}
	}
}

func TestDownloadAdaptersReturnError(t *testing.T) {
	adapters := []struct {
		name string
		p    core.DownloadProvider
	}{
		{"deezer", &deezerDownloadAdapter{}},
		{"tidal", &tidalDownloadAdapter{}},
		{"qobuz", &qobuzDownloadAdapter{}},
	}

	for _, a := range adapters {
		data, err := a.p.Download("someID", "320")
		if data != nil {
			t.Errorf("%s Download() returned non-nil data; want nil", a.name)
		}
		if err == nil {
			t.Errorf("%s Download() returned nil error; want error", a.name)
		}
	}
}
