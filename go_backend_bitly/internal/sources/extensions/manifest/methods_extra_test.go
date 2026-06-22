package manifest

import "testing"

func TestHasCustomSearch_Enabled(t *testing.T) {
	m := &ExtensionManifest{SearchBehavior: &SearchBehaviorConfig{Enabled: true}}
	if !m.HasCustomSearch() {
		t.Error("expected true")
	}
}

func TestHasCustomSearch_Disabled(t *testing.T) {
	m := &ExtensionManifest{SearchBehavior: &SearchBehaviorConfig{Enabled: false}}
	if m.HasCustomSearch() {
		t.Error("expected false")
	}
}

func TestHasCustomSearch_Nil(t *testing.T) {
	m := &ExtensionManifest{}
	if m.HasCustomSearch() {
		t.Error("expected false for nil")
	}
}

func TestHasCustomMatching(t *testing.T) {
	m := &ExtensionManifest{TrackMatching: &TrackMatchingConfig{CustomMatching: true}}
	if !m.HasCustomMatching() {
		t.Error("expected true")
	}
}

func TestHasPostProcessing(t *testing.T) {
	m := &ExtensionManifest{PostProcessing: &PostProcessingConfig{Enabled: true}}
	if !m.HasPostProcessing() {
		t.Error("expected true")
	}
}

func TestHasURLHandler_EnabledWithPatterns(t *testing.T) {
	m := &ExtensionManifest{URLHandler: &URLHandlerConfig{Enabled: true, Patterns: []string{"youtube.com"}}}
	if !m.HasURLHandler() {
		t.Error("expected true")
	}
}

func TestHasURLHandler_NoPatterns(t *testing.T) {
	m := &ExtensionManifest{URLHandler: &URLHandlerConfig{Enabled: true}}
	if m.HasURLHandler() {
		t.Error("expected false with no patterns")
	}
}

func TestMatchesURL_Found(t *testing.T) {
	m := &ExtensionManifest{URLHandler: &URLHandlerConfig{Enabled: true, Patterns: []string{"youtube.com"}}}
	if !m.MatchesURL("https://youtube.com/watch") {
		t.Error("expected true")
	}
}

func TestMatchesURL_NotFound(t *testing.T) {
	m := &ExtensionManifest{URLHandler: &URLHandlerConfig{Enabled: true, Patterns: []string{"youtube.com"}}}
	if m.MatchesURL("https://vimeo.com") {
		t.Error("expected false")
	}
}

func TestMatchesURL_NoHandler(t *testing.T) {
	m := &ExtensionManifest{}
	if m.MatchesURL("https://youtube.com") {
		t.Error("expected false with no handler")
	}
}

func TestGetPostProcessingHooks_Nil(t *testing.T) {
	m := &ExtensionManifest{}
	if hooks := m.GetPostProcessingHooks(); hooks != nil {
		t.Error("expected nil")
	}
}

func TestGetPostProcessingHooks_Returned(t *testing.T) {
	hooks := []PostProcessingHook{{ID: "hook1"}}
	m := &ExtensionManifest{PostProcessing: &PostProcessingConfig{Hooks: hooks}}
	if got := m.GetPostProcessingHooks(); len(got) != 1 || got[0].ID != "hook1" {
		t.Error("expected hooks to be returned")
	}
}
