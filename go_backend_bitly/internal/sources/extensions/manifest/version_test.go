package manifest

import "testing"

func TestCompareVersions_Equal(t *testing.T) {
	if c := CompareVersions("1.2.3", "1.2.3"); c != 0 {
		t.Errorf("expected 0, got %d", c)
	}
}

func TestCompareVersions_VPrefix(t *testing.T) {
	if c := CompareVersions("v1.2.3", "1.2.3"); c != 0 {
		t.Errorf("expected 0, got %d", c)
	}
}

func TestCompareVersions_Less(t *testing.T) {
	if c := CompareVersions("1.2.3", "2.0.0"); c != -1 {
		t.Errorf("expected -1, got %d", c)
	}
}

func TestCompareVersions_Greater(t *testing.T) {
	if c := CompareVersions("2.0.0", "1.2.3"); c != 1 {
		t.Errorf("expected 1, got %d", c)
	}
}

func TestCompareVersions_DifferentParts(t *testing.T) {
	if c := CompareVersions("1.2", "1.2.3"); c != -1 {
		t.Errorf("expected -1, got %d", c)
	}
}

func TestCompareVersions_NonNumeric(t *testing.T) {
	if c := CompareVersions("1.a.3", "1.b.3"); c != 0 {
		t.Errorf("expected 0 (non-numeric default to 0), got %d", c)
	}
}

func TestCompareVersions_NonNumericVsNumeric(t *testing.T) {
	if c := CompareVersions("1.a.3", "1.5.3"); c != -1 {
		t.Errorf("expected -1 (non-numeric=0 < 5), got %d", c)
	}
}

func TestCompareVersions_Empty(t *testing.T) {
	if c := CompareVersions("", ""); c != 0 {
		t.Errorf("expected 0, got %d", c)
	}
}

func TestCompareVersions_OneEmpty(t *testing.T) {
	if c := CompareVersions("1.0", ""); c != 1 {
		t.Errorf("expected 1, got %d", c)
	}
}

func TestToJSON_Success(t *testing.T) {
	m := &ExtensionManifest{Name: "test", Version: "1", Description: "d", Types: []ExtensionType{ExtensionTypeMetadataProvider}, Permissions: ExtensionPermissions{Storage: true}}
	data, err := m.ToJSON()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(data) == 0 {
		t.Fatal("expected non-empty JSON")
	}
}

func TestToJSON_RoundTrip(t *testing.T) {
	m := &ExtensionManifest{Name: "test", Version: "1.0", Description: "desc", Types: []ExtensionType{ExtensionTypeDownloadProvider}, Permissions: ExtensionPermissions{Network: []string{"*"}}}
	data, err := m.ToJSON()
	if err != nil {
		t.Fatalf("marshal error: %v", err)
	}
	m2, err := ParseManifest(data)
	if err != nil {
		t.Fatalf("parse error: %v", err)
	}
	if m2.Name != m.Name || m2.Version != m.Version || !m2.IsDownloadProvider() {
		t.Error("round-trip mismatch")
	}
}
