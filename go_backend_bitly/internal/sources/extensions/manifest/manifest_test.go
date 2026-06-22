package manifest

import (
	"testing"
)

func TestParseManifest_Success(t *testing.T) {
	data := []byte(`{
		"name": "test-ext",
		"displayName": "Test",
		"version": "1.0.0",
		"description": "A test extension",
		"type": ["metadata_provider"],
		"permissions": {"network":["*://example.com"],"storage":true,"file":false}
	}`)
	m, err := ParseManifest(data)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if m.Name != "test-ext" {
		t.Errorf("expected name test-ext, got %s", m.Name)
	}
}

func TestParseManifest_InvalidJSON(t *testing.T) {
	_, err := ParseManifest([]byte(`{invalid}`))
	if err == nil {
		t.Fatal("expected error for invalid JSON")
	}
}

func TestParseManifest_ValidationError(t *testing.T) {
	_, err := ParseManifest([]byte(`{}`))
	if err == nil {
		t.Fatal("expected validation error")
	}
}

func TestManifestValidationError_Error(t *testing.T) {
	e := &ManifestValidationError{Field: "name", Message: "is required"}
	expected := "manifest validation error: name - is required"
	if got := e.Error(); got != expected {
		t.Errorf("expected %q, got %q", expected, got)
	}
}

func TestValidate_NameRequired(t *testing.T) {
	m := &ExtensionManifest{Version: "1", Description: "d", Types: []ExtensionType{ExtensionTypeMetadataProvider}}
	err := m.Validate()
	if err == nil {
		t.Fatal("expected error for missing name")
	}
}

func TestValidate_VersionRequired(t *testing.T) {
	m := &ExtensionManifest{Name: "n", Description: "d", Types: []ExtensionType{ExtensionTypeMetadataProvider}}
	err := m.Validate()
	if err == nil {
		t.Fatal("expected error for missing version")
	}
}

func TestValidate_DescriptionRequired(t *testing.T) {
	m := &ExtensionManifest{Name: "n", Version: "1", Types: []ExtensionType{ExtensionTypeMetadataProvider}}
	err := m.Validate()
	if err == nil {
		t.Fatal("expected error for missing description")
	}
}

func TestValidate_TypeRequired(t *testing.T) {
	m := &ExtensionManifest{Name: "n", Version: "1", Description: "d"}
	err := m.Validate()
	if err == nil {
		t.Fatal("expected error for missing types")
	}
}

func TestValidate_InvalidType(t *testing.T) {
	m := &ExtensionManifest{Name: "n", Version: "1", Description: "d", Types: []ExtensionType{"invalid_type"}}
	err := m.Validate()
	if err == nil {
		t.Fatal("expected error for invalid type")
	}
}

func TestValidate_SettingKeyRequired(t *testing.T) {
	m := &ExtensionManifest{Name: "n", Version: "1", Description: "d", Types: []ExtensionType{ExtensionTypeMetadataProvider}, Settings: []ExtensionSetting{{Type: SettingTypeString}}}
	err := m.Validate()
	if err == nil {
		t.Fatal("expected error for missing setting key")
	}
}

func TestValidate_SettingTypeRequired(t *testing.T) {
	m := &ExtensionManifest{Name: "n", Version: "1", Description: "d", Types: []ExtensionType{ExtensionTypeMetadataProvider}, Settings: []ExtensionSetting{{Key: "k"}}}
	err := m.Validate()
	if err == nil {
		t.Fatal("expected error for missing setting type")
	}
}

func TestValidate_SelectRequiresOptions(t *testing.T) {
	m := &ExtensionManifest{Name: "n", Version: "1", Description: "d", Types: []ExtensionType{ExtensionTypeMetadataProvider}, Settings: []ExtensionSetting{{Key: "k", Type: SettingTypeSelect}}}
	err := m.Validate()
	if err == nil {
		t.Fatal("expected error: select requires options")
	}
}

func TestValidate_ButtonRequiresAction(t *testing.T) {
	m := &ExtensionManifest{Name: "n", Version: "1", Description: "d", Types: []ExtensionType{ExtensionTypeMetadataProvider}, Settings: []ExtensionSetting{{Key: "k", Type: SettingTypeButton}}}
	err := m.Validate()
	if err == nil {
		t.Fatal("expected error: button requires action")
	}
}
