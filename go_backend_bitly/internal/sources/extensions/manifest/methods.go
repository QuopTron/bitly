package manifest

import "strings"

func (m *ExtensionManifest) HasType(t ExtensionType) bool {
	for _, et := range m.Types {
		if et == t {
			return true
		}
	}
	return false
}

func (m *ExtensionManifest) IsMetadataProvider() bool {
	return m.HasType(ExtensionTypeMetadataProvider)
}

func (m *ExtensionManifest) IsDownloadProvider() bool {
	return m.HasType(ExtensionTypeDownloadProvider)
}

func (m *ExtensionManifest) IsLyricsProvider() bool {
	return m.HasType(ExtensionTypeLyricsProvider)
}

func (m *ExtensionManifest) StopsProviderFallback() bool {
	if m == nil {
		return false
	}
	return m.StopProviderFallback || m.SkipBuiltInFallback
}

func (m *ExtensionManifest) IsDomainAllowed(domain string) bool {
	domain = strings.ToLower(strings.TrimSpace(domain))
	for _, allowed := range m.Permissions.Network {
		allowed = strings.ToLower(strings.TrimSpace(allowed))
		if allowed == domain {
			return true
		}
		if strings.HasPrefix(allowed, "*.") {
			suffix := allowed[1:]
			if strings.HasSuffix(domain, suffix) {
				return true
			}
		}
	}
	return false
}

func (m *ExtensionManifest) HasCustomSearch() bool {
	return m.SearchBehavior != nil && m.SearchBehavior.Enabled
}

func (m *ExtensionManifest) HasCustomMatching() bool {
	return m.TrackMatching != nil && m.TrackMatching.CustomMatching
}

func (m *ExtensionManifest) HasPostProcessing() bool {
	return m.PostProcessing != nil && m.PostProcessing.Enabled
}

func (m *ExtensionManifest) HasURLHandler() bool {
	return m.URLHandler != nil && m.URLHandler.Enabled && len(m.URLHandler.Patterns) > 0
}

func (m *ExtensionManifest) MatchesURL(urlStr string) bool {
	if !m.HasURLHandler() {
		return false
	}
	urlStr = strings.ToLower(strings.TrimSpace(urlStr))
	for _, pattern := range m.URLHandler.Patterns {
		pattern = strings.ToLower(strings.TrimSpace(pattern))
		if strings.Contains(urlStr, pattern) {
			return true
		}
	}
	return false
}

func (m *ExtensionManifest) GetPostProcessingHooks() []PostProcessingHook {
	if m.PostProcessing == nil {
		return nil
	}
	return m.PostProcessing.Hooks
}
