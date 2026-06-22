package store

import (
	"fmt"
	"strings"
)

func (s *Store) GetExtensionsWithStatus(forceRefresh bool) ([]storeExtensionResponse, error) {
	registry, err := s.FetchRegistry(forceRefresh)
	if err != nil {
		return nil, err
	}

	installed := make(map[string]string)
	rawInstalled := make(map[string]string)
	for _, ext := range s.manager.ListExtensions() {
		if ext == nil {
			continue
		}
		rawInstalled[ext.ID] = ext.Version
		installed[normalizeStoreID(ext.ID)] = ext.Version
	}

	result := make([]storeExtensionResponse, 0, len(registry.Extensions))
	for i := range registry.Extensions {
		ext := &registry.Extensions[i]
		resp := ext.toResponse()
		storeID := ext.ID
		normStoreID := normalizeStoreID(storeID)
		if installedVersion, ok := rawInstalled[storeID]; ok {
			resp.IsInstalled = true
			resp.InstalledVersion = installedVersion
			resp.HasUpdate = compareVersions(ext.Version, installedVersion) > 0
		} else if installedVersion, ok := installed[normStoreID]; ok {
			resp.IsInstalled = true
			resp.InstalledVersion = installedVersion
			resp.HasUpdate = compareVersions(ext.Version, installedVersion) > 0
		}
		result = append(result, resp)
	}
	return result, nil
}

func (s *Store) GetCategories() []string {
	return []string{
		CategoryMetadata,
		CategoryDownload,
		CategoryUtility,
		CategoryLyrics,
		CategoryIntegration,
	}
}

func (s *Store) SearchExtensions(query, category string) ([]storeExtensionResponse, error) {
	extensions, err := s.GetExtensionsWithStatus(false)
	if err != nil {
		return nil, err
	}
	if query == "" && category == "" {
		return extensions, nil
	}

	result := make([]storeExtensionResponse, 0, len(extensions))
	queryLower := strings.ToLower(query)
	for _, ext := range extensions {
		if category != "" && ext.Category != category {
			continue
		}
		if query != "" {
			if !containsIgnoreCase(ext.Name, queryLower) &&
				!containsIgnoreCase(ext.DisplayName, queryLower) &&
				!containsIgnoreCase(ext.Description, queryLower) {
				found := false
				for _, tag := range ext.Tags {
					if containsIgnoreCase(tag, queryLower) {
						found = true
						break
					}
				}
				if !found {
					continue
				}
			}
		}
		result = append(result, ext)
	}
	return result, nil
}

func normalizeStoreID(id string) string {
	s := strings.ToLower(id)
	s = strings.ReplaceAll(s, " ", "-")
	s = strings.ReplaceAll(s, "_", "-")
	return s
}

func compareVersions(v1, v2 string) int {
	v1Parts := strings.Split(strings.TrimPrefix(v1, "v"), ".")
	v2Parts := strings.Split(strings.TrimPrefix(v2, "v"), ".")
	maxLen := len(v1Parts)
	if len(v2Parts) > maxLen {
		maxLen = len(v2Parts)
	}
	var n1, n2 int
	for i := 0; i < maxLen; i++ {
		n1, n2 = 0, 0
		if i < len(v1Parts) {
			fmt.Sscanf(v1Parts[i], "%d", &n1)
		}
		if i < len(v2Parts) {
			fmt.Sscanf(v2Parts[i], "%d", &n2)
		}
		if n1 < n2 {
			return -1
		}
		if n1 > n2 {
			return 1
		}
	}
	return 0
}
