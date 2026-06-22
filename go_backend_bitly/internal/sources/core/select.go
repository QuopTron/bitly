package core

import "sort"

func (s *SourceSelector) SelectBestSource(trackID, isrc, requestedQuality string) (*SelectedSource, error) {
	if s.availChecker != nil {
		result, err := s.availChecker.CheckTrackAvailability(trackID, isrc)
		if err == nil && result != nil {
			if sel := s.bestFromAny(result); sel != nil {
				sel.Quality = bestQualityFor(requestedQuality, sel.Provider)
				return sel, nil
			}
		}
	}

	if s.isrcResolver != nil && isrc != "" {
		result, err := s.isrcResolver.ResolveByISRC(isrc)
		if err == nil && result != nil {
			if sel := s.bestFromResolveResult(trackID, result); sel != nil {
				sel.Quality = bestQualityFor(requestedQuality, sel.Provider)
				return sel, nil
			}
		}
	}

	if len(s.priority) > 0 {
		return &SelectedSource{
			Provider:   s.priority[0],
			ProviderID: trackID,
			Quality:    bestQualityFor(requestedQuality, s.priority[0]),
			Confidence: 0.5,
		}, nil
	}

	return &SelectedSource{
		Provider:   "deezer",
		ProviderID: trackID,
		Quality:    bestQualityFor(requestedQuality, "deezer"),
		Confidence: 0.3,
	}, nil
}

func (s *SourceSelector) bestFromAny(avail interface{}) *SelectedSource {
	availMap, ok := avail.(map[string]interface{})
	if !ok {
		return nil
	}
	type candidate struct {
		provider   string
		providerID string
		available  bool
	}

	deezer, _ := availMap["deezer"].(bool)
	tidal, _ := availMap["tidal"].(bool)
	qobuz, _ := availMap["qobuz"].(bool)
	deezerID, _ := availMap["deezer_id"].(string)
	tidalID, _ := availMap["tidal_id"].(string)
	qobuzID, _ := availMap["qobuz_id"].(string)

	cands := []candidate{
		{"deezer", deezerID, deezer},
		{"tidal", tidalID, tidal},
		{"qobuz", qobuzID, qobuz},
	}

	rank := make(map[string]int, len(s.priority))
	for i, p := range s.priority {
		rank[p] = i
	}

	sort.SliceStable(cands, func(i, j int) bool {
		if cands[i].available != cands[j].available {
			return cands[i].available
		}
		return rank[cands[i].provider] < rank[cands[j].provider]
	})

	for _, c := range cands {
		if c.available {
			return &SelectedSource{
				Provider:   c.provider,
				ProviderID: c.providerID,
				Confidence: 0.85,
			}
		}
	}

	return nil
}

func (s *SourceSelector) bestFromResolveResult(trackID string, result interface{}) *SelectedSource {
	resultMap, ok := result.(map[string]interface{})
	if !ok {
		return nil
	}
	if deezerURL, _ := resultMap["deezer_url"].(string); deezerURL != "" {
		return &SelectedSource{Provider: "deezer", ProviderID: trackID, Confidence: 0.7}
	}
	if tidalURL, _ := resultMap["tidal_url"].(string); tidalURL != "" {
		return &SelectedSource{Provider: "tidal", ProviderID: trackID, Confidence: 0.7}
	}
	if qobuzURL, _ := resultMap["qobuz_url"].(string); qobuzURL != "" {
		return &SelectedSource{Provider: "qobuz", ProviderID: trackID, Confidence: 0.7}
	}
	return nil
}
