package share

import (
	"encoding/json"
	"fmt"
	"strings"
	"sync"
)

func (s *Service) FindCollectionAcrossExtensions(requestJSON string) (string, error) {
	var req struct {
		Name              string `json:"name"`
		Artists           string `json:"artists"`
		Type              string `json:"type"`
		SourceExtensionID string `json:"source_extension_id"`
	}
	if err := json.Unmarshal([]byte(requestJSON), &req); err != nil {
		return "", fmt.Errorf("FindCollectionAcrossExtensions: invalid request: %w", err)
	}

	req.Name = strings.TrimSpace(req.Name)
	req.Artists = strings.TrimSpace(req.Artists)
	req.Type = strings.ToLower(strings.TrimSpace(req.Type))
	req.SourceExtensionID = strings.TrimSpace(req.SourceExtensionID)

	if req.Name == "" {
		return "[]", nil
	}
	if req.Type == "" {
		req.Type = "album"
	}

	var candidates []string
	for _, ext := range s.manager.ListExtensions() {
		if ext == nil || ext.ID == req.SourceExtensionID || !ext.Enabled || ext.Error != "" {
			continue
		}
		if !strings.Contains(ext.Type, "metadata_provider") {
			continue
		}
		candidates = append(candidates, ext.ID)
	}

	if len(candidates) == 0 {
		return "[]", nil
	}

	cacheKey := s.buildCacheKey(req.Name, req.Artists, req.Type, req.SourceExtensionID, candidates)
	if cached := s.cacheGet(cacheKey); cached != "" {
		return cached, nil
	}

	query := req.Name
	if req.Artists != "" {
		query += " " + req.Artists
	}

	results := make([]CrossExtensionShareResult, len(candidates))
	var wg sync.WaitGroup
	for i, extID := range candidates {
		wg.Add(1)
		go func(index int, id string) {
			defer wg.Done()
			results[index] = s.findForExtension(id, req.Type, req.Name, req.Artists, query)
		}(i, extID)
	}
	wg.Wait()

	data, err := json.Marshal(results)
	if err != nil {
		return "[]", err
	}
	response := string(data)

	if s.resultsCacheable(results) {
		s.cacheSet(cacheKey, response)
	}
	return response, nil
}
