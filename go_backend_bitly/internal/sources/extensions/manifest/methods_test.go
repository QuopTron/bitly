package manifest

import "testing"

func TestHasType_Found(t *testing.T) {
	m := &ExtensionManifest{Types: []ExtensionType{ExtensionTypeMetadataProvider, ExtensionTypeDownloadProvider}}
	if !m.HasType(ExtensionTypeMetadataProvider) {
		t.Error("expected true for metadata_provider")
	}
}

func TestHasType_NotFound(t *testing.T) {
	m := &ExtensionManifest{Types: []ExtensionType{ExtensionTypeDownloadProvider}}
	if m.HasType(ExtensionTypeMetadataProvider) {
		t.Error("expected false for metadata_provider")
	}
}

func TestIsMetadataProvider(t *testing.T) {
	m := &ExtensionManifest{Types: []ExtensionType{ExtensionTypeMetadataProvider}}
	if !m.IsMetadataProvider() {
		t.Error("expected true")
	}
}

func TestIsDownloadProvider(t *testing.T) {
	m := &ExtensionManifest{Types: []ExtensionType{ExtensionTypeDownloadProvider}}
	if !m.IsDownloadProvider() {
		t.Error("expected true")
	}
}

func TestIsLyricsProvider(t *testing.T) {
	m := &ExtensionManifest{Types: []ExtensionType{ExtensionTypeLyricsProvider}}
	if !m.IsLyricsProvider() {
		t.Error("expected true")
	}
}

func TestStopsProviderFallback_Nil(t *testing.T) {
	var m *ExtensionManifest
	if m.StopsProviderFallback() {
		t.Error("expected false for nil")
	}
}

func TestStopsProviderFallback_Stop(t *testing.T) {
	m := &ExtensionManifest{StopProviderFallback: true}
	if !m.StopsProviderFallback() {
		t.Error("expected true")
	}
}

func TestStopsProviderFallback_SkipBuiltIn(t *testing.T) {
	m := &ExtensionManifest{SkipBuiltInFallback: true}
	if !m.StopsProviderFallback() {
		t.Error("expected true")
	}
}

func TestIsDomainAllowed_Exact(t *testing.T) {
	m := &ExtensionManifest{Permissions: ExtensionPermissions{Network: []string{"example.com"}}}
	if !m.IsDomainAllowed("example.com") {
		t.Error("expected true for exact match")
	}
}

func TestIsDomainAllowed_Wildcard(t *testing.T) {
	m := &ExtensionManifest{Permissions: ExtensionPermissions{Network: []string{"*.example.com"}}}
	if !m.IsDomainAllowed("sub.example.com") {
		t.Error("expected true for subdomain")
	}
}

func TestIsDomainAllowed_NotAllowed(t *testing.T) {
	m := &ExtensionManifest{Permissions: ExtensionPermissions{Network: []string{"example.com"}}}
	if m.IsDomainAllowed("other.com") {
		t.Error("expected false")
	}
}

func TestIsDomainAllowed_CaseInsensitive(t *testing.T) {
	m := &ExtensionManifest{Permissions: ExtensionPermissions{Network: []string{"EXAMPLE.COM"}}}
	if !m.IsDomainAllowed("example.com") {
		t.Error("expected case-insensitive match")
	}
}

func TestIsDomainAllowed_EmptyPermissions(t *testing.T) {
	m := &ExtensionManifest{}
	if m.IsDomainAllowed("anything.com") {
		t.Error("expected false with empty permissions")
	}
}
