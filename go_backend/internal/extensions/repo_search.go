package extensions

import (
	"strings"
)

func (es *ExtensionStore) SearchExtensions(query, category string) ([]RepoExtension, error) {
	registry, err := es.GetRegistry()
	if err != nil {
		return nil, err
	}

	query = strings.ToLower(strings.TrimSpace(query))
	category = strings.ToLower(strings.TrimSpace(category))

	var results []RepoExtension
	for _, ext := range registry.Extensions {
		if category != "" && strings.ToLower(ext.Category) != category {
			continue
		}
		if query != "" {
			match := strings.Contains(strings.ToLower(ext.Name), query) ||
				strings.Contains(strings.ToLower(ext.DisplayName), query) ||
				strings.Contains(strings.ToLower(ext.Description), query) ||
				strings.Contains(strings.ToLower(ext.ID), query)
			for _, tag := range ext.Tags {
				if strings.Contains(strings.ToLower(tag), query) {
					match = true
					break
				}
			}
			if !match {
				continue
			}
		}
		results = append(results, ext)
	}
	return results, nil
}

// GetCategories returns available extension categories.
func (es *ExtensionStore) GetCategories() ([]RepoCategory, error) {
	registry, err := es.GetRegistry()
	if err != nil {
		return nil, err
	}
	return registry.Categories, nil
}

// DownloadExtension downloads an extension package with SHA-256 verification.
